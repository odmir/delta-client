//
//  AssetManager.swift
//  DeltaClient
//
//  Created by Rohan van Klinken on 3/7/21.
//

import Foundation
import DeltaCore

/// A manager for DeltaClient's assets.
class AssetManager {
  /// The default asset manager instance.
  public static var `default` = AssetManager()
  
  /// The directory for storing the default vanilla resource pack.
  public private(set) var vanillaAssetsDirectory: URL
  /// The directory for storing downloaded data generated by pixlyzer.
  public private(set) var pixlyzerDirectory: URL
  
  /// Creates a new asset manager.
  private init() {
    vanillaAssetsDirectory = StorageManager.default.absoluteFromRelative("assets")
    pixlyzerDirectory = StorageManager.default.absoluteFromRelative("pixlyzer")
//    if !StorageManager.default.directoryExists(at: pixlyzerDirectory) {
//      do {
//        try StorageManager.default.createDirectory(at: pixlyzerDirectory)
//      } catch {
//        let message = "Failed to create pixlyzer data directory: \(error)"
//        DeltaClientApp.fatal(message)
//      }
//    }
  }
  
  // MARK: - Download
  
  /// Downloads the vanilla client and extracts its assets (textures, block models, etc.).
  public func downloadVanillaAssets(forVersion version: String) throws {
    // Get the url for the client jar
    log.info("Fetching version manifest for '\(version)'")
    let versionManifest = try getVersionManifest(for: version)
    let clientJarURL = versionManifest.downloads.client.url
    
    // Download the client jar
    log.info("Downloading client jar")
    let temporaryDirectory = FileManager.default.temporaryDirectory
    let clientJarTempFile = temporaryDirectory.appendingPathComponent("client.jar")
    do {
      let data = try Data(contentsOf: clientJarURL)
      try data.write(to: clientJarTempFile)
    } catch {
      log.error("Failed to download client jar: \(error)")
      throw AssetError.clientJarDownloadFailure
    }
    
    // Extract the contents of the client jar (jar files are just zip archives)
    log.info("Extracting client jar")
    let extractedClientJarDirectory = temporaryDirectory.appendingPathComponent("client", isDirectory: true)
    do {
      try StorageManager.default.unzipItem(at: clientJarTempFile, to: extractedClientJarDirectory)
    } catch {
      log.error("Failed to extract client jar: \(error)")
      throw AssetError.clientJarExtractionFailure
    }
    
    // Copy the assets from the extracted client jar to application support
    log.info("Copying assets")
    do {
      try StorageManager.default.copyItem(
        at: extractedClientJarDirectory.appendingPathComponent("assets"),
        to: vanillaAssetsDirectory)
    } catch {
      log.error("Failed to copy assets from extracted client jar: \(error)")
      throw AssetError.assetCopyFailure
    }
  }
  
  public func downloadPixlyzerData(forVersion version: String) throws {
    // swiftlint:disable force_unwrap
    let pixlyzerBlockPaletteURL = URL(string: "https://gitlab.bixilon.de/bixilon/pixlyzer-data/-/raw/master/version/\(version)/blocks.min.json")!
    // swiftlint:enable force_unwrap
    
    let pixlyzerBlockPaletteFile = pixlyzerDirectory.appendingPathComponent("blocks.min.json")
    
    let data: Data
    do {
      data = try Data(contentsOf: pixlyzerBlockPaletteURL)
    } catch {
      throw AssetError.failedToDownloadPixlyzerData(error)
    }
    
    do {
      try StorageManager.default.createDirectory(at: pixlyzerDirectory)
      try data.write(to: pixlyzerBlockPaletteFile)
    } catch {
      throw AssetError.failedToWritePixlyzerData(error)
    }
  }
  
  /// Get the manifest describing all versions.
  private func getVersionsManifest() throws -> VersionsManifest {
    // swiftlint:disable force_unwrap
    let versionsManifestURL = URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json")!
    // swiftlint:enable force_unwrap
    
    let versionsManifest: VersionsManifest
    do {
      let data = try Data(contentsOf: versionsManifestURL)
      versionsManifest = try JSONDecoder().decode(VersionsManifest.self, from: data)
    } catch {
      throw AssetError.versionsManifestFailure(error)
    }
    
    return versionsManifest
  }
  
  /// Get the manifest for the specified version.
  private func getVersionManifest(for versionString: String) throws -> VersionManifest {
    let versionURLs = try getVersionURLs()
    
    guard let versionURL = versionURLs[versionString] else {
      log.error("Failed to find manifest download url for version \(versionString)")
      throw AssetError.noURLForVersion(versionString)
    }
    
    let versionManifest: VersionManifest
    do {
      let data = try Data(contentsOf: versionURL)
      versionManifest = try JSONDecoder().decode(VersionManifest.self, from: data)
    } catch {
      throw AssetError.versionManifestFailure(error)
    }
    
    return versionManifest
  }
  
  /// Returns a map from version name to the version's manifest url.
  private func getVersionURLs() throws -> [String: URL] {
    let manifest = try getVersionsManifest()
    var urls: [String: URL] = [:]
    for version in manifest.versions {
      urls[version.id] = version.url
    }
    return urls
  }
  
  // MARK: - Textures
  
  /// Returns a texture palette of block textures.
  public func getBlockTexturePalette() throws -> TexturePalette {
    let textureDirectory = vanillaAssetsDirectory.appendingPathComponent("minecraft/textures/block")
    
    guard let textureDirectoryContents = try? StorageManager.default.contentsOfDirectory(at: textureDirectory) else {
      throw AssetError.blockTextureEnumerationFailure
    }
    
    var textureFiles: [URL] = []
    for file in textureDirectoryContents where file.pathExtension == "png" {
      textureFiles.append(file)
    }
    
    var images: [CGImage] = []
    var identifierToIndex: [Identifier: Int] = [:]
    var index: Int = 0
    for file in textureFiles {
      let textureName = file.deletingPathExtension().lastPathComponent
      let identifier = Identifier(name: "block/\(textureName)")
      
      guard let dataProvider = CGDataProvider(url: file as CFURL) else {
        log.error("Failed to get image data provider for texture '\(textureName)'")
        throw AssetError.dataProviderFailure
      }
      
      guard let cgImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
        log.error("Failed to create CGImage for texture '\(textureName)'")
        throw AssetError.cgImageFailure
      }
      
      if cgImage.width == 16 && cgImage.height == 16 {
        images.append(cgImage)
        identifierToIndex[identifier] = index
        index += 1
      }
    }
    
    return TexturePalette(
      identifierToIndex: identifierToIndex,
      textures: images)
  }
  
  // MARK: - Locale
  
  // TODO: clean up locale loading
  public func getLocale() throws -> MinecraftLocale {
    let localeURL = vanillaAssetsDirectory.appendingPathComponent("minecraft/lang/en_us.json")
    return try MinecraftLocale(localeFile: localeURL)
  }
}
