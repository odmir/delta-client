//
//  AttachEntityPacket.swift
//  DeltaCore
//
//  Created by Rohan van Klinken on 14/2/21.
//

import Foundation

public struct AttachEntityPacket: ClientboundPacket {
  public static let id: Int = 0x45
  
  public var attachedEntityId: Int
  public var holdingEntityId: Int

  public init(from packetReader: inout PacketReader) throws {
    attachedEntityId = packetReader.readInt()
    holdingEntityId = packetReader.readInt()
  }
}
