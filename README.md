# 🌙 Mawaqit Island

**A standalone, customizable mosque prayer-time island for macOS.**

An *unofficial community project* inspired by the feel of macOS Dynamic Island and the purple palette of MAWAQIT. It does not copy or modify SuperIsland's code and is **not affiliated with or endorsed by MAWAQIT or Apple**.

> [اقرأ بالعربية / Arabic instructions](README.ar.md)

## Features

- 🔎 **Choose your own mosque**: open a web search for a city/mosque and import a public Mawaqit mosque URL from your clipboard, or paste it manually. Saved favorites remain available.
- ⭐ **Saved mosques**: easily switch between multiple favorites.
- ⏱️ **Genuine live countdown**: main-run-loop 1s clock; no dependency on SuperIsland's extension scheduler.
- 🪄 **Auto-hiding notch-style UI**: starts hidden, expands after pointer hover, automatically hides when the pointer leaves. Optional always-visible compact pill.
- 🎨 **Themes**: Mawaqit Purple, Midnight Blue, Pure Black. Adjustable compact width, hover delay, hide delay.
- 🌍 **Languages**: Arabic, English, German for prayer labels and island UI.
- 🕋 **Five daily prayers**, optional sunrise and iqama when published by the mosque. Friday special times/announcements are not yet rendered.
- 🪟 **Multi-monitor preference**: built-in screen, main screen, or screen under pointer.
- 💾 **Local cache** of public prayer times, per mosque; sync every 2h, retry on failures; clearly labeled when stale.
- 🔔 Optional brief island reveal five minutes before each prayer. No automatic audio playback.
- 🔒 **No account, API key, GPS, analytics or custom server needed.** Requests go directly to mawaqit.net.

## Requirements

- macOS 13 Ventura or later.
- Intel or Apple Silicon Mac. A hardware notch is optional; this is a native overlay, not Apple's system Dynamic Island.
- For building from source: Apple Command Line Tools (`xcode-select --install`). No Homebrew, Node.js, XcodeGen or third-party package manager needed.

## Installation

### Option A: Build on your Mac (best during development)

1. Download this repository as a ZIP from **Code → Download ZIP**, or clone it.
2. Unzip the project, open Terminal in its directory.
3. Run:

```bash
bash install.command
```

The script builds with Apple's Swift compiler, makes a local ad-hoc-signed `.app` and installs it to `~/Applications/Mawaqit Island.app`. If you have a previous standalone version, the installer backs it up first. It does not uninstall SuperIsland or erase your saved choices.

**First launch:** the mosque picker opens automatically. Search for a name/city in your browser, copy a public Mawaqit mosque page URL, then use **Import copied link**. Or paste a mosque URL manually. Select a mosque. Move the pointer to the top-center of your chosen display to reveal the island; hover to expand and move away to hide. The menu bar 🌙 offers a manual **Show island** and **Choose mosque / Preferences** action.

### Option B: GitHub Actions release archive (after publishing this repository)

Tag a release (for example `v0.4.1`) and the included release workflow builds a **universal Intel + Apple Silicon** `.app` ZIP and attaches it to a GitHub Release. Users can unpack and move the app to `Applications` without compiling Swift.

**Signing warning:** The automatically produced app is only **ad-hoc signed**, not Apple Developer ID signed or notarized. macOS Gatekeeper may require the user to explicitly approve opening it via **System Settings → Privacy & Security → Open Anyway**. For broad public distribution, configure a Developer ID signature and Apple notarization before calling it a frictionless one-click installer. Never disable Gatekeeper globally.

## Changing mosque and colors

Open the moon icon in your menu bar → **Choose mosque / Preferences**.

| Preference | Available choices |
|---|---|
| Mosque | Browser-assisted discovery, saved favorites, direct Mawaqit URL or paste clipboard |
| Theme | Mawaqit Purple / Midnight Blue / Pure Black |
| Language | Arabic / English / German |
| Behavior | Hover on/off, always-compact on/off, width, expansion and dismissal delays |
| Schedule | Iqama, sunrise, optional five-minute reminder |
| Screen | Built-in / Primary / Under pointer |
| Timezone | From mosque page; manual IANA override only if the page omits it |

