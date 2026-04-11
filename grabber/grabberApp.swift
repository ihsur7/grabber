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
        // No main window — the app lives entirely in the menu bar.
        Settings { EmptyView() }
    }
}
