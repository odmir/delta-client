import Foundation
import simd

public struct BlockModelPalette {
  /// Block models indexed by block state id. Each is an array of block model variants. Each variant is an array of block models (required for multi-part block models).
  public var models: [[BlockModel]]
  /// The transforms to use when displaying blocks in different places. Block models specify an index into this array.
  public var displayTransforms: [BlockModelDisplayTransforms]
  
  // MARK: Init
  
  public init() {
    models = []
    displayTransforms = []
  }
  
  public init(models: [[BlockModel]], displayTransforms: [BlockModelDisplayTransforms]) {
    self.models = models
    self.displayTransforms = displayTransforms
  }
  
  // MARK: Access
  
  /// Returns the model to render for the given block state. The position is used
  /// to determine which variant to use in the cases where there are multiple.
  ///
  /// If `position` is nil the first block model is returned. This is used to skip
  /// random number generation in finding culling faces. We assume that the block
  /// model variants all have the same general shape.
  public func getModel(for stateId: Int, at position: Position?) -> BlockModel? {
    // TODO: correctly select weighted models (not doing that only affects chorus fruit so not a big deal)
    let variants = models[stateId]
    if let position = position {
      let modelCount = variants.count
      if modelCount > 1 {
        var random = Random(getPositionRandom(position))
        let value = Int32(truncatingIfNeeded: random.nextLong())
        let absValue = value.signum() * value
        let index = absValue % Int32(modelCount)
        return variants[Int(index)]
      } else if modelCount == 1 {
        return variants.first.unsafelyUnwrapped
      } else {
        return nil
      }
    } else {
      return variants.first
    }
  }
  
  /// Returns the seed to use for choosing block models. Identical behaviour to vanilla.
  public func getPositionRandom(_ position: Position) -> Int64 {
    var seed = Int64(position.x &* 3129871) ^ (Int64(position.z) &* 116129781) ^ Int64(position.y);
    seed = (seed &* seed &* 42317861) &+ (seed &* 11);
    return seed >> 16;
  }
  
  // MARK: Loading
  
  public static func load(
    from modelDirectory: URL,
    namespace: String,
    blockRegistry: BlockRegistry,
    blockTexturePalette: TexturePalette
  ) throws -> BlockModelPalette {
    // Load block models from the pack into an intermediate format
    let jsonBlockModels = try JSONBlockModel.loadModels(from: modelDirectory, namespace: namespace)
    let intermediateBlockModelPalette = try IntermediateBlockModelPalette(from: jsonBlockModels)
    
    // Convert intermediate block models to final format
    var blockModels = [[BlockModel]](repeating: [], count: blockRegistry.renderDescriptors.count)
    for (stateId, variants) in blockRegistry.renderDescriptors {
      let blockModelVariants: [BlockModel] = try variants.map { variant in
        do {
          let blockState = blockRegistry.getBlockState(withId: stateId) ?? BlockState.missing
          return try blockModel(
            for: variant,
            from: intermediateBlockModelPalette,
            with: blockTexturePalette,
            blockState: blockState)
        } catch {
          log.error("Failed to create block model for state \(stateId): \(error)")
          throw error
        }
      }
      
      blockModels[stateId] = blockModelVariants
    }
    
    return BlockModelPalette(
      models: blockModels,
      displayTransforms: intermediateBlockModelPalette.displayTransforms)
  }
  
  /// Creates the block model for the given pixlyzer block model descriptor.
  private static func blockModel(
    for partDescriptors: [BlockModelRenderDescriptor],
    from intermediateBlockModelPalette: IntermediateBlockModelPalette,
    with blockTexturePalette: TexturePalette,
    blockState: BlockState
  ) throws -> BlockModel {
    var cullingFaces: Set<Direction> = []
    var cullableFaces: Set<Direction> = []
    var nonCullableFaces: Set<Direction> = []
    
    let parts: [BlockModelPart] = try partDescriptors.map { renderDescriptor in
      // Get the block model data in its intermediate 'flattened' format
      guard let intermediateModel = intermediateBlockModelPalette.blockModel(for: renderDescriptor.model) else {
        throw BlockPaletteError.invalidIdentifier
      }
      
      let modelMatrix = renderDescriptor.transformationMatrix
      
      // Convert the elements to the correct format and identify culling faces
      var rotatedCullingFaces: Set<Direction> = []
      let elements: [BlockModelElement] = try intermediateModel.elements.map { intermediateElement in
        // Identify any faces of the elements that can fill a whole side of a block
        if blockState.isOpaque {
          rotatedCullingFaces.formUnion(intermediateElement.getCullingFaces())
        }
        
        let element = try blockModelElement(
          from: intermediateElement,
          with: blockTexturePalette,
          modelMatrix: modelMatrix,
          renderDescriptor: renderDescriptor)
        
        for face in element.faces {
          if let cullFace = face.cullface {
            cullableFaces.insert(cullFace)
          } else {
            nonCullableFaces.insert(face.actualDirection)
          }
        }
        
        return element
      }
      
      // Rotate the culling face directions to correctly match the block
      cullingFaces.formUnion(Set<Direction>(rotatedCullingFaces.map { direction in
        rotate(direction, byRotationFrom: renderDescriptor)
      }))
      
      return BlockModelPart(
        ambientOcclusion: intermediateModel.ambientOcclusion,
        displayTransformsIndex: intermediateModel.displayTransformsIndex,
        elements: elements)
    }
    
    return BlockModel(
      parts: parts,
      cullingFaces: cullingFaces,
      cullableFaces: cullableFaces,
      nonCullableFaces: nonCullableFaces)
  }
  
