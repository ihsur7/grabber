//
//  ContentView.swift
//  grabber
//
//  Created by Rushi Patel on 27/3/2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var appVisibilityStore: AppVisibilityStore
    @EnvironmentObject var launchAtLoginStore: LaunchAtLoginStore
    @EnvironmentObject var windowMover: WindowMover
    @EnvironmentObject var updateChecker: UpdateChecker
    @ObservedObject var hotkeyStore = HotkeyStore.shared
    let onOpenAbout: () -> Void
    let onUpdate: () -> Void

    // Modifier options shown as toggle buttons
    private let modifierOptions: [(flag: NSEvent.ModifierFlags, label: String)] = [
        (.control, "⌃"),
        (.option,  "⌥"),
        (.command, "⌘"),
        (.shift,   "⇧"),
    ]
    
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    
    @ViewBuilder
    func glassEffect() -> some View {
        if #available(macOS 26.0, *) {
            self
        } else {
            self
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ──────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(windowMover.isHotkeyActive ? "closehand-symbol" : "openhand-symbol")
                    .font(.title2)
                    .foregroundStyle(.primary)
                Text("Grabber")
                    .font(.headline)
                Spacer()
                if case .available(let newVersion, _) = updateChecker.state {
                    Button("↑ v\(newVersion)") {
                        onUpdate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Accessibility status ─────────────────────────────────
            if !windowMover.accessibilityGranted {
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

            // ── Hotkey selector ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Hold key to grab")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(modifierOptions, id: \.flag.rawValue) { option in
                        let isOn = hotkeyStore.modifiers.contains(option.flag)
                        Button(option.label) {
                            var mods = hotkeyStore.modifiers
                            if isOn { mods.remove(option.flag) } else { mods.insert(option.flag) }
                            hotkeyStore.modifiers = mods
                        }
                        .buttonStyle(.bordered)
                        .tint(.primary)
                        .opacity(isOn ? 1 : 0.5)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: isOn ? 2 : 0)
                        )
                    }
                    Spacer()
                }
                
                if (hotkeyStore.modifiers.isEmpty) {
                    Text("No modifiers selected. Grab disabled.")
                        .font(.footnote)
                        .foregroundStyle(.red)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .fixedSize(horizontal: false, vertical: true)
                }
                else if hotkeyStore.modifiers.intersection([.control, .option, .command, .shift]).rawValue.nonzeroBitCount == 1 {
                    Text("Two or more modifiers recommended.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Toggle("Show icon in Dock", isOn: $appVisibilityStore.showsDockIcon)

            Toggle(
                "Start Grabber on login",
                isOn: Binding(
                    get: { launchAtLoginStore.launchesAtLogin },
                    set: { launchAtLoginStore.setLaunchAtLogin($0) }
                )
            )
            .disabled(!launchAtLoginStore.isSupported)

            if launchAtLoginStore.approvalRequired {
                Text("Approve Grabber in System Settings > General > Login Items if macOS asks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // ── Quit ─────────────────────────────────────────────────
            HStack {
                Button {
                    onOpenAbout()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .font(.title3)
                .foregroundStyle(.secondary)
                .help("About Grabber")

                Spacer()

                Button("Quit") { NSApp.terminate(nil) }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
