# Mawaqit Island — compact notch design (v0.4.1)

This is an original macOS SwiftUI implementation, inspired by general Dynamic Island patterns (not a copy of SuperIsland, NotchNook, DynamicLanding, or Mawaqit UI assets).

## Three states

1. Hidden: no overlay window on the screen.
2. Compact on built-in notched displays: two 88pt-wide black ears, aligned at the top. They show the next prayer (left) and its live countdown (right), with a **210pt genuinely transparent camera gap**. On notchless displays the compact state is one 32pt-high black pill.
3. Expanded: a 396pt-wide surface, pinned to the top. The 48pt default crown contains tiny controls outside the camera housing; the content begins immediately below it. The body is 338pt tall with a timetable, 230pt with no data. Sunrise adds 24pt.

## Style

- Surface: near-black purple (`#0C0713` approximately), avoiding the washed-out full-panel lavender gradient.
- Accent: soft orchid violet; used selectively on the active prayer, a micro-label, and the progress ring.
- Header: one-line mosque name at 13pt, small location line at 10pt; no header labels next to the physical camera.
- Main hero: next prayer and countdown at 30pt with 51pt orbital progress indicator, all within an 86pt card.
- Timetable: five rows of 24pt, understated secondary iqama times, active prayer has a subtle accent bar.
- Footer: synchronisation status and two small action icons.

## Hardware caveats

`NSScreen.safeAreaInsets.top` is consulted when available. A built-in screen with an unexpectedly zero value receives a 48pt fallback, intentionally tighter than v0.3.2's 72pt. This fallback is **not** guaranteed on every MacBook. Before tagging a release, test at least one 14-inch and one 16-inch notched MacBook plus a notchless external display. Record any overlap and use the specific display's measurements when refining the geometry; avoid reintroducing a global 72pt empty spacer.

## Visual QA on macOS

- With the mouse away, the island should hide completely unless Always show compact is on.
- Move to the top-center: the ears should appear and be separated by a clear gap.
- Hover for the configured delay: the panel should grow **downward** and never jump vertically.
- Verify no text or buttons are under the camera, both in compact and expanded modes.
- Verify the countdown changes each second, and the UI rolls to the next prayer.
- Check Arabic, German and English in both modes, longest mosque names, sunrise on/off, iqama on/off.
- Test changing the selected mosque, switching screens, and re-opening after logout/restart.
