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
}

class AudioService: NSObject, AudioServiceProtocol {
	var audioFormat: AVAudioFormat
	var audioEngine: AVAudioEngine
	var inputAudioConverter: AVAudioConverter?
	var outputAudioConverter: AVAudioConverter?

	var player: AVAudioPlayerNode
	var playingData = Data()

	var dataStreamer: ((Data, Int) -> Void)?

	private let conversionQueue = DispatchQueue(label: "conversionQueue")

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

		let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate))!

		var error: NSError?
		let status = audioConverter?.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)

		if let error = error {
			print(error.localizedDescription, error.description)
		}

		return convertedBuffer
	}

	override init() {
		do {
			try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
			try AVAudioSession.sharedInstance().setActive(true)

			audioFormat = AVAudioFormat(
				commonFormat: .pcmFormatFloat32,
				sampleRate: 44100,
				channels: 1,
				interleaved: true
			) ?? .init()

			audioEngine = AVAudioEngine()
			inputAudioConverter = AVAudioConverter(from: audioFormat, to: audioEngine.mainMixerNode.inputFormat(forBus: 0))
			outputAudioConverter = AVAudioConverter(from: audioEngine.inputNode.outputFormat(forBus: 0), to: audioFormat)
			player = AVAudioPlayerNode()

			super.init()

			print(audioEngine.inputNode.outputFormat(forBus: 0))
			let bufferSize = AVAudioFrameCount(audioEngine.inputNode.outputFormat(forBus: 0).sampleRate)
			audioEngine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: audioEngine.inputNode.outputFormat(forBus: 0), block: { buffer, when in
				self.conversionQueue.async {
					let convertedBuffer = self.convert(buffer: buffer, outputFormat: self.audioFormat, audioConverter: self.outputAudioConverter)
					
					let audioBuffer = convertedBuffer.audioBufferList.pointee.mBuffers
					let data = Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
					self.dataStreamer?(data, data.count)
				}
			})

			self.audioEngine.prepare()
			self.audioEngine.attach(self.player)
			self.audioEngine.connect(player, to: audioEngine.mainMixerNode, format: audioEngine.mainMixerNode.inputFormat(forBus: 0))
			try self.audioEngine.start()
		} catch {
			print(error.localizedDescription)
			fatalError()
		}
	}
}

extension AudioService: StreamDelegate {
	func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
		if !audioEngine.isRunning {
			print("Audio engine stopped")
			try? audioEngine.start()
			return
		}

		if eventCode == Stream.Event.hasBytesAvailable {
			print("Reading bytes")

			guard let inputStream = aStream as? InputStream else { return }
			playingData.read(stream: inputStream, size: Int(audioFormat.sampleRate))

			guard playingData.count > Int(audioFormat.sampleRate) else {
				return
			}

			guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(audioFormat.sampleRate)) else {
				print("Stream reading failed")
				return
			}

			pcmBuffer.frameLength = pcmBuffer.frameCapacity
			print(pcmBuffer.frameLength, audioFormat.sampleRate)
			let channels = UnsafeBufferPointer(start: pcmBuffer.floatChannelData, count: Int(pcmBuffer.format.channelCount))
			playingData.withUnsafeBytes { src in
				memcpy(channels[0], src, Int(audioFormat.sampleRate))
			}

			//_ = playingData.copyBytes(to:  UnsafeMutableBufferPointer(start: channels[0], count: Int(pcmBuffer.frameLength)))
			playingData.removeFirst(Int(pcmBuffer.frameLength))

			DispatchQueue.global(qos: .background).async {
				DispatchQueue.main.async {
					let convertedBuffer = self.convert(buffer: pcmBuffer, outputFormat: self.audioEngine.mainMixerNode.inputFormat(forBus: 0), audioConverter: self.inputAudioConverter)

					self.player.scheduleBuffer(convertedBuffer, completionHandler: {
						NSLog("Scheduled buffer")
						NSLog("\(self.player.isPlaying)")
					})
					if !self.player.isPlaying {
						self.player.play()
					}
				}
			}
		}
	}
}

extension Data {
	init(reading input: InputStream) throws {
		self.init()
		input.open()
		defer {
			input.close()
		}

		let bufferSize = 1024
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
		defer {
			buffer.deallocate()
		}
		while input.hasBytesAvailable {
			let read = input.read(buffer, maxLength: bufferSize)
			if read < 0 {
				throw input.streamError!
			} else if read == 0 {
				break
			}
			self.append(buffer, count: read)
		}
	}
}
