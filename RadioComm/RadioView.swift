//
//  ContentView.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import SwiftUI

struct RadioView: View {
	@ObservedObject var viewModel: ViewModel

    var body: some View {
        VStack {
            Text("RadioComm")
				.bold()
			Spacer()
			Text("Talk")
				.font(.largeTitle)
				.bold()
				.foregroundColor(.white)
				.padding(80)
				.background(Circle().foregroundColor(viewModel.isTalking ? .green : .blue))
				.onTouchGesture {
					if $0 {
						viewModel.startTalking()
					} else {
						viewModel.stopTalking()
					}
				}
			.fixedSize()
			Spacer()
        }
		.padding(20)
    }
}

struct RadioView_Previews: PreviewProvider {
    static var previews: some View {
		RadioView(viewModel: RadioView.ViewModel(voiceService: VoiceService(audioService: AudioService(), multipeerService: MultipeerService())))
    }
}
