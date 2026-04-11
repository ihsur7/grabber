//
//  grabberApp.swift
//  grabber
//
//  Created by Rushi Patel on 27/3/2026.
//

import SwiftUI

@main
struct grabberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.windowMover)
        }
    }
}
