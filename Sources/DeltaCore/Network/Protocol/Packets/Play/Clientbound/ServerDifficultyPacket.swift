//
//  ServerDifficultyPacket.swift
//  DeltaCore
//
//  Created by Rohan van Klinken on 3/1/21.
//

import Foundation

public struct ServerDifficultyPacket: ClientboundPacket {
  public static let id: Int = 0x0d
  
  public var difficulty: Difficulty
  public var isLocked: Bool
  
  public init(from packetReader: inout PacketReader) throws {
    guard let difficulty = Difficulty(rawValue: packetReader.readUnsignedByte()) else {
      throw ClientboundPacketError.invalidDifficulty
    }
    self.difficulty = difficulty
    isLocked = packetReader.readBool()
  }
  
  public func handle(for client: Client) throws {
    client.server?.update(with: self)
  }
}
