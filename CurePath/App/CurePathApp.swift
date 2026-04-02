//
//  CurePathApp.swift
//  CurePath
//

import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        OrientationLockHelper.lockPortrait()
        return true
    }
}

enum OrientationLockHelper {
    static func lockPortrait() {
        if #available(iOS 16.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                windowScene.windows.forEach { window in
                    window.rootViewController?
                        .setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue,
                                      forKey: "orientation")
        }
    }
}

@main
struct CurePathApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Persisted across launches — false means onboarding hasn't been seen yet
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    ContentView()
                } else {
                    OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
                }
            }
            .onAppear { OrientationLockHelper.lockPortrait() }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.didBecomeActiveNotification)
            ) { _ in OrientationLockHelper.lockPortrait() }
            .onReceive(NotificationCenter.default.publisher(
                for: UIDevice.orientationDidChangeNotification)
            ) { _ in OrientationLockHelper.lockPortrait() }
        }
    }
}
