# 🌙 Mawaqit Island

**Prayer times in a beautiful Dynamic Island–style app for macOS.**  
**Deutsch:** [README.de.md](README.de.md) · **العربية:** [README.ar.md](README.ar.md) · **English:** this page

[⬇️ Download the latest macOS release](https://github.com/abderlahmanalhnedi/Mawaqit-Island/releases/latest)

Mawaqit Island is a free, independent macOS app that displays the next prayer, a **live countdown**, today's prayer and iqama times, and your chosen mosque. It hides near the notch when not needed. No SuperIsland, account, GPS, or subscription required.

## Install — no Terminal required

1. Open **[Releases](https://github.com/abderlahmanalhnedi/Mawaqit-Island/releases/latest)**.
2. Download **`Mawaqit-Island-macOS-universal.zip`**.
3. Double-click the ZIP, then drag **Mawaqit Island.app** into your **Applications** folder.
4. Open it, choose your mosque, and move the mouse to the top center of the screen.

**First launch security notice:** This community build is **ad-hoc signed, not Apple-notarized**. If macOS prevents opening, try Control-click / right-click the app in Finder → **Open**. If needed, go to **System Settings → Privacy & Security → Open Anyway**, then confirm. Do not turn off Gatekeeper system-wide.

**Supported:** macOS 13+ · Intel and Apple Silicon · Macs with or without a notch.

## What it does

- ⏳ Real-time countdown to the next prayer; five daily prayers and available iqama times
- 🕌 Save and switch between multiple mosques using their public MAWAQIT page URL
- ✨ Compact, auto-hiding notch-style design; hover to expand, move away to hide
- 🎨 Purple, Midnight Blue and Pure Black themes; Arabic, German and English
- ⚙️ Optional sunrise, reminder, display selection, size and animation timings
- 🔒 Local preferences and cache; no registration or tracking service

## Choose your mosque

Open the moon icon in the menu bar → **Preferences**. Choose **Find on the web** and search for a mosque, copy its MAWAQIT public page URL, then select **Import copied link**. You can also paste the URL and use **Use URL**. The website's private search API is **not** used.

## Screenshots

| Island · live countdown | Preferences · choose your mosque |
|---|---|
| ![Mawaqit Island in English](docs/screenshots/island-en.webp) | ![Mawaqit Island settings in English](docs/screenshots/preferences-en.webp) |

[All screenshots in Arabic, English and German](docs/SCREENSHOTS.md).

## For developers

To build locally from source (requires Apple Command Line Tools):

```bash
bash install.command
```

The script builds and installs to `~/Applications/Mawaqit Island.app`. [Build instructions](docs/GITHUB_UPLOAD.md) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md).

## Disclaimer

Independent community project, **not affiliated with or endorsed by MAWAQIT, Apple or SuperIsland**. Prayer data comes from public MAWAQIT mosque pages through an **unofficial integration** that may change. Check times against your mosque. MIT license.
