//
//  SettingsView.swift
//  grabber
//

import SwiftUI
import AppKit

struct GrabberSettingsSections: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var windowMover: WindowMover
    @ObservedObject private var hotkeyStore = HotkeyStore.shared
    @ObservedObject private var appPreferences = AppPreferencesStore.shared

    let showAdvancedOptions: Bool

    private let modifierOptions: [(flag: NSEvent.ModifierFlags, label: String)] = [
        (.control, "⌃"),
        (.option, "⌥"),
        (.command, "⌘"),
        (.shift, "⇧"),
    ]

    private let githubURL = URL(string: "https://github.com/ihsur7/grabber")!

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if showAdvancedOptions {
                    Image(colorScheme == .dark ? "icondark" : "iconlight")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                Text("Grabber")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Accessibility")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: windowMover.accessibilityGranted
                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(windowMover.accessibilityGranted ? .green : .red)
                    Text(windowMover.accessibilityGranted
                         ? "Accessibility granted"
                         : "Accessibility required")
                        .font(.subheadline)
                    Spacer()
                    if !windowMover.accessibilityGranted {
                        Button("Grant") {
                            windowMover.requestAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hold key to grab")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(modifierOptions, id: \.flag.rawValue) { option in
                        let isOn = hotkeyStore.modifiers.contains(option.flag)
                        Button(option.label) {
                            var modifiers = hotkeyStore.modifiers
                            if isOn {
                                modifiers.remove(option.flag)
                            } else {
                                modifiers.insert(option.flag)
                            }
                            hotkeyStore.modifiers = modifiers
                        }
                        .buttonStyle(.bordered)
                        .tint(isOn ? .primary : .secondary)
                        .opacity(isOn ? 1 : 0.6)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                }

                if hotkeyStore.modifiers.isEmpty {
                    Text("No modifiers selected. Grab disabled.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if hotkeyStore.modifiers
                    .intersection([.control, .option, .command, .shift])
                    .rawValue
                    .nonzeroBitCount == 1 {
                    Text("Two or more modifiers recommended.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if showAdvancedOptions {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show in Dock", isOn: $appPreferences.showInDock)

                    Text("Show Grabber in the Dock and app switcher.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Made by")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text("Rushabh Patel")
                        Link(destination: githubURL) {
                            Label("GitHub", systemImage: "link")
                        }
                        .buttonStyle(.automatic)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GrabberSettingsSections(showAdvancedOptions: true)

            HStack {
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

#Preview {
    SettingsView()
}
