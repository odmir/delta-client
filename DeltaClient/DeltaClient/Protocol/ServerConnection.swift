//
//  ServerConnection.swift
//  DeltaClient
//
//  Created by Rohan van Klinken on 12/12/20.
//

import Foundation
import Network
import os

class ServerConnection {
  var host: String
  var port: UInt16
  
  var managers: Managers
  var packetRegistry: PacketRegistry
  var networkStack: NetworkStack
  
  var state: ConnectionState
  
  enum ConnectionState {
    case idle
    case handshaking
    case status
    case login
    case play
    case disconnected
    
    func toPacketState() -> PacketState? {
      switch self {
        case .handshaking:
          return .handshaking
        case .status:
          return .status
        case .login:
          return .login
        case .play:
          return .play
        default:
          return nil
      }
    }
  }
  
  // Init
  
  init(host: String, port: UInt16, managers: Managers) {
    self.managers = managers
    
    self.host = host
    self.port = port
    
    self.packetRegistry = PacketRegistry.createDefault()
    self.networkStack = NetworkStack(host, port, eventManager: self.managers.eventManager)
    
    self.state = .idle
  }
  
  // Lifecycle
  
  func start() {
    networkStack.connect()
  }
  
  func close() {
    networkStack.disconnect()
  }
  
  func restart() {
    networkStack.reconnect()
  }
  
  // Network layers
  
  func setCompression(threshold: Int) {
    networkStack.compressionLayer.compressionThreshold = threshold
  }
  
  // Packet
  
  func setPacketHandler(_ handler: @escaping (PacketReader) -> Void) {
    networkStack.setPacketHandler(handler)
  }
  
  func sendPacket(_ packet: ServerboundPacket) {
    networkStack.sendPacket(packet)
  }
  
  // Abstracted Operations
  
  func handshake(nextState: HandshakePacket.NextState) {
    let handshake = HandshakePacket(protocolVersion: PROTOCOL_VERSION, serverAddr: host, serverPort: Int(port), nextState: nextState)
    self.sendPacket(handshake)
    self.state = (nextState == .login) ? .login : .status
  }
  
  func login(username: String) {
    managers.eventManager.registerOneTimeEventHandler({ event in
      self.handshake(nextState: .login)
      
      let loginStart = LoginStartPacket(username: username)
      self.sendPacket(loginStart)
    }, eventName: "connectionReady")
    restart()
  }
}
