import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

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
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version)" //(\(build))
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }
}
