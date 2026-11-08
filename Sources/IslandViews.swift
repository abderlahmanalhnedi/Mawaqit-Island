import SwiftUI
import AppKit

// Original Mawaqit-inspired interface; black notch ears, subtle purple
// accents, no third-party artwork or copied code.
enum IslandStyle {
    static func accent(_ theme: IslandPreferences.Theme) -> Color {
        switch theme {
        case .mawaqit: return Color(red: 0.72, green: 0.48, blue: 1.0)
        case .midnight: return Color(red: 0.36, green: 0.76, blue: 1.0)
        case .charcoal: return Color(red: 0.91, green: 0.91, blue: 0.96)
        }
    }
    static func background(_ theme: IslandPreferences.Theme) -> Color {
        switch theme {
        case .mawaqit: return Color(red: 0.045, green: 0.027, blue: 0.075)
        case .midnight: return Color(red: 0.019, green: 0.034, blue: 0.063)
        case .charcoal: return Color(red: 0.026, green: 0.026, blue: 0.032)
        }
    }
    static let text = Color(red: 0.97, green: 0.96, blue: 1.0)
    static let muted = Color(red: 0.68, green: 0.65, blue: 0.75)
    static let success = Color(red: 0.38, green: 0.89, blue: 0.70)
}

private struct CapsuleButton: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.77))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.075), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct IslandContent: View {
    @ObservedObject var model: IslandModel
    let expanded: Bool
    let notchTopClearance: CGFloat
    let expand: () -> Void
    let collapse: () -> Void
    let hide: () -> Void
    let settings: () -> Void
    let refresh: () -> Void
    let openWebsite: () -> Void

    private var accent: Color { IslandStyle.accent(model.preferences.theme) }
    private var base: Color { IslandStyle.background(model.preferences.theme) }
    private var zone: TimeZone { model.timetable?.timeZone ?? .current }
    private var upcoming: UpcomingPrayer? { PrayerClock.upcoming(after: model.now, table: model.timetable) }
    private var hasCrown: Bool { NotchGeometry.hasCameraSafeEars(notchTopClearance) }
    private func label(_ ar: String, _ en: String, _ de: String) -> String {
        model.preferences.label(ar: ar, en: en, de: de)
    }
    private func name(_ prayer: Prayer) -> String {
        model.preferences.language == .arabic ? prayer.arabicName : prayer.englishName
    }
    private var heading: String {
        model.selected?.name ?? label("اختر المسجد", "Choose mosque", "Moschee auswählen")
    }
    private var panelWidth: CGFloat {
        expanded ? NotchGeometry.expandedWidth :
            NotchGeometry.compactWidth(clearance: notchTopClearance,
                                       preferred: CGFloat(model.preferences.compactWidth))
    }
    private var panelHeight: CGFloat {
        expanded ? NotchGeometry.expandedHeight(clearance: notchTopClearance,
            showSunrise: model.preferences.showSunrise, hasTimetable: model.timetable != nil)
            : NotchGeometry.compactBodyHeight
    }

