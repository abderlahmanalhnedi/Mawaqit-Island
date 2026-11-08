import Foundation
import Combine

struct IslandPreferences: Codable, Equatable {
    enum Theme: String, CaseIterable, Codable, Identifiable {
        case mawaqit = "Mawaqit Purple"
        case midnight = "Midnight Blue"
        case charcoal = "Pure Black"
        var id: String { rawValue }
    }
    enum Language: String, CaseIterable, Codable, Identifiable {
        case arabic = "العربية"
        case english = "English"
        case german = "Deutsch"
        var id: String { rawValue }
    }
    enum Display: String, CaseIterable, Codable, Identifiable {
        case builtIn = "Built-in display"
        case main = "Primary display"
        case pointer = "Display under pointer"
        var id: String { rawValue }
    }

    var theme: Theme = .mawaqit
    var language: Language = .arabic
    var display: Display = .builtIn
    var showOnHover = true
    var alwaysShowCompact = false
    var showIqama = true
    var showSunrise = false
    var reminder5Minutes = false
    var compactWidth = 246.0
    var hoverDelay = 0.44
    var hideDelay = 0.92
    // Used only when Mawaqit does not publish an IANA timezone; user must select deliberately.
    var timezoneOverride = ""

    func label(ar: String, en: String, de: String) -> String {
        switch language {
        case .arabic: return ar
        case .english: return en
        case .german: return de
        }
    }
}

@MainActor
final class IslandModel: ObservableObject {
    @Published var now = Date()
    @Published var preferences: IslandPreferences = IslandPreferences() {
        didSet { savePreferences() }
    }
    @Published private(set) var selected: Mosque?
    @Published private(set) var favorites: [Mosque] = []
    @Published private(set) var timetable: Timetable?
    @Published private(set) var syncing = false
    @Published private(set) var errorMessage: String?

    private let defaults = UserDefaults.standard
    private var ticking: Timer?
    private var polling: Timer?
    private var lastAttempt: Date?

