//
//  TouchdownModifier.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import SwiftUI

extension View {
	func onTouchGesture(callback: @escaping (Bool) -> Void) -> some View {
		modifier(OnTouchGestureModifier(callback: callback))
	}
}

private struct OnTouchGestureModifier: ViewModifier {
	@State private var tapped = false
	let callback: (Bool) -> Void

	func body(content: Content) -> some View {
		content
			.simultaneousGesture(DragGesture(minimumDistance: 0)
				.onChanged { _ in
					if !self.tapped {
						self.tapped = true
						self.callback(self.tapped)
					}
				}
				.onEnded { _ in
					self.tapped = false
					self.callback(self.tapped)
				})
	}
}