    var body: some View {
        Group {
            if expanded {
                expandedView
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(base)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(LinearGradient(colors: [accent.opacity(0.12), .clear, .clear],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(accent.opacity(0.14), lineWidth: 0.7)
                    }
                    .shadow(color: .black.opacity(0.30), radius: 18, y: 8)
            } else if hasCrown {
                compactEars
            } else {
                compactPill
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .animation(.spring(response: 0.29, dampingFraction: 0.87), value: expanded)
    }

    // A native-like compact island: the hardware camera lives in the CLEAR
    // middle gap, so all glyphs are in two tiny black side wings.
    private var compactEars: some View {
        HStack(spacing: 0) {
            Button(action: expand) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(accent).font(.system(size: 12))
                    Text(upcoming.map { name($0.prayer) } ?? "MAWAQIT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(IslandStyle.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: NotchGeometry.notchEarWidth, height: 30)
                .background(.black, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            Spacer(minLength: NotchGeometry.cameraGuardWidth)
            Button(action: expand) {
                Text(upcoming?.countdown ?? "--:--")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(IslandStyle.text)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: NotchGeometry.notchEarWidth, height: 30)
                    .background(.black, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 5)
    }

    private var compactPill: some View {
        Button(action: expand) {
            HStack(spacing: 8) {
                Image(systemName: "moon.stars.fill").foregroundStyle(accent)
                Text(upcoming.map { name($0.prayer) } ?? "Mawaqit")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(upcoming?.countdown ?? "--:--")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(IslandStyle.text)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(.black, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // The hardware-safe crown is not empty: both narrow sides hold controls,
    // and the centre is clear for the camera. It also works with notch-free
    // displays (no crown, actions move to the regular header).
    @ViewBuilder private var crown: some View {
        if hasCrown {
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(accent)
                    Text("MAWAQIT")
                        .foregroundStyle(IslandStyle.text.opacity(0.86))
                        .tracking(0.5)
                }
                .font(.system(size: 9, weight: .bold))
                .frame(width: NotchGeometry.notchEarWidth, alignment: .leading)
                Spacer(minLength: NotchGeometry.cameraGuardWidth)
                HStack(spacing: 5) {
                    CapsuleButton(symbol: "gearshape", action: settings).help("Settings")
                    CapsuleButton(symbol: "xmark", action: hide).help("Hide")
                }
                .frame(width: NotchGeometry.notchEarWidth, alignment: .trailing)
            }
            .padding(.horizontal, 5)
            .padding(.top, 6)
            .frame(height: notchTopClearance, alignment: .top)
        }
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            crown
            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(heading)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(IslandStyle.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(model.errorMessage == nil && model.timetable != nil ? IslandStyle.success : accent)
                                .frame(width: 5, height: 5)
                            Text(model.selected?.subtitle.isEmpty == false ? model.selected!.subtitle : "MAWAQIT · COMMUNITY")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(IslandStyle.muted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 6)
                    if !hasCrown {
                        CapsuleButton(symbol: "gearshape", action: settings)
                        CapsuleButton(symbol: "xmark", action: hide)
                    }
                    CapsuleButton(symbol: "chevron.up", action: collapse).help("Collapse")
                }
                .frame(height: 38)

                if let next = upcoming {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(label("الصلاة القادمة", "NEXT PRAYER", "NÄCHSTES GEBET"))
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(accent)
                            Text(next.countdown)
                                .font(.system(size: 30, weight: .semibold, design: .monospaced))
                                .monospacedDigit()
                                .contentTransition(.numericText(countsDown: true))
                                .foregroundStyle(IslandStyle.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            HStack(spacing: 6) {
                                Text(name(next.prayer)).fontWeight(.semibold)
                                Text("·").foregroundStyle(IslandStyle.muted)
                                Text(next.prayer.time).monospacedDigit()
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(IslandStyle.text.opacity(0.80))
                        }
                        Spacer(minLength: 2)
                        ZStack {
                            Circle().stroke(accent.opacity(0.15), lineWidth: 5)
                            Circle().trim(from: 0, to: next.progress)
                                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(accent)
                        }
                        .frame(width: 51, height: 51)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 86)
                    .background(accent.opacity(0.085), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(model.selected == nil ? label("اختر مسجدك", "Choose your mosque", "Moschee auswählen") :
                             label("المواقيت غير متاحة", "Prayer times unavailable", "Gebetszeiten nicht verfügbar"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(model.errorMessage ?? "Choose a mosque in Settings to load prayer times.")
                            .font(.system(size: 11)).foregroundStyle(IslandStyle.muted)
                            .lineLimit(2)
                        Button(action: settings) {
                            Label("Choose mosque", systemImage: "magnifyingglass")
                        }.buttonStyle(.borderedProminent).tint(accent).controlSize(.small)
                    }
                    .foregroundStyle(IslandStyle.text)
                    .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(accent.opacity(0.085), in: RoundedRectangle(cornerRadius: 15))
                }

                if model.timetable != nil {
                    HStack(spacing: 4) {
                        Text(label("مواقيت اليوم", "TODAY", "HEUTE"))
                            .font(.system(size: 10, weight: .bold)).tracking(0.5)
                        Spacer()
                        Text(localDate).font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(IslandStyle.muted)
                    .frame(height: 22)

                    VStack(spacing: 1) {
                        let todays = PrayerClock.prayers(on: model.now, table: model.timetable)
                        ForEach(todays) { prayer in
                            let active = upcoming?.prayer.englishName == prayer.englishName &&
                                PrayerClock.key(prayer.date, in: zone) == PrayerClock.key(model.now, in: zone)
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(active ? accent : .clear)
                                    .frame(width: 3, height: 15)
                                Text(name(prayer))
                                    .font(.system(size: 11, weight: active ? .bold : .medium))
                                    .foregroundStyle(IslandStyle.text.opacity(active ? 1 : 0.78))
                                Spacer(minLength: 4)
                                if model.preferences.showIqama, let iqama = prayer.iqama {
                                    Text(label("إقامة", "Iqama", "Iqama") + " " + iqama)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(IslandStyle.muted)
                                }
                                Text(prayer.time)
                                    .font(.system(size: 12, weight: active ? .bold : .medium, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(active ? accent : IslandStyle.text)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(active ? accent.opacity(0.13) : .clear,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        if model.preferences.showSunrise, let table = model.timetable,
                           let row = table.days[PrayerClock.key(model.now, in: zone)], row.count >= 2 {
                            HStack {
                                Image(systemName: "sunrise.fill").font(.system(size: 10))
                                Text(label("الشروق", "Sunrise", "Sonnenaufgang"))
                                Spacer()
                                Text(row[1]).monospacedDigit()
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(IslandStyle.muted)
                            .padding(.horizontal, 11)
                            .frame(height: 24)
                        }
                    }
                }

                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.errorMessage == nil && model.timetable != nil ? IslandStyle.success : accent)
                        .frame(width: 5, height: 5)
                    Text(model.selectionInfo())
                        .font(.system(size: 9))
                        .foregroundStyle(IslandStyle.muted)
                        .lineLimit(1)
                    Spacer(minLength: 5)
                    CapsuleButton(symbol: "arrow.clockwise", action: refresh).help("Sync now")
                    CapsuleButton(symbol: "arrow.up.right", action: openWebsite).help("Mawaqit")
                }
                .frame(height: 24)
            }
            .padding(.horizontal, 13)
            .padding(.top, 6)
            .padding(.bottom, 9)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var localDate: String {
        let f = DateFormatter()
        f.timeZone = zone
        f.dateFormat = "dd MMM yyyy"
        f.locale = Locale(identifier: model.preferences.language == .arabic ? "ar-u-nu-latn" : model.preferences.language == .german ? "de" : "en")
        return f.string(from: model.now)
    }
}

struct PreferencesView: View {
    @ObservedObject var model: IslandModel
    let choose: (Mosque) -> Void
    let close: () -> Void
    @State private var query = ""
    @State private var manualURL = ""
    @State private var manualError: String?
    @State private var launchAtLogin = false
    @State private var loginItemError: String?

    private var accent: Color { IslandStyle.accent(model.preferences.theme) }
    private func label(_ ar: String, _ en: String, _ de: String) -> String {
        model.preferences.label(ar: ar, en: en, de: de)
    }
    private func openDiscovery() {
        guard let url = MosqueDiscovery.webSearchURL(query) else {
            manualError = label("اكتب اسم مدينة أو مسجد من حرفين على الأقل.",
                                "Enter at least two letters for the city or mosque.",
                                "Bitte mindestens zwei Zeichen eingeben.")
            return
        }
        manualError = nil
        NSWorkspace.shared.open(url)
    }
    private func useURL(_ value: String) {
        if let mosque = MosqueURLs.fromUserInput(value) {
            manualError = nil
            choose(mosque)
        } else {
            manualError = label("الرابط غير صالح. انسخ رابط المسجد من mawaqit.net (https).",
                                "Paste an HTTPS mosque page link from mawaqit.net.",
                                "Bitte einen HTTPS-Moschee-Link von mawaqit.net einfügen.")
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 26)).foregroundStyle(accent)
                        .frame(width: 48, height: 48)
                        .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mawaqit Island")
                            .font(.system(size: 25, weight: .bold))
                        Text("A community-built island for your mosque · v0.4.2")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Done", action: close).keyboardShortcut(.defaultAction)
                }

                sectionTitle(label("ابحث عن مسجدك", "Find your mosque", "Moschee finden"), symbol: "magnifyingglass")
                HStack(spacing: 8) {
                    TextField(label("مدينة أو اسم مسجد (مثال: Berlin)",
                                    "City or mosque name (e.g. Berlin)",
                                    "Stadt oder Moschee (z. B. Berlin)"), text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(openDiscovery)
                    Button {
                        openDiscovery()
                    } label: {
                        Label(label("ابحث على الويب", "Find on the web", "Im Web suchen"),
                              systemImage: "safari")
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
                Text(label("سيفتح البحث في المتصفح. انسخ رابط صفحة المسجد من نتائج Mawaqit ثم ارجع واضغط «استيراد الرابط المنسوخ». لا يتطلب البحث حساب Mawaqit.",
                           "Search opens your browser. Copy a mosque's Mawaqit page link, then return and choose ‘Import copied link’. No MAWAQIT account needed.",
                           "Die Suche öffnet den Browser. Kopiere den Mawaqit-Moscheelink und wähle dann „Kopierten Link importieren“. Kein Mawaqit-Konto nötig."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 7) {
                    TextField("https://mawaqit.net/en/m/your-mosque-slug", text: $manualURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { useURL(manualURL) }
                    Button(label("استخدم الرابط", "Use URL", "Link verwenden")) {
                        useURL(manualURL)
                    }
                    .disabled(manualURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        let copied = NSPasteboard.general.string(forType: .string) ?? ""
                        manualURL = copied
                        useURL(copied)
                    } label: {
                        Label(label("استيراد الرابط المنسوخ", "Import copied link", "Kopierten Link importieren"),
                              systemImage: "doc.on.clipboard")
                    }
                }
                if let manualError { Text(manualError).font(.caption).foregroundStyle(.orange) }

                if !model.favorites.isEmpty {
                    sectionTitle("Saved mosques", symbol: "star.fill")
                    ForEach(model.favorites) { mosque in
                        HStack {
                            mosqueRow(mosque)
                            Button(role: .destructive) { model.removeFavorite(mosque) } label: {
                                Image(systemName: "minus.circle").foregroundStyle(.secondary)
                            }.buttonStyle(.plain).help("Remove from saved mosques")
                        }
                    }
                }

                sectionTitle("Appearance & interaction", symbol: "paintbrush")
                GroupBox {
                    VStack(alignment: .leading, spacing: 13) {
                        Picker("Theme", selection: $model.preferences.theme) {
                            ForEach(IslandPreferences.Theme.allCases) { theme in Text(theme.rawValue).tag(theme) }
                        }
                        Picker("Language", selection: $model.preferences.language) {
                            ForEach(IslandPreferences.Language.allCases) { option in Text(option.rawValue).tag(option) }
                        }
                        Picker("Display", selection: $model.preferences.display) {
                            ForEach(IslandPreferences.Display.allCases) { option in Text(option.rawValue).tag(option) }
                        }
                        Toggle(label("تشغيل التطبيق بعد تسجيل الدخول", "Launch at login", "Beim Anmelden starten"),
                               isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                do {
                                    try LaunchAtLogin.setEnabled(newValue)
                                    launchAtLogin = LaunchAtLogin.enabled
                                    loginItemError = nil
                                } catch {
                                    launchAtLogin = LaunchAtLogin.enabled
                                    loginItemError = error.localizedDescription
                                }
                            }
                        if let loginItemError {
                            Text(label("تعذر تفعيل بدء التشغيل. راجع عناصر تسجيل الدخول في إعدادات النظام.",
                                       "Couldn't change login startup. Review Login Items in System Settings.",
                                       "Autostart konnte nicht geändert werden. Bitte Anmeldeobjekte in den Systemeinstellungen prüfen.")
                                 + " " + loginItemError)
                                .font(.caption).foregroundStyle(.orange)
                        }
                        Toggle("Open when hovering near the notch", isOn: $model.preferences.showOnHover)
                        Toggle("Keep compact pill always visible (optional)", isOn: $model.preferences.alwaysShowCompact)
                        Toggle("Show iqama when published", isOn: $model.preferences.showIqama)
                        Toggle("Show sunrise", isOn: $model.preferences.showSunrise)
                        Toggle("Brief reminder 5 minutes before prayer", isOn: $model.preferences.reminder5Minutes)
                        HStack {
                            Text("Compact width")
                            Slider(value: $model.preferences.compactWidth, in: 210...320, step: 2)
                            Text("\(Int(model.preferences.compactWidth)) px").monospacedDigit().frame(width: 58)
                        }
                        HStack {
                            Text("Hover expand delay")
                            Slider(value: $model.preferences.hoverDelay, in: 0.15...1.5, step: 0.05)
                            Text(String(format: "%.2fs", model.preferences.hoverDelay)).monospacedDigit().frame(width: 55)
                        }
                        HStack {
                            Text("Auto hide delay")
                            Slider(value: $model.preferences.hideDelay, in: 0.3...3.0, step: 0.1)
                            Text(String(format: "%.1fs", model.preferences.hideDelay)).monospacedDigit().frame(width: 55)
                        }
                    }.padding(10)
                }

                sectionTitle("Prayer data", symbol: "clock.arrow.circlepath")
                GroupBox {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Timezone is read from the chosen mosque's page. If Mawaqit omits it, enter an IANA timezone manually (for example Europe/Berlin).")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("Optional timezone override (IANA)", text: $model.preferences.timezoneOverride)
                            .textFieldStyle(.roundedBorder)
                        if !model.preferences.timezoneOverride.isEmpty && TimeZone(identifier: model.preferences.timezoneOverride) == nil {
                            Text("Unknown timezone. Use a valid value such as Europe/Berlin.")
                                .font(.caption).foregroundStyle(.red)
                        }
                        Text(model.selectionInfo()).font(.caption).foregroundStyle(.secondary)
                        if let error = model.errorMessage { Text("Last sync error: \(error)").font(.caption).foregroundStyle(.orange) }
                        Button("Refresh prayer times") { Task { await model.refresh(force: true) } }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }

                Text("UNOFFICIAL COMMUNITY PROJECT · Not affiliated with MAWAQIT. Data from mosque-owned public Mawaqit pages. No account or location permission required.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 740, alignment: .leading)
        }
        .frame(minWidth: 600, minHeight: 620)
        .onAppear { launchAtLogin = LaunchAtLogin.enabled }
    }

    private func sectionTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 16, weight: .semibold))
            .padding(.top, 4)
    }
    private func mosqueRow(_ mosque: Mosque) -> some View {
        Button { choose(mosque) } label: {
            HStack(spacing: 10) {
                Image(systemName: "building.columns.fill").foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mosque.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if !mosque.subtitle.isEmpty { Text(mosque.subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if model.selected?.slug == mosque.slug { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                else { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
            }
            .padding(9)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}
