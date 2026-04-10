//
//  ContentView.swift
//  grabber
//
//  Created by Rushi Patel on 27/3/2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    let closePopover: () -> Void
    
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
            GrabberSettingsSections(showAdvancedOptions: false)

            HStack {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    closePopover()
                })
                .font(.caption)
                .foregroundStyle(.secondary)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

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
