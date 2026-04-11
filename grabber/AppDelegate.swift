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
