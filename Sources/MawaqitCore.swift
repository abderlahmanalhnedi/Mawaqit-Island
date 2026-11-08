import Foundation

// Platform-independent domain, URL validation and parsing logic.
// This source intentionally contains no SuperIsland code or third-party dependencies.

enum MawaqitError: LocalizedError {
    case invalidURL
    case invalidSearch
    case badResponse
    case pageTooLarge
    case missingData
    case invalidData
    case noTimes
    case missingTimezone

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Enter a valid https://mawaqit.net mosque URL."
        case .invalidSearch: return "Search for a mosque name or city (2–80 characters)."
        case .badResponse: return "Mawaqit did not return a successful response."
        case .pageTooLarge: return "The response was larger than the permitted limit."
        case .missingData: return "The mosque page has no readable confData."
        case .invalidData: return "The Mawaqit data format has changed."
        case .noTimes: return "No reliable prayer timetable was found for today."
        case .missingTimezone: return "The mosque timezone is missing; choose one in Settings."
        }
    }
}

struct Mosque: Identifiable, Codable, Equatable, Hashable {
    var id: String { slug }
    let slug: String
    var name: String
    var locality: String
    var country: String

    var subtitle: String {
        [locality, country].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    var website: URL { URL(string: "https://mawaqit.net/en/\(slug)")! }

    static let dresden = Mosque(slug: "islamisches-zentrum-dresden-e-v-dresden-01157-germany",
                                name: "Islamisches Zentrum Dresden e.V.", locality: "Dresden", country: "Germany")
}

enum MosqueURLs {
    static func validSlug(_ s: String) -> Bool {
        !s.isEmpty && s.utf8.count <= 160 && s.allSatisfy { c in
            c.isASCII && (c.isLowercase || c.isNumber || c == "-")
        } && !s.hasPrefix("-") && !s.hasSuffix("-")
    }

    static func fromUserInput(_ text: String) -> Mosque? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: value), components.scheme?.lowercased() == "https",
              ["mawaqit.net", "www.mawaqit.net"].contains(components.host?.lowercased() ?? ""), components.user == nil,
              components.password == nil, components.port == nil else { return nil }
        let path = components.path.split(separator: "/").map(String.init)
        // Accept /en/slug, /ar/slug, /en/m/slug, /ar/m/slug.
        guard path.count == 2 || path.count == 3, ["ar", "en", "fr", "de", "nl", "es", "tr", "it"].contains(path[0]) else { return nil }
        if path.count == 3 && path[1] != "m" { return nil }
        let slug = path.last ?? ""
        guard validSlug(slug) else { return nil }
        return Mosque(slug: slug, name: slug.replacingOccurrences(of: "-", with: " "), locality: "", country: "")
    }
}

// Discovery is deliberately browser-driven: MAWAQIT's official API is
// private and search now requires authorized access. Do not call or attempt
// to bypass private endpoints from a community macOS application.
enum MosqueDiscovery {
    static func webSearchURL(_ raw: String) -> URL? {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(query.count),
              !query.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "site:mawaqit.net/ \(query)")]
        return components.url
    }
}

enum MosqueSearchParser {
    static func decode(_ data: Data) throws -> [Mosque] {
        guard data.count <= 2_000_000 else { throw MawaqitError.pageTooLarge }
        let json = try JSONSerialization.jsonObject(with: data)
        let entries: [Any]
        if let list = json as? [Any] { entries = list }
        else if let obj = json as? [String: Any] {
            let candidate = obj["data"] ?? obj["mosques"] ?? obj["results"]
            if let list = candidate as? [Any] { entries = list }
            else if let nested = candidate as? [String: Any], let list = nested["data"] as? [Any] { entries = list }
            else { throw MawaqitError.invalidData }
        } else { throw MawaqitError.invalidData }
        var seen = Set<String>()
        return entries.compactMap { item -> Mosque? in
            guard let d = item as? [String: Any] else { return nil }
            func string(_ keys: [String]) -> String {
                for key in keys { if let s = d[key] as? String, !s.isEmpty { return String(s.prefix(150)) } }
                return ""
            }
            let rawSlug = string(["slug", "mosque_slug"])
            let slug: String
            if MosqueURLs.validSlug(rawSlug) { slug = rawSlug }
            else if let parsed = MosqueURLs.fromUserInput(rawSlug) { slug = parsed.slug }
            else { return nil }
            guard seen.insert(slug).inserted else { return nil }
            return Mosque(slug: slug,
                          name: string(["label", "name", "mosqueName"]).isEmpty ? slug : string(["label", "name", "mosqueName"]),
                          locality: string(["locality", "city"]), country: string(["country"]))
        }
    }
}

