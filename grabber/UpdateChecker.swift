//
//  UpdateChecker.swift
//  grabber
//

import AppKit
import Combine
import Foundation

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, downloadURL: URL)
    case downloading(progress: Double)
    case readyToInstall(zipURL: URL)
    case error(String)
}

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var state: UpdateState = .idle
    /// Persists the latest available version string even after state moves to .downloading / .readyToInstall.
    @Published private(set) var availableVersion: String?

    private let apiURL = URL(string: "https://api.github.com/repos/ihsur7/grabber/releases/latest")!
    private var downloadTask: URLSessionDownloadTask?
    private var downloadObservation: NSKeyValueObservation?

    // MARK: - GitHub API model

    private struct Release: Decodable {
        let tagName: String
        let assets: [Asset]
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: String
            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }
    }

    // MARK: - Public API

    @MainActor
    func checkForUpdates() async {
        state = .checking
        do {
            var request = URLRequest(url: apiURL, cachePolicy: .reloadIgnoringLocalCacheData)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                state = .error("Failed to fetch release info.")
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard isNewer(latest, than: current) else {
                state = .upToDate
                return
            }
            guard let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
                  let url = URL(string: asset.browserDownloadURL) else {
                state = .upToDate
                return
            }
            availableVersion = latest
            state = .available(version: latest, downloadURL: url)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    func checkInBackground() {
        Task { await checkForUpdates() }
    }

    @MainActor
    func startDownload() {
        guard case .available(_, let downloadURL) = state else { return }

        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempURL, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.downloadObservation = nil
                if let error {
                    self.state = .error(error.localizedDescription)
                    return
                }
                guard let tempURL else {
                    self.state = .error("Download failed.")
                    return
                }
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("grabber-update-\(UUID().uuidString).zip")
                do {
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    self.state = .readyToInstall(zipURL: dest)
                } catch {
                    self.state = .error(error.localizedDescription)
                }
            }
        }

        downloadObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.state = .downloading(progress: progress.fractionCompleted)
            }
        }

        downloadTask = task
        state = .downloading(progress: 0)
        task.resume()
    }

    /// Writes a launcher script that waits for the current process to quit,
    /// replaces the app bundle, then reopens it.
    @MainActor
    func installAndReopen() {
        guard case .readyToInstall(let zipURL) = state else { return }

        let appPath = Bundle.main.bundleURL.path

        // Running inside Xcode (DerivedData) — don't try to replace the build output
        // or terminate the debug session. Just open the downloaded zip in Finder.
        if appPath.contains("/DerivedData/") || appPath.contains("Xcode") {
            state = .error("Install not supported in debug builds. Run the release app from /Applications to update.")
            NSWorkspace.shared.activateFileViewerSelecting([zipURL])
            return
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("grabber_update_\(UUID().uuidString)").path
        let scriptPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("grabber_install_\(UUID().uuidString).sh").path

        let script = """
        #!/bin/bash
        # Fork the real work into a disowned subshell so it survives the parent quitting.
        (
          while kill -0 \(pid) 2>/dev/null; do sleep 0.25; done
          mkdir -p "\(extractDir)"
          ditto -xk "\(zipURL.path)" "\(extractDir)"
          NEWAPP=$(find "\(extractDir)" -name "*.app" -maxdepth 3 | head -1)
          if [ -n "$NEWAPP" ]; then
              rm -rf "\(appPath)"
              ditto "$NEWAPP" "\(appPath)"
          fi
          rm -rf "\(extractDir)" "\(zipURL.path)"
          open "\(appPath)"
          rm -f "\(scriptPath)"
        ) &>/dev/null &
        disown $!
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: scriptPath
            )
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [scriptPath]
            try proc.run()
            NSApp.terminate(nil)
        } catch {
            state = .error("Install failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Version comparison

    private func isNewer(_ latest: String, than current: String) -> Bool {
        let lp = latest.split(separator: ".").compactMap { Int($0) }
        let cp = current.split(separator: ".").compactMap { Int($0) }
        let count = max(lp.count, cp.count)
        for i in 0..<count {
            let l = i < lp.count ? lp[i] : 0
            let c = i < cp.count ? cp[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}
