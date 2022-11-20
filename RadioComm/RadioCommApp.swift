//
//  RadioCommApp.swift
//  RadioComm
//
//  Created by Евгений on 10.11.22.
//

import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options: UIScene.ConnectionOptions
	) -> UISceneConfiguration {
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?

	func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard let windowScene = scene as? UIWindowScene else { return }

		let rootView = RadioView(viewModel: .init())
		let controller = UIHostingController(rootView: rootView)

		let window = UIWindow(windowScene: windowScene)
		window.tintColor = UIColor(named: "AccentColor")
		window.rootViewController = controller
		window.makeKeyAndVisible()
		self.window = window
	}
}

