//
//  AppDelegate.swift
//  grabber
//

import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let openHandAssetName = "openhand-symbol"
    private static let closedHandAssetName = "closehand-symbol"

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var aboutWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    let windowMover = WindowMover()
    let appVisibilityStore = AppVisibilityStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy(showDockIcon: appVisibilityStore.showsDockIcon)

        setupStatusItem()
        setupPopover()
        observeVisibilityChanges()
        windowMover.startMonitoring()
    }

    private func observeAppPreferences() {
        appPreferences.$showInDock
            .removeDuplicates()
            .sink { [weak self] showInDock in
                self?.applyActivationPolicy(showInDock: showInDock)
            }
            .store(in: &cancellables)
    }

    private func applyActivationPolicy(showInDock: Bool) {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }

        NSApp.setActivationPolicy(policy)
        if showInDock {
            applyApplicationIcon()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func applyApplicationIcon() {
        NSApp.applicationIconImage = applicationIconImage
            ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private static func loadApplicationIcon() -> NSImage? {
        guard let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String else {
            return nil
        }

        let iconFilePath = iconFile as NSString
        let resourceName = iconFilePath.deletingPathExtension
        let resourceExtension = iconFilePath.pathExtension.isEmpty ? "icns" : iconFilePath.pathExtension

        if let iconPath = Bundle.main.path(forResource: resourceName, ofType: resourceExtension),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            return iconImage
        }

        return NSImage(named: NSImage.Name(iconFile))
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
        popover.contentSize = NSSize(width: 280, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(onOpenAbout: { [weak self] in
                self?.showAboutWindow()
            })
                .environmentObject(appVisibilityStore)
                .environmentObject(windowMover)
        )
    }

    private func observeVisibilityChanges() {
        appVisibilityStore.$showsDockIcon
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] showDockIcon in
                self?.applyActivationPolicy(showDockIcon: showDockIcon)
            }
            .store(in: &cancellables)

        windowMover.$isHotkeyActive
            .removeDuplicates()
            .sink { [weak self] isHotkeyActive in
                self?.updateStatusItemIcon(isHotkeyActive: isHotkeyActive)
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

    private func showAboutWindow() {
        if aboutWindowController == nil {
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
            aboutWindowController = NSWindowController(window: window)
        }

        popover.performClose(nil)
        aboutWindowController?.showWindow(nil)
        guard let window = aboutWindowController?.window else { return }

        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeMain()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