## Data source, privacy and caveats

The app **does not** use the private MAWAQIT search API (which currently requires authorized access). For discovery, the user explicitly chooses to open a browser search at Google using `site:mawaqit.net`; the app never automatically transmits city queries. Once a valid mosque URL is imported, it requests only the public mosque page:

- `GET https://mawaqit.net/en/<mosque-slug>` for a public HTML page embedding `confData.calendar`, `confData.timezone` and optionally `confData.iqamaCalendar`.

These endpoints and embedded structures may change or become unavailable. The app **does not** claim official API support and does not manufacture prayer times on errors. A mosque may omit its timezone: the app then asks for an explicit timezone in Preferences; it does not silently assume the Mac's timezone for everyone.

Web discovery queries go to Google only when the user explicitly selects **Find on the web**. Visited mosque pages are fetched from mawaqit.net. Saved mosques, settings and timetable caches remain on your Mac (`UserDefaults` and `~/Library/Application Support/MawaqitIsland/`). There is no custom intermediary, telemetry or GPS permission. This project does not guarantee that the upstream provider does not log incoming requests.

The app uses original layout code inspired by Dynamic Island conventions. It includes **no assets, sources, fonts or code copied from SuperIsland**. Branding is referential only, not a claim of affiliation. Official mosque times should be verified with the mosque when they matter.

## Test and build

```bash
bash scripts/test.sh
bash scripts/build.sh
UNIVERSAL=1 bash scripts/build.sh   # Apple macOS SDK, builds both CPU architectures
```

- The pure Foundation core tests also run with Swift on Linux; AppKit/SwiftUI requires macOS.
- CI: `.github/workflows/build.yml` runs tests, makes a universal app archive and uploads an artifact.
- Releases: `.github/workflows/release.yml` publishes an ad-hoc-signed universal ZIP for any `v*` tag.
- There is **no runtime dependency on SuperIsland**.

## Status of this version

**v0.4.1 is a source-preview release.** The core test suite has run on Linux, and Swift files were syntax-parsed. The macOS UI was **not compiled, visually verified, or exercised on physical macOS hardware** in the authoring environment. Treat the CI macOS build and real-device smoke tests in [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) as release gates. Browser search and live Mawaqit page parsing were not tested end-to-end on a real Mac in the authoring environment.

## License

MIT — see [LICENSE](LICENSE). Copyright belongs to this project's contributors. MAWAQIT, macOS, and SuperIsland are trademarks or names belonging to their respective owners; the project is independent of them.

## Design refresh (v0.4.1)

- Compact, notch-aware **black ears** on either side of the camera: prayer name on the left, ticking countdown on the right. The gap is transparent.
- An expanded **396pt-wide panel** flows down from the physical notch, with useful small icons beside the camera instead of a blank 72pt strip.
- Dark Mawaqit-inspired surfaces and delicate purple accents; 5 compact prayer rows and a 51pt progress ring.
- Automatically shrinks when there is no timetable to show. Adds only one row when sunrise is enabled.
- For other displays, the UI remains a compact regular pill with controls in the expanded header.

This is a UI redesign based on original code. No third-party app code or artwork was copied. `NSScreen.safeAreaInsets.top` is consulted; the built-in 48pt fallback is **not proof of correctness on every model**. Visually verify on multiple MacBooks before a public release.

For layout details, see [Design system](docs/DESIGN_SYSTEM.md) and [Upgrade notes](docs/UPGRADE.md).


## v0.4.1 interaction fixes

- **Collapse chevron** now latches the compact state until the pointer leaves the island/hover region; moving back can expand again.
- **Mosque finder:** the former direct MAWAQIT API search required authorization. The app uses a user-initiated normal browser search and a clipboard import button instead. No OAuth token or credentials are needed. Google receives the search term only when the user presses **Find on the web**.
- If Google or the chosen mosque site changes, the fallback is to paste the exact public Mawaqit URL manually.
