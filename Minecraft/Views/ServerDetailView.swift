//
//  ServerDetailView.swift
//  Minecraft
//
//  Created by Rohan van Klinken on 11/12/20.
//

import SwiftUI

struct ServerDetailView: View {
  @Binding var isPlaying: Bool
  @Binding var selectedServer: Server?
  
  @ObservedObject var server: Server
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading) {
        Text(server.name)
          .font(.title)
          .bold()
        Text("\(server.host):\(String(server.port))")
          .font(.title2)
      }
      
      VStack(alignment: .leading) {
        if (server.pingInfo != nil) {
          let pingInfo = server.pingInfo!
          Text("\(pingInfo.numPlayers)/\(pingInfo.maxPlayers) players")
          Text("version: \(pingInfo.versionName)")
        } else {
          Text("Pinging..")
        }
      }
      
      Button(action: {
//        isPlaying = true
        selectedServer = server
        server.login()
      }) {
        Text("Play")
      }
    }
  }
}
