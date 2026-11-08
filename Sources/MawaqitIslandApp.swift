import AppKit
import SwiftUI
import QuartzCore
import Foundation

private enum PresentationMode: Equatable { case hidden, compact, expanded }

@MainActor
private final class IslandController: NSObject, NSApplicationDelegate {
    private let model = IslandModel()
    private var mode: PresentationMode = .hidden
    private var island: NSPanel?
    private var preferencesWindow: NSWindow?
    private var menuBar: NSStatusItem?
    private var pointerPoll: Timer?
    private var activeScreen: NSScreen?
    private var hoveredSince: Date?
    private var lastNear = Date.distantPast
    private var suppressUntilLeave = false
    // When the user clicks the collapse chevron, do not immediately expand
    // again just because the pointer still overlaps the island's hover zone.
    private var userCollapsedUntilPointerExit = false
    private var eventVisibleUntil = Date.distantPast
    private var lastReminder = ""
    private var animationGeneration = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupIsland()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let polling = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePointer() }
        }
        RunLoop.main.add(polling, forMode: .common)
        pointerPoll = polling
        if model.selected == nil { showSettings() }
        if model.preferences.alwaysShowCompact { present(.compact) }
        if let screen = configuredScreen(for: NSEvent.mouseLocation) {
            NSLog("[Mawaqit Island] Display notch geometry — builtIn=%@, safeTop=%.1f, crown=%.1f, screen=%@",
                  builtInDisplay(screen) ? "yes" : "no", Double(screen.safeAreaInsets.top),
                  Double(notchClearance(for: screen)), screen.localizedName)
        }
        Task { @MainActor in await model.refresh(force: true) }
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Mawaqit Island")
        item.button?.toolTip = "Mawaqit Island v0.4.1 — mosque prayer times"
        let menu = NSMenu()
        let entries: [(String, Selector)] = [
            ("Show island", #selector(showFromMenu)),
            ("Hide island", #selector(hideFromMenu)),
            ("Choose mosque / Preferences…", #selector(showSettings)),
            ("Sync now", #selector(refreshFromMenu)),
            ("Open mosque on Mawaqit", #selector(openSource)),
            ("Quit Mawaqit Island", #selector(quit))
        ]
        for (n, pair) in entries.enumerated() {
            if n == 3 || n == 5 { menu.addItem(.separator()) }
            let entry = NSMenuItem(title: pair.0, action: pair.1, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        item.menu = menu
        menuBar = item
    }

    private func builtInDisplay(_ screen: NSScreen?) -> Bool {
        guard let screen else { return false }
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            // Hardware API, independent of the Mac's system language.
            if CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0 { return true }
        }
        // Also handle configurations where the display number is unavailable.
        let name = screen.localizedName.lowercased()
        return name.contains("built-in") || name.contains("integriert") || name.contains("internal")
            || name.contains("intégré") || name.contains("incorporado")
    }
    private func notchClearance(for screen: NSScreen?) -> CGFloat {
        // Use measured safe insets plus a tight fallback. In the current UI,
        // this space is a functional crown with left/right notch ears.
        NotchGeometry.contentClearance(topSafeArea: screen?.safeAreaInsets.top ?? 0,
                                       isBuiltIn: builtInDisplay(screen))
    }
    private func displayedScreen() -> NSScreen? {
        activeScreen ?? configuredScreen(for: NSEvent.mouseLocation)
    }

    private func setupIsland() {
        let panel = NSPanel(contentRect: frame(for: .compact),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(rootView: IslandContent(
            model: model,
            expanded: false,
            notchTopClearance: notchClearance(for: displayedScreen()),
            expand: { [weak self] in self?.present(.expanded) },
            collapse: { [weak self] in self?.collapseFromButton() },
            hide: { [weak self] in self?.hideFromButton() },
            settings: { [weak self] in self?.showSettings() },
            refresh: { [weak self] in self?.refreshNow() },
            openWebsite: { [weak self] in self?.visitSelected() }
        ))
        panel.orderOut(nil)
        panel.alphaValue = 0
        island = panel
    }

    // We deliberately use a dedicated NSWindow for settings. The island itself is never a full app window.
    @objc private func showSettings() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 750),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Mawaqit Island — Preferences"
        window.minSize = NSSize(width: 620, height: 570)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView(
            model: model,
            choose: { [weak self] mosque in
                self?.model.updateMosque(mosque)
                self?.preferencesWindow?.orderOut(nil)
                self?.eventVisibleUntil = Date().addingTimeInterval(8)
                self?.present(.expanded)
            },
            close: { [weak self] in self?.preferencesWindow?.orderOut(nil) }
        ))
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func screenUnderPointer(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
    private func configuredScreen(for point: NSPoint) -> NSScreen? {
        switch model.preferences.display {
        case .pointer: return screenUnderPointer(point) ?? NSScreen.main ?? NSScreen.screens.first
        case .main: return NSScreen.main ?? NSScreen.screens.first
        case .builtIn:
            return NSScreen.screens.first(where: {
                let name = $0.localizedName.lowercased()
                return name.contains("built-in") || name.contains("integriert") || name.contains("internal")
            }) ?? NSScreen.main ?? NSScreen.screens.first
        }
    }
    private func frame(for requested: PresentationMode) -> NSRect {
        let screen = displayedScreen()
        let rect = screen?.frame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        let width: CGFloat = requested == .expanded ? NotchGeometry.expandedWidth :
            NotchGeometry.compactWidth(clearance: notchClearance(for: screen),
                                       preferred: CGFloat(model.preferences.compactWidth))
        let clearance = notchClearance(for: screen)
        let height: CGFloat = requested == .expanded
            ? NotchGeometry.expandedHeight(clearance: clearance,
                showSunrise: model.preferences.showSunrise, hasTimetable: model.timetable != nil)
            : NotchGeometry.compactBodyHeight
        // On notched Macs the compact state uses two safe ears *alongside*
        // the camera. The centre gap stays visually transparent.
        let compactOffset = requested == .compact
            ? NotchGeometry.compactTopOffset(clearance: clearance) : 0
        return NSRect(x: rect.midX - width / 2,
                      y: rect.maxY - height - compactOffset,
                      width: width, height: height)
    }
    private func pointerNearNotch(_ position: NSPoint, screen: NSScreen?) -> Bool {
        guard let rect = screen?.frame else { return false }
        return abs(position.x - rect.midX) <= max(125, CGFloat(model.preferences.compactWidth / 2)) &&
            position.y >= rect.maxY - 39 && position.y <= rect.maxY + 3
    }
    private func pointerNearIsland(_ position: NSPoint) -> Bool {
        guard let island, mode != .hidden else { return false }
        return island.frame.insetBy(dx: -17, dy: -18).contains(position)
    }

    private func updatePointer() {
        let now = Date()
        let position = NSEvent.mouseLocation
        let target = mode == .hidden ? configuredScreen(for: position) : activeScreen
        let inNotch = pointerNearNotch(position, screen: target)
        let near = inNotch || pointerNearIsland(position)
        if !near {
            suppressUntilLeave = false
            userCollapsedUntilPointerExit = false
        }

        if mode == .hidden {
            if model.preferences.showOnHover && inNotch && !suppressUntilLeave {
                activeScreen = target
                hoveredSince = now
                lastNear = now
                present(.compact)
            } else if model.preferences.alwaysShowCompact && !suppressUntilLeave {
                present(.compact)
            }
        } else if near {
            lastNear = now
            if hoveredSince == nil { hoveredSince = now }
            if mode == .compact, model.preferences.showOnHover,
               !userCollapsedUntilPointerExit, let since = hoveredSince,
               now.timeIntervalSince(since) >= model.preferences.hoverDelay {
                present(.expanded)
            }
        } else {
            hoveredSince = nil
            if now >= eventVisibleUntil && now.timeIntervalSince(lastNear) >= model.preferences.hideDelay {
                if model.preferences.alwaysShowCompact {
                    if mode == .expanded { present(.compact) }
                } else { hide() }
            }
        }
        checkReminder(now)
    }

    private func checkReminder(_ now: Date) {
        guard model.preferences.reminder5Minutes,
              let next = PrayerClock.upcoming(after: now, table: model.timetable),
              (295...300).contains(Int(next.seconds)),
              let zone = model.timetable?.timeZone else { return }
        let key = PrayerClock.key(next.prayer.date, in: zone) + "-" + next.prayer.englishName
        guard lastReminder != key else { return }
        lastReminder = key
        if mode == .hidden {
            eventVisibleUntil = now.addingTimeInterval(7)
            lastNear = now
            present(.compact)
        }
    }

    private func updatePanelContent() {
        guard let island else { return }
        island.contentView = NSHostingView(rootView: IslandContent(
            model: model, expanded: mode == .expanded,
            notchTopClearance: notchClearance(for: displayedScreen()),
            expand: { [weak self] in self?.present(.expanded) },
            collapse: { [weak self] in self?.collapseFromButton() },
            hide: { [weak self] in self?.hideFromButton() },
            settings: { [weak self] in self?.showSettings() },
            refresh: { [weak self] in self?.refreshNow() },
            openWebsite: { [weak self] in self?.visitSelected() }
        ))
    }
    private func present(_ newMode: PresentationMode) {
        guard newMode != .hidden, let panel = island else { return }
        if mode == .hidden {
            activeScreen = activeScreen ?? configuredScreen(for: NSEvent.mouseLocation)
            panel.setFrame(frame(for: .compact).offsetBy(dx: 0, dy: 4), display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        mode = newMode
        animationGeneration += 1
        updatePanelContent()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = newMode == .expanded ? 0.32 : 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(frame(for: newMode), display: true)
            panel.animator().alphaValue = 1
        }
    }
    private func hide() {
        guard mode != .hidden, let panel = island else { return }
        mode = .hidden
        hoveredSince = nil
        animationGeneration += 1
        let generation = animationGeneration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak panel] in
            Task { @MainActor [weak self] in
                guard let self, self.animationGeneration == generation else { return }
                panel?.orderOut(nil)
                self.activeScreen = nil
            }
        })
    }
    private func collapseFromButton() {
        guard mode == .expanded else { return }
        // Don't allow the 120 ms pointer polling loop to undo a manual click.
        // Hover expansion is rearmed after the pointer leaves the island/hotspot.
        userCollapsedUntilPointerExit = true
        hoveredSince = nil
        lastNear = Date()
        eventVisibleUntil = .distantPast
        NSLog("[Mawaqit Island] Collapsed by user; waiting for pointer exit to rearm hover")
        present(.compact)
    }
    private func hideFromButton() {
        suppressUntilLeave = true
        eventVisibleUntil = .distantPast
        hide()
    }
    private func refreshNow() { Task { @MainActor in await model.refresh(force: true) } }
    private func visitSelected() { if let website = model.selected?.website { NSWorkspace.shared.open(website) } }

    @objc private func screensChanged() {
        // Recalculate both panel geometry and SwiftUI safe area after a
        // monitor, resolution, or display topology change.
        guard let island, mode != .hidden else { return }
        updatePanelContent()
        island.setFrame(frame(for: mode), display: true)
    }
    @objc private func showFromMenu() {
        suppressUntilLeave = false
        activeScreen = configuredScreen(for: NSEvent.mouseLocation)
        lastNear = Date()
        eventVisibleUntil = Date().addingTimeInterval(12)
        present(.expanded)
    }
    @objc private func hideFromMenu() { hideFromButton() }
    @objc private func refreshFromMenu() { refreshNow() }
    @objc private func openSource() { visitSelected() }
    @objc private func quit() { NSApp.terminate(nil) }
}

@main
struct MawaqitIslandEntry {
    static func main() {
        let application = NSApplication.shared
        let controller = IslandController()
        application.delegate = controller
        application.run()
    }
}
