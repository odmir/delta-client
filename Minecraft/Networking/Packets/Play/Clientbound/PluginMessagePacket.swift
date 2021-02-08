//
//  PluginMessagePacket.swift
//  Minecraft
//
//  Created by Rohan van Klinken on 30/1/21.
//

import Foundation

struct PluginMessagePacket: Packet {
  typealias PacketType = PluginMessagePacket
  static var id: Int = 0x18
  
  var pluginMessage: PluginMessage
  
  // TODO_LATER: move this somewhere else if necessary
  struct PluginMessage {
    var channel: Identifier
    var data: Buffer
  }
  
  init(fromReader packetReader: inout PacketReader) throws {
    let channel = try packetReader.readIdentifier()
    let data = packetReader.buf
    pluginMessage = PluginMessage(channel: channel, data: data)
  }
}