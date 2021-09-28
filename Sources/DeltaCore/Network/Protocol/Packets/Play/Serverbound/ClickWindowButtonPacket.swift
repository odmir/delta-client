//
//  ClickWindowButtonPacket.swift
//  DeltaCore
//
//  Created by Rohan van Klinken on 21/2/21.
//

import Foundation

public struct ClickWindowButtonPacket: ServerboundPacket {
  public static let id: Int = 0x08
  
  public var windowId: Int8
  public var buttonId: Int8
  
  public func writePayload(to writer: inout PacketWriter) {
    writer.writeByte(windowId)
    writer.writeByte(buttonId)
  }
}