struct Timetable: Codable {
    var slug: String
    var year: Int
    var updatedAt: Date
    var timezoneID: String
    var timezoneIsVerified: Bool
    var days: [String: [String]]
    var iqamaDays: [String: [String]]
    var mosqueName: String?

    var timeZone: TimeZone? { TimeZone(identifier: timezoneID) }
}

struct Prayer: Identifiable, Equatable {
    var id: Int
    var englishName: String
    var arabicName: String
    var time: String
    var date: Date
    var iqama: String?
}

struct UpcomingPrayer {
    let prayer: Prayer
    let previous: Date?
    let seconds: TimeInterval

    var countdown: String {
        let n = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d:%02d", n / 3600, n / 60 % 60, n % 60)
    }
    var progress: Double {
        guard let previous else { return 0 }
        let interval = prayer.date.timeIntervalSince(previous)
        return interval > 0 ? max(0, min(1, 1 - seconds / interval)) : 0
    }
}

enum PrayerClock {
    static let names = [
        ("Fajr", "الفجر", 0), ("Dhuhr", "الظهر", 2),
        ("Asr", "العصر", 3), ("Maghrib", "المغرب", 4),
        ("Isha", "العشاء", 5)
    ]

    static func calendar(_ zone: TimeZone) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = zone
        return result
    }
    static func key(_ date: Date, in zone: TimeZone) -> String {
        let c = calendar(zone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func noon(year: Int, month: Int, day: Int, zone: TimeZone) -> Date? {
        var d = DateComponents()
        d.timeZone = zone; d.year = year; d.month = month; d.day = day; d.hour = 12
        return calendar(zone).date(from: d)
    }
    static func timestamp(on day: Date, hhmm: String, zone: TimeZone) -> Date? {
        let bits = hhmm.split(separator: ":")
        guard bits.count == 2, let h = Int(bits[0]), let m = Int(bits[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        let c = calendar(zone).dateComponents([.year, .month, .day], from: day)
        var d = DateComponents()
        d.timeZone = zone; d.year = c.year; d.month = c.month; d.day = c.day
        d.hour = h; d.minute = m; d.second = 0
        return calendar(zone).date(from: d)
    }
    static func prayers(on date: Date, table: Timetable?) -> [Prayer] {
        guard let table, let zone = table.timeZone,
              let row = table.days[key(date, in: zone)], row.count == 6 else { return [] }
        let iqama = table.iqamaDays[key(date, in: zone)]
        return names.enumerated().compactMap { (i, value) -> Prayer? in
            let (english, arabic, index) = value
            guard let instant = timestamp(on: date, hhmm: row[index], zone: zone) else { return nil }
            let iqamaText: String?
            if let iqama, iqama.count >= 5 {
                let raw = iqama[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.hasPrefix("+"), let minutes = Int(raw.dropFirst()), (0...180).contains(minutes) {
                    let added = calendar(zone).date(byAdding: .minute, value: minutes, to: instant) ?? instant
                    let parts = calendar(zone).dateComponents([.hour, .minute], from: added)
                    iqamaText = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
                } else { iqamaText = normalizedTime(raw) }
            } else { iqamaText = nil }
            return Prayer(id: i, englishName: english, arabicName: arabic,
                          time: row[index], date: instant, iqama: iqamaText)
        }
    }
    static func upcoming(after now: Date, table: Timetable?) -> UpcomingPrayer? {
        guard let table, let zone = table.timeZone else { return nil }
        let cal = calendar(zone)
        var previous: Date?
        for offset in [-1, 0, 1] {
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            for prayer in prayers(on: date, table: table) {
                if prayer.date > now { return UpcomingPrayer(prayer: prayer, previous: previous, seconds: prayer.date.timeIntervalSince(now)) }
                previous = prayer.date
            }
        }
        return nil
    }
    static func normalizedTime(_ text: String) -> String? {
        let bits = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard (bits.count == 2 || bits.count == 3), let hour = Int(bits[0]), let minute = Int(bits[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }
}

enum MawaqitHTML {
    // Mawaqit puts JSON directly after the confData assignment. Scan quote-aware braces.
    static func embeddedJSON(_ html: Data) throws -> Data {
        guard html.count <= 3_000_000 else { throw MawaqitError.pageTooLarge }
        let bytes = Array(html)
        let needle = Array("confData".utf8)
        guard bytes.count >= needle.count else { throw MawaqitError.missingData }
        var start: Int? = nil
        for i in 0...(bytes.count - needle.count) {
            if bytes[i] != needle[0] || !bytes[i..<(i + needle.count)].elementsEqual(needle) { continue }
            var p = i + needle.count
            while p < bytes.count && [9,10,13,32].contains(bytes[p]) { p += 1 }
            guard p < bytes.count && bytes[p] == 61 else { continue }
            p += 1
            while p < bytes.count && [9,10,13,32].contains(bytes[p]) { p += 1 }
            if p < bytes.count && bytes[p] == 123 { start = p; break }
        }
        guard let begin = start else { throw MawaqitError.missingData }
        var quote = false, escape = false, depth = 0
        for i in begin..<bytes.count {
            let b = bytes[i]
            if quote {
                if escape { escape = false }
                else if b == 92 { escape = true }
                else if b == 34 { quote = false }
            } else {
                if b == 34 { quote = true }
                else if b == 123 { depth += 1 }
                else if b == 125 {
                    depth -= 1
                    if depth == 0 { return Data(bytes[begin...i]) }
                }
            }
        }
        throw MawaqitError.invalidData
    }

    private static func monthRows(_ months: [Any], year: Int, zone: TimeZone, six: Bool) -> [String: [String]] {
        guard months.count == 12 else { return [:] }
        var output: [String: [String]] = [:]
        for month in 1...12 {
            guard let first = PrayerClock.noon(year: year, month: month, day: 1, zone: zone),
                  let days = PrayerClock.calendar(zone).range(of: .day, in: .month, for: first) else { continue }
            let source = months[month - 1]
            for day in days {
                let raw: Any?
                if let dict = source as? [String: Any] { raw = dict[String(day)] ?? dict[String(format: "%02d", day)] }
                else if let array = source as? [Any] {
                    let index = array.count == days.count + 1 ? day : day - 1
                    raw = array.indices.contains(index) ? array[index] : nil
                } else { raw = nil }
                guard let row = raw as? [Any] else { continue }
                var times = row.compactMap { $0 as? String }
                if six && (times.count == 6 || times.count == 7) { times = Array(times.suffix(6)) }
                else if !six && (times.count == 5 || times.count == 6) { times = Array(times.suffix(5)) }
                else { continue }
                if six {
                    let normalized = times.compactMap(PrayerClock.normalizedTime)
                    guard normalized.count == 6, let date = PrayerClock.noon(year: year, month: month, day: day, zone: zone) else { continue }
                    output[PrayerClock.key(date, in: zone)] = normalized
                } else {
                    guard let date = PrayerClock.noon(year: year, month: month, day: day, zone: zone) else { continue }
                    output[PrayerClock.key(date, in: zone)] = times.map { String($0.prefix(24)) }
                }
            }
        }
        return output
    }

    static func decode(_ html: Data, mosque: Mosque, now: Date = Date(), fallbackTimezone: String? = nil) throws -> Timetable {
        let json = try embeddedJSON(html)
        guard let conf = try JSONSerialization.jsonObject(with: json) as? [String: Any] else { throw MawaqitError.invalidData }
        let providedTZ = conf["timezone"] as? String ?? ""
        let verified = TimeZone(identifier: providedTZ) != nil
        let timezoneID: String
        if verified { timezoneID = providedTZ }
        else if let override = fallbackTimezone, TimeZone(identifier: override) != nil { timezoneID = override }
        else { throw MawaqitError.missingTimezone }
        guard let zone = TimeZone(identifier: timezoneID) else { throw MawaqitError.missingTimezone }
        let year = PrayerClock.calendar(zone).component(.year, from: now)
        guard let months = conf["calendar"] as? [Any] else { throw MawaqitError.invalidData }
        let days = monthRows(months, year: year, zone: zone, six: true)
        guard days[PrayerClock.key(now, in: zone)] != nil else { throw MawaqitError.noTimes }
        let iqama = conf["iqamaCalendar"] as? [Any] ?? []
        return Timetable(slug: mosque.slug, year: year, updatedAt: now,
                         timezoneID: timezoneID, timezoneIsVerified: verified,
                         days: days, iqamaDays: monthRows(iqama, year: year, zone: zone, six: false),
                         mosqueName: (conf["name"] as? String).map { String($0.prefix(160)) })
    }
}
