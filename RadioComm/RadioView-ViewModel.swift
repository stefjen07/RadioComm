//
//  RadioView-ViewModel.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import Foundation
import PushToTalk

extension RadioView {
	@MainActor class ViewModel: ObservableObject {
		@Published var isTalking: Bool = false

		var voiceService: VoiceServiceProtocol

		init(voiceService: VoiceServiceProtocol) {
			self.voiceService = voiceService
		}

		func startTalking() {
			isTalking = true
			voiceService.isTalking = true
		}

		func stopTalking() {
			isTalking = false
			voiceService.isTalking = false
		}
	}
}
