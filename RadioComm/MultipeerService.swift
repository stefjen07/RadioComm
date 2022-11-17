//
//  MultipeerService.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import Foundation
import MultipeerConnectivity

protocol MultipeerServiceProtocol {
	var outputStreams: [OutputStream] { get }
	var trackStream: ((InputStream) -> Void)? { get set }
}

class MultipeerService: NSObject, MultipeerServiceProtocol {
	private let myPeerID: MCPeerID
	private let session: MCSession
	private let nearbyServiceBrowser: MCNearbyServiceBrowser
	private let nearbyServiceAdvertiser: MCNearbyServiceAdvertiser

	private var peers: [Peer] = []

	var outputStreams: [OutputStream] {
		peers.compactMap { $0.outputStream }
	}

	var trackStream: ((InputStream) -> Void)?

	override init() {
		myPeerID = MCPeerID(displayName: (UIDevice.current.identifierForVendor ?? UUID()).uuidString)
		session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)

		nearbyServiceBrowser = MCNearbyServiceBrowser(
			peer: myPeerID,
			serviceType: Constants.serviceType
		)
		nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(
			peer: myPeerID,
			discoveryInfo: nil,
			serviceType: Constants.serviceType
		)

		super.init()

		session.delegate = self

		nearbyServiceBrowser.delegate = self
		nearbyServiceBrowser.startBrowsingForPeers()

		nearbyServiceAdvertiser.delegate = self
		nearbyServiceAdvertiser.startAdvertisingPeer()
	}

	func invitePeer(_ newPeerID: MCPeerID) {
		print("Peer invited")
		nearbyServiceBrowser.invitePeer(
			newPeerID,
			to: session,
			withContext: nil,
			timeout: 30
		)
	}

	func startStream(_ peerID: MCPeerID) {
		guard let stream = try? session.startStream(withName: UUID().uuidString, toPeer: peerID) else { return }
		stream.delegate = self
		stream.schedule(in: .main, forMode: .default)
		stream.open()

		peers.first(where: { $0.peerID == peerID })?.outputStream = stream
	}
}

extension MultipeerService: MCNearbyServiceBrowserDelegate {
	func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
		if !peers.contains(where: { $0.peerID == peerID }) {
			if(myPeerID.hashValue < peerID.hashValue){
				invitePeer(peerID)
			}
		}
	}

	func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
		print("Peer lost")
	}

	func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
		print(error.localizedDescription)
	}
}

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		print("Invitation accepted")
		invitationHandler(true, self.session)
	}

	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
		print(error.localizedDescription)
	}
}

extension MultipeerService: MCSessionDelegate {
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		if state == MCSessionState.connected {
			print("Peer connected")
			if !peers.contains(where: { $0.peerID == peerID }) {
				peers.append(Peer(peerID: peerID))
				startStream(peerID)
			}
		}
		if state == MCSessionState.notConnected {
			print("Peer disconnected")
			guard let index = peers.firstIndex(where: { $0.peerID == peerID }) else { return }

			peers.remove(at: index)
		}
	}

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {

	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		stream.schedule(in: .main, forMode: .default)
		stream.open()

		peers.first(where: { $0.peerID == peerID })?.inputStream = stream
		trackStream?(stream)
	}

	func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
		certificateHandler(true)
	}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {

	}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {

	}
}

extension MultipeerService: StreamDelegate {
	func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
		if let error = aStream.streamError {
			print(error.localizedDescription)

			guard let peer = peers.first(where: { $0.outputStream == aStream }) else { return }
			startStream(peer.peerID)
		}

	}
}
