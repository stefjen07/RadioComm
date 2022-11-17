//
//  RadioCommApp.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import SwiftUI

@main
struct RadioCommApp: App {
    var body: some Scene {
        WindowGroup {
			RadioView(viewModel: RadioView.ViewModel(voiceService: VoiceService(audioService: AudioService(), multipeerService: MultipeerService())))
        }
    }
}
