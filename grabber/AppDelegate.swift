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
    let windowMover = WindowMover()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            NSApp.activate(ignoringOtherApps: true)
        }
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
