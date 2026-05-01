import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var updateChecker: UpdateChecker
    let onUpdate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(iconAssetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppMetadata.displayName)
                        .font(.title2.weight(.semibold))

                    Text("Grab 'em by the hotkeys.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                AboutRow(title: "Created by", value: "Rushabh Patel")
                AboutRow(title: "Version", value: AppMetadata.versionDescription)
            }

            Link(destination: AppMetadata.repositoryURL) {
                Label("Open project on GitHub", systemImage: "arrow.up.right.square")
            }

            Spacer(minLength: 0)

            HStack {
                // ── Check for Updates ────────────────────────────────
                checkForUpdatesButton
                updateStatus

                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var checkForUpdatesButton: some View {
        switch updateChecker.state {
        case .idle, .upToDate:
            Button("Check for Updates") {
                updateChecker.checkInBackground()
            }
        case .error:
            Button {
                updateChecker.checkInBackground()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Error")
                }
            }
        case .checking:
            Button("Checking…") {}
                .disabled(true)
        case .available(let v, _):
            Button("Update to v\(v)") {
                onUpdate()
            }
            .buttonStyle(.borderedProminent)
        case .downloading, .readyToInstall:
            Button("Installing…") {
                onUpdate()
            }
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updateChecker.state {
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Up to Date")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        default:
            EmptyView()
        }
    }

    private var iconAssetName: String {
        colorScheme == .dark ? "icondark" : "iconlight"
    }
}

private struct AboutRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
        }
    }
}

private enum AppMetadata {
    static let repositoryURL = URL(string: "https://github.com/ihsur7/grabber")!

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Grabber"
    }

    static var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        return "\(version)"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }
}

#Preview {
    AboutView(onUpdate: {})
        .environmentObject(UpdateChecker.shared)
}
