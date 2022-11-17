//
//  VoiceService.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import Foundation

protocol VoiceServiceProtocol {
	var isTalking: Bool { get set }
}

class VoiceService: VoiceServiceProtocol {
	private var audioService: AudioServiceProtocol
	private var multipeerService: MultipeerServiceProtocol
	var isTalking: Bool = false

	init(audioService: AudioServiceProtocol, multipeerService: MultipeerServiceProtocol) {
		self.audioService = audioService
		self.multipeerService = multipeerService

		self.audioService.dataStreamer = streamData(_:length:)
		self.multipeerService.trackStream = trackStream(_:)
	}

	func trackStream(_ stream: InputStream) {
		stream.delegate = audioService
	}

	func streamData(_ data: Data, length: Int) {
		if !isTalking {
			return
		}

		for outputStream in multipeerService.outputStreams {
			streamData(data: data, length: length, outputStream: outputStream)
		}
	}

	func streamData(data: Data, length: Int, outputStream: OutputStream) {
		var _len = length, _byteIndex = 0

		while _byteIndex >= 0 && _byteIndex < data.count && outputStream.hasSpaceAvailable {
			_len = (data.count - _byteIndex) == 0 ? 1 : min(data.count - _byteIndex, length)
			print("START | byteIndex: \(_byteIndex)/\(data.count) writing len: \(_len)")
			var bytes = [UInt8](repeating: 0, count: _len)
			data.copyBytes(to: &bytes, from: _byteIndex ..< _byteIndex+_len)

			_byteIndex += outputStream.write(&bytes, maxLength: _len)
			print(outputStream.streamStatus.rawValue)
			print("END | byteIndex: \(_byteIndex)/\(data.count) wrote len: \(_len)")
		}
	}
}
