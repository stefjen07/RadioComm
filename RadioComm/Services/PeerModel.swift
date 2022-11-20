//
//  PeerModel.swift
//  RadioComm
//
//  Created by Евгений on 15.11.22.
//

import Foundation
import MultipeerConnectivity

class Peer {
	var peerID: MCPeerID
	var inputStream: InputStream?
	var outputStream: OutputStream?

	init(peerID: MCPeerID) {
		self.peerID = peerID
	}
}
