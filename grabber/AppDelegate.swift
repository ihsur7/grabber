//
//  AppDelegate.swift
//  grabber
//

import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    private let appPreferences = AppPreferencesStore.shared
    private let applicationIconImage = AppDelegate.loadApplicationIcon()
    let windowMover = WindowMover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyApplicationIcon()
        observeAppPreferences()
        setupStatusItem()
        setupPopover()
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
        button.image = NSImage(systemSymbolName: "hand.raised.fill",
                               accessibilityDescription: "Grabber")
        button.action = #selector(togglePopover)
        button.target = self
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(closePopover: { [weak self] in
                self?.popover.performClose(nil)
            })
                .environmentObject(windowMover)
        )
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
