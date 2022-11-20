//
//  AudioService.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import Foundation
import AVFoundation

protocol AudioServiceProtocol: StreamDelegate {
	var dataStreamer: ((Data, Int) -> Void)? { get set }

	func startStreaming()
	func stopStreaming()
}

class AudioService: NSObject, AudioServiceProtocol {
	var audioFormat: AVAudioFormat
	var audioEngine: AVAudioEngine
	var inputAudioConverter: AVAudioConverter?
	var outputAudioConverter: AVAudioConverter?

	var mixer = AVAudioMixerNode()
	var player: AVAudioPlayerNode
	var playingData = Data()

	var dataStreamer: ((Data, Int) -> Void)?

	private let conversionQueue = DispatchQueue(label: "conversionQueue")

	override init() {
		audioFormat = AVAudioFormat(
			commonFormat: .pcmFormatFloat32,
			sampleRate: 48000,
			channels: 1,
			interleaved: true
		) ?? .init()

		audioEngine = AVAudioEngine()
		inputAudioConverter = AVAudioConverter(from: audioFormat, to: audioEngine.outputNode.inputFormat(forBus: 0))
		outputAudioConverter = AVAudioConverter(from: audioEngine.inputNode.outputFormat(forBus: 0), to: audioFormat)
		player = AVAudioPlayerNode()

		super.init()
	}

	func startStreaming() {
		do {
			try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, policy: .default, options: [.interruptSpokenAudioAndMixWithOthers])
			try AVAudioSession.sharedInstance().setActive(true)

			audioEngine = AVAudioEngine()
			mixer = AVAudioMixerNode()

			let input = audioEngine.inputNode
			audioEngine.attach(mixer)
			audioEngine.connect(input, to: mixer, format: input.outputFormat(forBus: 0))

			mixer.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { buffer, when in
				let audioBuffer = buffer.audioBufferList.pointee.mBuffers

				if let ptr = audioBuffer.mData {
					let data = Data(bytes: ptr, count: Int(audioBuffer.mDataByteSize))
					self.dataStreamer?(data, data.count)
				}
			}

			self.audioEngine.prepare()
			try self.audioEngine.start()
		} catch {
			print(error.localizedDescription)
		}
	}

	func stopStreaming() {
		audioEngine.stop()
	}

	var counter = 0
}

extension AudioService: StreamDelegate {
	func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
		if eventCode == Stream.Event.hasBytesAvailable {
			guard let inputStream = aStream as? InputStream else { return }
			playingData.read(stream: inputStream, size: Int(audioFormat.sampleRate))

			guard playingData.count > Int(audioFormat.sampleRate) * 3 else {
				return
			}

			guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioFormat.sampleRate * 2)) else {
				print("Stream reading failed")
				return
			}

			buffer.frameLength = buffer.frameCapacity
			let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
			playingData.withUnsafeBytes { src in
				memcpy(channels[0], src, Int(audioFormat.sampleRate * 2))
			}
			playingData.removeFirst(Int(buffer.frameLength))

			DispatchQueue.main.async {
				if !self.audioEngine.isRunning || self.player.engine == nil {
					do {
						try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, policy: .default, options: [.interruptSpokenAudioAndMixWithOthers])
						try AVAudioSession.sharedInstance().setActive(true)

						self.audioEngine = AVAudioEngine()
						self.mixer = AVAudioMixerNode()

						self.audioEngine.attach(self.mixer)
						self.audioEngine.attach(self.player)

						self.audioEngine.connect(self.player, to: self.mixer, format: self.audioFormat)
						self.audioEngine.connect(self.mixer, to: self.audioEngine.outputNode, format: self.mixer.outputFormat(forBus: 0))

						self.audioEngine.prepare()
						try self.audioEngine.start()
						self.player.play()
						self.player.volume = 1
					} catch {
						print(error.localizedDescription)
					}
				}

				self.player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: {
					self.counter += 1
					print(self.counter)
				})
				print("Reading finished")
			}
		}
	}
}
