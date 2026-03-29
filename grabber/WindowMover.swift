//
//  WindowMover.swift
//  grabber
//

import AppKit
import Combine

class WindowMover: ObservableObject {
    @Published var isGrabbing = false
    @Published var accessibilityGranted = false

    let hotkeyStore = HotkeyStore.shared

    private var flagsMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var isHotkeyDown = false
    private var grabbedWindow: AXUIElement?
    private var grabOffset = CGPoint.zero

    // MARK: - Lifecycle

    func startMonitoring() {
        checkAccessibility()
        installFlagsMonitor()
    }

    func stopMonitoring() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        stopMouseTracking()
    }

    // MARK: - Accessibility

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [(kAXTrustedCheckOptionPrompt.takeRetainedValue() as String): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Re-check after a short delay so the published property updates in the UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAccessibility()
        }
    }

    // MARK: - Hotkey monitoring

    private func installFlagsMonitor() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            DispatchQueue.main.async { self?.handleFlagsChanged(event) }
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard accessibilityGranted else { return }
        let required = hotkeyStore.modifiers
        guard !required.isEmpty else { return }

        // Only compare the four standard modifier flags
        let active = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if active == required, !isHotkeyDown {
            isHotkeyDown = true
            grabWindowAtCursor()
        } else if active != required, isHotkeyDown {
            isHotkeyDown = false
            releaseWindow()
        }
    }

    // MARK: - Window grab / release

    private func grabWindowAtCursor() {
        let cursor = currentCursorInQuartz()
        guard let element = axElementAt(cursor),
              let window = findWindowElement(from: element),
              let windowPos = getPosition(of: window) else { return }

        grabbedWindow = window
        // Record offset so the window doesn't jump; cursor can be anywhere on the window
        grabOffset = CGPoint(x: cursor.x - windowPos.x, y: cursor.y - windowPos.y)
        isGrabbing = true
        startMouseTracking()
    }

    private func releaseWindow() {
        grabbedWindow = nil
        grabOffset = .zero
        isGrabbing = false
        stopMouseTracking()
    }

    // MARK: - Mouse tracking

    private func startMouseTracking() {
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            DispatchQueue.main.async { self?.moveGrabbedWindow() }
        }
    }

    private func stopMouseTracking() {
        if let m = mouseMoveMonitor { NSEvent.removeMonitor(m); mouseMoveMonitor = nil }
    }

    private func moveGrabbedWindow() {
        guard let window = grabbedWindow else { return }
        let cursor = currentCursorInQuartz()
        let newPos = CGPoint(x: cursor.x - grabOffset.x, y: cursor.y - grabOffset.y)
        setPosition(newPos, on: window)
    }

    // MARK: - Coordinate helpers

    /// NSEvent.mouseLocation is Cocoa coords (origin at bottom-left of primary screen, y up).
    /// The AX API uses Quartz coords (origin at top-left of primary screen, y down).
    private func currentCursorInQuartz() -> CGPoint {
        let p = NSEvent.mouseLocation
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: h - p.y)
    }

    // MARK: - Accessibility helpers

    private func axElementAt(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        return err == .success ? element : nil
    }

    /// Walk up the AX hierarchy to find the enclosing window element.
    private func findWindowElement(from element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth < 30 else { return nil }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        if let role = roleRef as? String {
            if role == kAXWindowRole as String { return element }
            if role == kAXApplicationRole as String { return nil }
        }

        var parentRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
              let parent = parentRef,
              CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }

        // swiftlint:disable:next force_cast
        return findWindowElement(from: parent as! AXUIElement, depth: depth + 1)
    }

    private func getPosition(of window: AXUIElement) -> CGPoint? {
        var posRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              let posVal = posRef,
              CFGetTypeID(posVal) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
        return point
    }

    private func setPosition(_ position: CGPoint, on window: AXUIElement) {
        var pos = position
        guard let value = AXValueCreate(.cgPoint, &pos) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }
}
