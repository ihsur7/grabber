//
//  HotkeyStore.swift
//  grabber
//

import AppKit
import Combine

class HotkeyStore: ObservableObject {
    static let shared = HotkeyStore()

    private static let defaultsKey = "grabHotkeyModifiers"

    @Published var modifiers: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(modifiers.rawValue, forKey: Self.defaultsKey)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.object(forKey: Self.defaultsKey) as? UInt {
            modifiers = NSEvent.ModifierFlags(rawValue: raw)
        } else {
            modifiers = .option  // default: hold ⌥ to grab
        }
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option)  { parts.append("⌥") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift)   { parts.append("⇧") }
        return parts.isEmpty ? "None" : parts.joined()
    }
}
