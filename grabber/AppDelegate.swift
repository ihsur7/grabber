//
//  AppDelegate.swift
//  grabber
//

import Cocoa
import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private static let openHandAssetName = "openhand-symbol"
    private static let closedHandAssetName = "closehand-symbol"

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var aboutWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    let windowMover = WindowMover()
    let appVisibilityStore = AppVisibilityStore.shared
    let launchAtLoginStore = LaunchAtLoginStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy(showDockIcon: appVisibilityStore.showsDockIcon)
        launchAtLoginStore.configureDefaultIfNeeded()

        setupStatusItem()
        setupPopover()
        observeStateChanges()
        windowMover.startMonitoring()
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        updateStatusItemIcon(isHotkeyActive: windowMover.isHotkeyActive)
        button.action = #selector(togglePopover)
        button.target = self
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(onOpenAbout: { [weak self] in
                self?.showAboutWindow()
            })
                .environmentObject(appVisibilityStore)
                .environmentObject(launchAtLoginStore)
                .environmentObject(windowMover)
        )
    }

    private func observeStateChanges() {
        appVisibilityStore.$showsDockIcon
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] showDockIcon in
                self?.scheduleActivationPolicyUpdate(showDockIcon: showDockIcon)
            }
            .store(in: &cancellables)

        windowMover.$isHotkeyActive
            .removeDuplicates()
            .sink { [weak self] isHotkeyActive in
                self?.updateStatusItemIcon(isHotkeyActive: isHotkeyActive)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.launchAtLoginStore.refresh()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemIcon(isHotkeyActive: Bool) {
        guard let button = statusItem.button else { return }

        let assetName = isHotkeyActive ? Self.closedHandAssetName : Self.openHandAssetName
        guard let image = NSImage(named: assetName) else { return }

        let configuredImage = image.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 15, weight: .regular, scale: .large)
        ) ?? image

        configuredImage.isTemplate = true
        button.image = configuredImage
        button.image?.accessibilityDescription = "Grabber"
    }

    private func applyActivationPolicy(showDockIcon: Bool) {
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        if showDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func scheduleActivationPolicyUpdate(showDockIcon: Bool) {
        DispatchQueue.main.async {
            self.applyActivationPolicy(showDockIcon: showDockIcon)
        }
    }

    private func showAboutWindow() {
        popover.performClose(nil)

        // Defer window activation until after the popover finishes its update cycle.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let windowController = self.aboutWindowController ?? self.makeAboutWindowController()
            self.aboutWindowController = windowController

            windowController.showWindow(nil)
            guard let window = windowController.window else { return }

            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func makeAboutWindowController() -> NSWindowController {
        let hostingController = NSHostingController(rootView: AboutView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Grabber"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        return NSWindowController(window: window)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            DispatchQueue.main.async { [weak self] in
                self?.popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