  /// Converts a flattened block model element to a block model element format ready for rendering.
  private static func blockModelElement(
    from flatElement: IntermediateBlockModelElement,
    with blockTexturePalette: TexturePalette,
    modelMatrix: matrix_float4x4,
    renderDescriptor: BlockModelRenderDescriptor
  ) throws -> BlockModelElement {
    // Convert the faces to the correct format
    let faces: [BlockModelFace] = try flatElement.faces.map { flatFace in
      // Get the index of the face's texture
      guard let textureIdentifier = try? Identifier(flatFace.texture) else {
        log.error("Invalid texture identifier string '\(flatFace.texture)'")
        throw BlockPaletteError.invalidTexture(flatFace.texture)
      }
      
      guard let textureIndex = blockTexturePalette.textureIndex(for: textureIdentifier) ?? blockTexturePalette.textureIndex(for: Identifier(name: "block/debug")) else {
        log.error("Failed to get texture for '\(textureIdentifier)' and failed to get debug texture (very sus)")
        throw BlockPaletteError.invalidTextureIdentifier(textureIdentifier)
      }
      
      // Update the cullface with the block rotation (ignoring element rotation)
      var cullface: Direction? = nil
      if let flatCullface = flatFace.cullface {
        cullface = rotate(flatCullface, byRotationFrom: renderDescriptor)
      }
      
      let uvs = try uvsForFace(
        flatFace,
        on: flatElement,
        from: renderDescriptor)
      
      // The actual direction the face will be facing after rotations are applied.
      let actualDirection = rotate(flatFace.direction, byRotationFrom: renderDescriptor)
      
      return BlockModelFace(
        direction: flatFace.direction,
        actualDirection: actualDirection,
        uvs: uvs,
        texture: textureIndex,
        cullface: cullface,
        tintIndex: flatFace.tintIndex)
    }
    
    return BlockModelElement(
      transformation: flatElement.transformationMatrix * modelMatrix,
      shade: flatElement.shouldShade,
      faces: faces)
  }
  
  /// Returns the given direction with the rotations in a model descriptor applied to it.
  private static func rotate(
    _ direction: Direction,
    byRotationFrom renderDescriptor: BlockModelRenderDescriptor
  ) -> Direction {
    var newDirection = direction
    if renderDescriptor.xRotationDegrees != 0 {
      newDirection = newDirection.rotated(renderDescriptor.xRotationDegrees / 90, clockwiseFacing: Axis.x.negativeDirection)
    }
    if renderDescriptor.yRotationDegrees != 0 {
      newDirection = newDirection.rotated(renderDescriptor.yRotationDegrees / 90, clockwiseFacing: Axis.y.negativeDirection)
    }
    return newDirection
  }
  
