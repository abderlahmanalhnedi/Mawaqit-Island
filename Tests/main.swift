import Foundation

var checks = 0
func assertThat(_ truth: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !truth() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func iso(_ text: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: text)!
}

assertThat(MosqueURLs.fromUserInput("https://mawaqit.net/ar/m/islamisches-zentrum-dresden-e-v-dresden-01157-germany")?.slug == Mosque.dresden.slug, "Mawaqit /m URL accepted")
assertThat(MosqueURLs.fromUserInput("https://mawaqit.net/en/islamisches-zentrum-dresden-e-v-dresden-01157-germany") != nil, "normal mosque URL accepted")
assertThat(MosqueURLs.fromUserInput("https://evil-mawaqit.net/en/secret") == nil, "untrusted host rejected")
assertThat(MosqueURLs.fromUserInput("http://mawaqit.net/en/mosque") == nil, "HTTP rejected")
assertThat(MosqueURLs.fromUserInput("https://mawaqit.net@malicious.example/en/foo") == nil, "credential spoof rejected")
assertThat(MosqueURLs.fromUserInput("https://mawaqit.net/en/../foo") == nil, "path traversal rejected")

let browserSearch = MosqueDiscovery.webSearchURL("Berlin")!
assertThat(browserSearch.host == "www.google.com" && browserSearch.scheme == "https", "web discovery opens standard browser search")
let searchQuery = URLComponents(url: browserSearch, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "q" })?.value ?? ""
assertThat(searchQuery.contains("Berlin") && searchQuery.contains("site:mawaqit.net"), "web search scopes to Mawaqit")
assertThat(MosqueDiscovery.webSearchURL(" ") == nil, "empty search rejected")
assertThat(MosqueDiscovery.webSearchURL(String(repeating: "x", count: 81)) == nil, "oversized search rejected")
assertThat(MosqueURLs.fromUserInput("https://www.mawaqit.net/de/m/berlin-mosque-berlin-10713-germany")?.slug == "berlin-mosque-berlin-10713-germany", "official www mosque links accepted")
assertThat(MosqueURLs.fromUserInput("https://www.mawaqit.net.evil.test/en/berlin-mosque") == nil, "spoofed www host rejected")

let searchJSON = #"[{"slug":"grand-mosquee-de-paris-france","label":"Grande Mosquée de Paris","locality":"Paris","country":"France"},{"slug":""},{"slug":"grand-mosquee-de-paris-france","name":"duplicated"}]"#.data(using: .utf8)!
let results = try MosqueSearchParser.decode(searchJSON)
assertThat(results.count == 1, "search removes missing slugs and duplicates")
assertThat(results[0].name == "Grande Mosquée de Paris", "search uses label")
assertThat(results[0].locality == "Paris", "city parsed")

let zone = TimeZone(identifier: "Europe/Berlin")!
let today = iso("2026-11-08T12:00:00Z") // 13:00 in Dresden
let date = PrayerClock.noon(year: 2026, month: 11, day: 8, zone: zone)!
assertThat(PrayerClock.key(date, in: zone) == "2026-11-08", "date key uses mosque timezone")
assertThat(PrayerClock.normalizedTime("05:15:30") == "05:15", "normalizes times")
assertThat(PrayerClock.normalizedTime("27:30") == nil, "rejects invalid times")

