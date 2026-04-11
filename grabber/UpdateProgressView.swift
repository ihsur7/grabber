//
//  UpdateProgressView.swift
//  grabber
//

import AppKit
import SwiftUI

struct UpdateProgressView: View {
    @EnvironmentObject var updateChecker: UpdateChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header ───────────────────────────────────────────────
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    if let v = updateChecker.availableVersion {
                        Text("Grabber \(v) Available")
                            .font(.headline)
                    } else {
                        Text("Grabber Update")
                            .font(.headline)
                    }
                    Text("A new version of Grabber is ready to install.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Status / progress ────────────────────────────────────
            Group {
                switch updateChecker.state {
                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Downloading…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                case .readyToInstall:
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Download complete.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                case .error(let msg):
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                default:
                    EmptyView()
                }
            }
            .frame(minHeight: 28)

            Spacer(minLength: 0)

            // ── Button row ───────────────────────────────────────────
            HStack {
                switch updateChecker.state {
                case .available:
                    Button("Download & Install") {
                        updateChecker.startDownload()
                    }
                    .buttonStyle(.borderedProminent)

                case .downloading:
                    Button("Downloading…") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)

                case .readyToInstall:
                    Button("Install and Reopen") {
                        updateChecker.installAndReopen()
                    }
                    .buttonStyle(.borderedProminent)

                case .error:
                    Button("Retry") {
                        Task { await updateChecker.checkForUpdates() }
                    }
                    .buttonStyle(.borderedProminent)

                default:
                    EmptyView()
                }

                Spacer()

                Button("Later") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 360, height: 190)
    }
}
