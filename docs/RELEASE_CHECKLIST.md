# Release checklist — v0.4.1

**Block public/stable releases until the macOS build and these checks pass.**

- [ ] On a real Intel macOS 13+ Mac: `bash scripts/test.sh && bash scripts/build.sh` succeeds.
- [ ] On Apple Silicon: universal binary launches. `lipo -info 'build/Mawaqit Island.app/Contents/MacOS/MawaqitIsland'` includes arm64 and x86_64 after universal build.
- [ ] Fresh install (no saved mosque): Preferences opens automatically; search for Dresden and Paris returns selectable mosques.
- [ ] Paste a real Mawaqit mosque URL into manual URL field; invalid domains are refused.
- [ ] Select a mosque, confirm real five prayer times against Mawaqit website (including country/timezone).
- [ ] Count down seconds visibly change; next prayer flips at exact prayer start (also Isha → tomorrow's Fajr).
- [ ] Verify DST date (switch to a mosque in another country and test across daylight-saving changes).
- [ ] Hide: panel is truly removed when pointer moves away; hover expands smoothly; settings click remains responsive.
- [ ] Choose "always visible compact" only when user enables it; default hides entirely.
- [ ] Test notch and non-notch hardware; test external monitor selection.
- [ ] Verify all three themes and three languages, especially RTL Arabic text, names and Western digits.
- [ ] Check cache offline behavior and 5-minute reminder (opt-in, does not play sound).
- [ ] Try GUI installer over v0.2.0; ensure preferences and cached data are preserved and older app is backed up.
- [ ] Accessibility check: keyboard access to Preferences and menu bar commands.
- [ ] Build on GitHub Actions, download ZIP, open on clean Mac, document Gatekeeper steps.
- [ ] For a polished release, arrange Developer ID signing + notarization. CI currently only creates ad-hoc signed apps.

## Known limitations

- No official Mawaqit integration or stability guarantee; public search/page HTML parsing can break.
- Some mosque data may not include iqama or timezone; a manual timezone override is provided.
- This is not a hardware/native Apple Dynamic Island; it is an overlay that mimics its interaction.
- No automatic software updater, full-screen-awareness toggle, or prayer audio player in the current preview.
- The macOS UI hasn't been built in the original Linux authoring environment.