  /// Calculates texture uvs for a face on a specific element and model.
  ///
  /// - Returns: One texture coordinate for each face vertex (4 total) starting at the top left
  ///            and going clockwise (I think).
  private static func uvsForFace(
    _ face: IntermediateBlockModelFace,
    on element: IntermediateBlockModelElement,
    from renderDescriptor: BlockModelRenderDescriptor
  ) throws -> [simd_float2] {
    let direction = face.direction
    let minimumPoint = element.from
    let maximumPoint = element.to
    
    // If the block model defines uvs we use those, otherwise we generate our own from the geometry
    var uvs: [Float]
    if let uvArray = face.uv {
      guard uvArray.count == 4 else {
        throw BlockPaletteError.invalidUVs
      }
      uvs = uvArray.map { Float($0) / 16 }
    } else {
      // Here's a big ugly switch statement I made just for you, you're welcome.
      // It just finds the xy coords of the top left and bottom right of the texture to use.
      switch direction {
        case .west:
          uvs = [
            minimumPoint.z,
            1 - maximumPoint.y,
            maximumPoint.z,
            1 - minimumPoint.y
          ]
        case .east:
          uvs = [
            1 - maximumPoint.z,
            1 - maximumPoint.y,
            1 - minimumPoint.z,
            1 - minimumPoint.y
          ]
        case .down:
          uvs = [
            minimumPoint.x,
            1 - maximumPoint.z,
            maximumPoint.x,
            1 - minimumPoint.z
          ]
        case .up:
          uvs = [
            minimumPoint.x,
            minimumPoint.z,
            maximumPoint.x,
            maximumPoint.z
          ]
        case .south:
          uvs = [
            minimumPoint.x,
            1 - maximumPoint.y,
            maximumPoint.x,
            1 - minimumPoint.y
          ]
        case .north:
          uvs = [
            1 - maximumPoint.x,
            1 - maximumPoint.y,
            1 - minimumPoint.x,
            1 - minimumPoint.y
          ]
      }
    }
    
    // The uv coordinates for each corner of the face starting at top left going clockwise
    var coordinates = [
      simd_float2(uvs[2], uvs[1]),
      simd_float2(uvs[2], uvs[3]),
      simd_float2(uvs[0], uvs[3]),
      simd_float2(uvs[0], uvs[1])]
    
    // Rotate the array of coordinates (samples the same part of the texture just changes the rotation of the sampled region on the face
    let rotation = face.textureRotation
    coordinates = rotate(coordinates, by: rotation / 90)
    
    // UV lock makes sure textures don't rotate with the model (like stairs where the planks always face east-west
    // We rotate counter-clockwise this time
    if renderDescriptor.uvLock {
      var uvLockRotationDegrees = 0
      switch direction.axis {
        case .x:
          uvLockRotationDegrees = -renderDescriptor.xRotationDegrees
        case .y:
          uvLockRotationDegrees = -renderDescriptor.yRotationDegrees
        case .z:
          // The model descriptor can't rotate on the z axis but we should uvlock with the x rotation
          uvLockRotationDegrees = -renderDescriptor.xRotationDegrees
      }
      coordinates = rotateTextureCoordinates(coordinates, by: uvLockRotationDegrees)
    }
    
    return coordinates
  }
  
  // TODO: make this an extension of arrays or something
  /// Rotates the given array. Positive k is right rotation and negative k is left rotation.
  private static func rotate<T>(_ array: [T], by k: Int) -> [T] {
    var initialDigits : Int = 0
    k >= 0 ? (initialDigits = array.count - (k % array.count)) : (initialDigits = (abs(k) % array.count))
    let elementToPutAtEnd = Array(array[0..<initialDigits])
    let elementsToPutAtBeginning = Array(array[initialDigits..<array.count])
    return elementsToPutAtBeginning + elementToPutAtEnd
  }
  
  /// Rotates each of the texture coordinates by the specified amount around the center of the texture (clockwise).
  /// The angle should be a positive multiple of 90 degrees. Used for UV locking (works different to texture rotation).
  private static func rotateTextureCoordinates(
    _ coordinates: [simd_float2],
    by degrees: Int
  ) -> [simd_float2] {
    // Check if any rotation is required
    let angle = MathUtil.mod(degrees, 360)
    if angle == 0 {
      return coordinates
    }
    
    let center = simd_float2(0.5, 0.5)
    // The rotation rounded to nearest 90 degrees
    let rotation = angle - angle % 90
    let rotatedCoordinates: [simd_float2] = coordinates.map { point in
      let centerRelativePoint = point - center
      let rotatedPoint: simd_float2
      switch rotation {
        case 90:
          rotatedPoint = simd_float2(centerRelativePoint.y, -centerRelativePoint.x)
        case 180:
          rotatedPoint = -centerRelativePoint
        case 270:
          rotatedPoint = simd_float2(-centerRelativePoint.y, centerRelativePoint.x)
        default:
          rotatedPoint = centerRelativePoint
      }
      return rotatedPoint + center
    }
    
    return rotatedCoordinates
  }
  
  /// Returns a dictionary containing all of the block models in the specified directory (in Mojang's format).
  private static func readJSONBlockModels(from directory: URL) throws -> [Identifier: JSONBlockModel] {
    var mojangBlockModels: [Identifier: JSONBlockModel] = [:]
    
    let files = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants)
    for file in files where file.pathExtension == "json" {
      let blockName = file.deletingPathExtension().lastPathComponent
      let identifier = Identifier(name: "block/\(blockName)")
      let data = try Data(contentsOf: file)
      let mojangBlockModel = try JSONDecoder().decode(JSONBlockModel.self, from: data)
      mojangBlockModels[identifier] = mojangBlockModel
    }
    
    return mojangBlockModels
  }
}