var months = [[String: [String]]](repeating: [:], count: 12)
var iqama = [[String: [String]]](repeating: [:], count: 12)
months[10]["8"] = ["05:15", "07:22", "12:00", "14:08", "16:45", "18:35"]
months[10]["9"] = ["05:16", "07:23", "12:00", "14:07", "16:44", "18:34"]
iqama[10]["8"] = ["+15", "+10", "+10", "+5", "+10"]
let conf: [String: Any] = ["calendar": months, "iqamaCalendar": iqama, "times": months[10]["8"]!, "name": "Test Mosque", "timezone": "Europe/Berlin"]
let confJSON = try JSONSerialization.data(withJSONObject: conf, options: [.sortedKeys])
let html = Data("<html><script> const confData = ".utf8) + confJSON + Data("; </script></html>".utf8)
let table = try MawaqitHTML.decode(html, mosque: .dresden, now: today)
assertThat(table.timezoneIsVerified, "mosque timezone verified")
assertThat(table.days["2026-11-08"]?.count == 6, "parses six daily times")
let daily = PrayerClock.prayers(on: today, table: table)
assertThat(daily.count == 5, "five prayer rows")
assertThat(daily[0].iqama == "05:30", "relative iqama converted")
let next = PrayerClock.upcoming(after: today, table: table)!
assertThat(next.prayer.englishName == "Asr", "next prayer determined from date")
assertThat(next.countdown == "01:08:00", "countdown is derived from now, not fixed text")
let later = PrayerClock.upcoming(after: today.addingTimeInterval(20), table: table)!
assertThat(later.countdown == "01:07:40", "countdown decreases after 20s")
assertThat(next.progress >= 0 && next.progress <= 1, "progress in expected range")
let tomorrow = PrayerClock.upcoming(after: iso("2026-11-08T20:00:00Z"), table: table)!
assertThat(tomorrow.prayer.englishName == "Fajr", "next day fajr handled")

// Missing timezone fails closed until a user explicitly chooses a fallback.
var missingTZ = conf; missingTZ.removeValue(forKey: "timezone")
let blankTZHTML = Data("const confData = ".utf8) + (try JSONSerialization.data(withJSONObject: missingTZ))
do {
    _ = try MawaqitHTML.decode(blankTZHTML, mosque: .dresden, now: today)
    assertThat(false, "timezone without mosque or override should fail")
} catch MawaqitError.missingTimezone { assertThat(true, "missing timezone properly detected") }
let manual = try MawaqitHTML.decode(blankTZHTML, mosque: .dresden, now: today, fallbackTimezone: "Europe/Berlin")
assertThat(!manual.timezoneIsVerified, "manual timezone marked unverified")

// Geometric regression: a true-black two-ear crown protects the camera,
// rather than shifting the entire layout down by 72 blank points.
assertThat(NotchGeometry.contentClearance(topSafeArea: 0, isBuiltIn: true) == 48, "built-in display uses a tight 48pt safe crown")
assertThat(NotchGeometry.contentClearance(topSafeArea: 37, isBuiltIn: true) == 48, "37pt top inset gets just 11pt breathing room")
assertThat(NotchGeometry.contentClearance(topSafeArea: 60, isBuiltIn: true) == 65, "larger notch respects its measured inset")
assertThat(NotchGeometry.contentClearance(topSafeArea: 0, isBuiltIn: false) == 0, "notchless external display has no crown")
assertThat(NotchGeometry.contentClearance(topSafeArea: 42, isBuiltIn: false) == 47, "measured inset on other screens is respected")
assertThat(NotchGeometry.reservedCameraGap == 210, "camera-safe centre is 210pt wide")
assertThat(NotchGeometry.expandedHeight(clearance: 48, showSunrise: false, hasTimetable: true) == 386, "expanded island is about 25% shorter than the previous 512pt version")
assertThat(NotchGeometry.expandedHeight(clearance: 48, showSunrise: true, hasTimetable: true) == 410, "sunrise creates only one row of extra height")
assertThat(NotchGeometry.expandedHeight(clearance: 48, showSunrise: false, hasTimetable: false) == 278, "no-data island is shorter")
assertThat(NotchGeometry.compactTopOffset(clearance: 48) == 0, "compact notch ears start on the top edge")
assertThat(NotchGeometry.compactTopOffset(clearance: 0) == 8, "notchless pill is inset from the screen edge")
assertThat(NotchGeometry.compactWidth(clearance: 48, preferred: 246) == 396, "ears straddle notch at full available width")
assertThat(NotchGeometry.compactWidth(clearance: 0, preferred: 246) == 246, "notchless compact respects the user's preferred width")
print("PASS: \(checks) core and notch layout checks")