    init() {
        if let bytes = defaults.data(forKey: "preferences-v3"),
           let stored = try? JSONDecoder().decode(IslandPreferences.self, from: bytes) {
            preferences = stored
        }
        if let bytes = defaults.data(forKey: "favorites-v3"),
           let stored = try? JSONDecoder().decode([Mosque].self, from: bytes) {
            favorites = stored.filter { MosqueURLs.validSlug($0.slug) }
        }
        if let bytes = defaults.data(forKey: "selected-v3"),
           let stored = try? JSONDecoder().decode(Mosque.self, from: bytes),
           MosqueURLs.validSlug(stored.slug) { selected = stored }
        // Existing Dresden users keep their mosque; fresh installs start with the selector.
        if selected == nil, legacyCacheURL.map({ FileManager.default.fileExists(atPath: $0.path) }) == true {
            selected = .dresden
            favorites = [.dresden]
            persistSelection()
        }
        loadCache()
        let seconds = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.now = Date() }
        }
        RunLoop.main.add(seconds, forMode: .common)
        ticking = seconds
        let sync = Timer(timeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(sync, forMode: .common)
        polling = sync
    }

    func updateMosque(_ mosque: Mosque) {
        guard MosqueURLs.validSlug(mosque.slug) else { return }
        let changed = selected?.slug != mosque.slug
        selected = mosque
        favorites.removeAll { $0.slug == mosque.slug }
        favorites.insert(mosque, at: 0)
        favorites = Array(favorites.prefix(20))
        persistSelection()
        if changed {
            timetable = nil
            errorMessage = nil
            lastAttempt = nil
            loadCache()
            Task { @MainActor in await refresh(force: true) }
        }
    }

    func removeFavorite(_ mosque: Mosque) {
        favorites.removeAll { $0.slug == mosque.slug }
        defaults.set(try? JSONEncoder().encode(favorites), forKey: "favorites-v3")
        if selected?.slug == mosque.slug {
            selected = nil; timetable = nil; errorMessage = nil
            defaults.removeObject(forKey: "selected-v3")
        }
    }

    private func persistSelection() {
        defaults.set(try? JSONEncoder().encode(selected), forKey: "selected-v3")
        defaults.set(try? JSONEncoder().encode(favorites), forKey: "favorites-v3")
    }
    private func savePreferences() {
        defaults.set(try? JSONEncoder().encode(preferences), forKey: "preferences-v3")
    }

    private var baseCacheURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("MawaqitIsland", isDirectory: true)
    }
    private var legacyCacheURL: URL? {
        baseCacheURL?.appendingPathComponent("mosque-13729.json")
    }
    private func cacheURL(for slug: String) -> URL? {
        guard MosqueURLs.validSlug(slug) else { return nil }
        return baseCacheURL?.appendingPathComponent("v3-\(slug).json")
    }
    private func loadCache() {
        guard let selected else { return }
        if let url = cacheURL(for: selected.slug),
           let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder().decode(Timetable.self, from: data),
           cached.slug == selected.slug, cached.timeZone != nil {
            timetable = cached
            return
        }
        // Read-only migration from the v0.2 Dresden cache.
        guard selected.slug == Mosque.dresden.slug, let path = legacyCacheURL,
              let data = try? Data(contentsOf: path),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let year = raw["year"] as? Int, let days = raw["days"] as? [String: [String]] else { return }
        timetable = Timetable(slug: selected.slug, year: year,
                              updatedAt: (raw["savedAt"] as? Date) ?? .distantPast,
                              timezoneID: "Europe/Berlin", timezoneIsVerified: false,
                              days: days, iqamaDays: [:], mosqueName: selected.name)
    }

    private static func fetch(_ url: URL, accept: String, maximum: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              http.url?.scheme == "https", http.url?.host == "mawaqit.net" else { throw MawaqitError.badResponse }
        guard bytes.count <= maximum else { throw MawaqitError.pageTooLarge }
        return bytes
    }

    func refresh(force: Bool = false) async {
        guard let mosque = selected, !syncing else { return }
        let current = Date()
        if !force, let lastAttempt {
            let interval = errorMessage == nil ? 2 * 3600.0 : 5 * 60.0
            let currentYear = PrayerClock.calendar(timetable?.timeZone ?? TimeZone.current).component(.year, from: current)
            if current.timeIntervalSince(lastAttempt) < interval && timetable?.year == currentYear { return }
        }
        syncing = true; lastAttempt = current
        defer {
            syncing = false
            // If a different mosque was chosen while the request was in flight,
            // start its first sync instead of waiting for the periodic poll.
            if selected?.slug != mosque.slug && selected != nil {
                Task { @MainActor in await refresh(force: true) }
            }
        }
        do {
            let html = try await Self.fetch(mosque.website, accept: "text/html", maximum: 3_000_000)
            let result = try MawaqitHTML.decode(html, mosque: mosque, now: Date(),
                                                fallbackTimezone: preferences.timezoneOverride.isEmpty ? nil : preferences.timezoneOverride)
            guard selected?.slug == mosque.slug else { return }
            timetable = result; errorMessage = nil
            if let publishedName = result.mosqueName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !publishedName.isEmpty, let active = selected, active.slug == mosque.slug,
               active.name != publishedName {
                let updated = Mosque(slug: active.slug, name: publishedName,
                                     locality: active.locality, country: active.country)
                selected = updated
                favorites = favorites.map { $0.slug == updated.slug ? updated : $0 }
                persistSelection()
            }
            if let path = cacheURL(for: mosque.slug) {
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(result).write(to: path, options: .atomic)
            }
        } catch {
            guard selected?.slug == mosque.slug else { return }
            errorMessage = error.localizedDescription
            NSLog("[Mawaqit Island] Refresh failed: %@", error.localizedDescription)
        }
    }

    func selectionInfo() -> String {
        guard selected != nil else { return "Choose a mosque" }
        if syncing { return "Syncing prayer times…" }
        guard let timetable else { return errorMessage ?? "No reliable timetable available" }
        if errorMessage != nil { return "Offline cache · sync failed" }
        let age = Date().timeIntervalSince(timetable.updatedAt)
        if age > 6 * 3600 { return "Cached times · last sync over 6h ago" }
        let date = DateFormatter()
        date.dateFormat = "HH:mm"; date.timeZone = timetable.timeZone
        let tz = timetable.timezoneIsVerified ? "" : " · timezone not confirmed"
        return "Synced \(date.string(from: timetable.updatedAt))\(tz)"
    }
}
