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

			let input = audioEngine.inputNode
			audioEngine.attach(mixer)
			audioEngine.connect(input, to: mixer, format: input.outputFormat(forBus: 0))

			mixer.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, when in
				self.conversionQueue.async {
					let convertedBuffer = self.convert(buffer: buffer, outputFormat: self.audioFormat, audioConverter: self.outputAudioConverter)

					let audioBuffer = convertedBuffer.audioBufferList.pointee.mBuffers

					if let ptr = audioBuffer.mData {
						let data = Data(bytes: ptr, count: Int(audioBuffer.mDataByteSize))
						self.dataStreamer?(data, data.count)
					}
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

	func convert(buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat, audioConverter: AVAudioConverter?) -> AVAudioPCMBuffer {
		var newBufferAvailable = true

		let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
			if newBufferAvailable {
				outStatus.pointee = .haveData
				newBufferAvailable = false
				return buffer
			} else {
				outStatus.pointee = .noDataNow
				return nil
			}
		}

		let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)) ?? AVAudioPCMBuffer()

		var error: NSError?
		_ = audioConverter?.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)

		if let error = error {
			print(error.localizedDescription, error.description)
		}

		return convertedBuffer
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

			print("Reading bytes \(counter)")
			counter += 1

			guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioFormat.sampleRate)) else {
				print("Stream reading failed")
				return
			}

			pcmBuffer.frameLength = pcmBuffer.frameCapacity
			let channels = UnsafeBufferPointer(start: pcmBuffer.floatChannelData, count: Int(pcmBuffer.format.channelCount))
			playingData.withUnsafeBytes { src in
				memcpy(channels[0], src, Int(audioFormat.sampleRate))
			}
			playingData.removeFirst(Int(pcmBuffer.frameLength))

			DispatchQueue.main.async {
				let convertedBuffer = self.convert(buffer: pcmBuffer, outputFormat: self.audioEngine.outputNode.inputFormat(forBus: 0), audioConverter: self.inputAudioConverter)
				convertedBuffer.frameLength = convertedBuffer.frameCapacity

				if !self.audioEngine.isRunning {
					self.audioEngine.attach(self.player)
					self.audioEngine.connect(self.player, to: self.audioEngine.mainMixerNode, format: convertedBuffer.format)
					self.audioEngine.prepare()
					try? self.audioEngine.start()
					self.player.play()
				}
				self.player.volume = 1

				self.player.scheduleBuffer(convertedBuffer, completionHandler: {})
				print("Reading finished")
			}
		}
	}
}
