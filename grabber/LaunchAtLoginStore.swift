import Combine
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginStore: ObservableObject {
    static let shared = LaunchAtLoginStore()

    private static let didConfigureDefaultKey = "didConfigureLaunchAtLoginDefault"

    @Published private(set) var launchesAtLogin = false
    @Published private(set) var approvalRequired = false
    @Published private(set) var isSupported = false

    private init() {
        refresh()
    }

    func configureDefaultIfNeeded() {
        guard #available(macOS 13.0, *) else { return }
        guard UserDefaults.standard.object(forKey: Self.didConfigureDefaultKey) == nil else { return }

        defer {
            UserDefaults.standard.set(true, forKey: Self.didConfigureDefaultKey)
        }

        refresh()
        guard !launchesAtLogin else { return }
        setLaunchAtLogin(true)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            refresh()
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update launch at login setting: %@", error.localizedDescription)
        }

        refresh()
    }

    func refresh() {
        guard #available(macOS 13.0, *) else {
            isSupported = false
            launchesAtLogin = false
            approvalRequired = false
            return
        }

        let status = SMAppService.mainApp.status
        isSupported = true
        launchesAtLogin = status == .enabled || status == .requiresApproval
        approvalRequired = status == .requiresApproval
    }
}