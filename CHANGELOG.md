## v0.4.2 — DMG packaging and login startup (2026-11-08)

- Add a **Launch at login** preference using Apple's ServiceManagement API (macOS 13+). It is off by default and requires user opt-in.
- Build a drag-to-Applications **DMG** (and keep the universal ZIP) in GitHub Actions on macOS.
- Update German, English and Arabic installation instructions.
- Document that ad-hoc signed installers remain subject to macOS Gatekeeper; Developer ID signing and Apple notarization are separate future steps.

## v0.4.1 — Collapse interaction & mosque discovery (2026-11-08)

- Fix expanded chevron: manual collapse now stays collapsed until pointer exits the hover zone, preventing immediate automatic re-expansion.
- Replace broken direct private MAWAQIT mosque search with user-triggered browser discovery, editable HTTPS URL input, and one-click clipboard import. Do not ask for or bypass API authorization.
- Accept official `www.mawaqit.net` public links and use the mosque name published on the page after sync.
- Retain favorites, caching, settings and the compact island design from v0.4.0.
- Core checks extended with discovery and URL validation regressions; macOS visual testing still required.

## [0.4.0] — Compact notch redesign

- Replaced 72pt empty top crown with 48pt camera-safe *functional ears*.
- Redesigned compact mode as two black wings flanking the physical camera housing.
- Narrowed the expanded panel to 396pt, reduced typical expanded height to 386pt, tightened typography and prayer rows.
- Darkened the purple theme, removed large decorative empty spaces, preserved mosque selection, timers, favorites and other settings.
- Added layout regression tests for built-in and notchless displays.
- Source-only preview; test with a macOS build and physical notch before public release.

## v0.3.2 — Notch header layout correction (2026-11-08)

- Fix: the mosque name and header controls are now **structurally below** the entire camera housing.
- Use the hardware built-in screen detector (`CGDisplayIsBuiltin`) with a 72-point fail-safe crown when macOS reports `safeAreaInsets.top = 0`. All other padding is derived from this clearance.
- The compact pill is also moved below the same camera-safe band. No large gap on external displays without a notch.
- Add a launch-time screen geometry log for troubleshooting.
- Expand regression tests for zero safe-area reported on a built-in screen.

# Changelog

## v0.3.1 (camera safe area fix)

- Keeps expanded mosque title and control buttons fully below a MacBook camera housing.
- Places compact countdown below the physical notch instead of behind it.
- Uses display-specific `NSScreen.safeAreaInsets.top`, handling external displays without a notch.
- Allows two-line mosque names, recalculates layout on screen changes, and adds geometry regression tests.
- Preserves the existing Mawaqit purple theme, animations, prayer synchronization, user preferences and favorites.


## v0.3.0 (source preview)

- Mosque selection via public Mawaqit search or manually pasted URL.
- Favorites and saved mosque migration for prior Dresden v0.2 installations.
- Mawaqit-inspired purple palette, plus Midnight and Charcoal themes.
- Adjustable hover and hide delays, optional persistent compact pill, display selection.
- Arabic, German and English labels; optional sunrise/iqama and 5-minute reminder.
- Mosque-local timezones, cached per-mosque timetables, core tests, GitHub Actions build/release workflows.
- GitHub-friendly README, contributor and licensing documents.

## v0.2.0 (prototype)

- Single-mosque Dresden overlay, hover expansion, auto-hide.
