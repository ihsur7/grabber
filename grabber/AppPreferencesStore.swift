//
//  AppPreferencesStore.swift
//  grabber
//
import SwiftUI
import Combine

final class AppPreferencesStore: ObservableObject {
    static let shared = AppPreferencesStore()

    private static let showInDockKey = "showInDock"

    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: Self.showInDockKey)
        }
    }

    private init() {
        showInDock = UserDefaults.standard.bool(forKey: Self.showInDockKey)
    }
}
