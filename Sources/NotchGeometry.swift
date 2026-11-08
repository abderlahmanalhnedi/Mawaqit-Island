import Foundation

/// All dimensions are in macOS points. The notch-safe layout is split into
/// two *ears* (outside the camera), plus a compact body BELOW the camera.
/// There is no empty 72pt spacer; the crown is useful UI space.
enum NotchGeometry {
    static let expandedWidth: CGFloat = 396
    static let notchEarWidth: CGFloat = 88
    static let cameraGuardWidth: CGFloat = 210
    static let compactBodyHeight: CGFloat = 32
    static let crownFallback: CGFloat = 48
    static let crownSafetyGap: CGFloat = 5
    static let baseBodyHeight: CGFloat = 338

    static func contentClearance(topSafeArea: CGFloat, isBuiltIn: Bool) -> CGFloat {
        let measured = max(0, topSafeArea)
        if isBuiltIn {
            // 48pt covers the tested MacBook camera housing with a small gap;
            // for other hardware, always defer to the larger measured inset.
            return max(crownFallback, ceil(measured) + crownSafetyGap)
        }
        guard measured > 0 else { return 0 }
        return ceil(measured) + crownSafetyGap
    }

    static func expandedBodyHeight(showSunrise: Bool, hasTimetable: Bool) -> CGFloat {
        if !hasTimetable { return 230 }
        return baseBodyHeight + (showSunrise ? 24 : 0)
    }
    static func expandedHeight(clearance: CGFloat, showSunrise: Bool, hasTimetable: Bool) -> CGFloat {
        contentClearanceBounded(clearance) + expandedBodyHeight(showSunrise: showSunrise, hasTimetable: hasTimetable)
    }
    private static func contentClearanceBounded(_ value: CGFloat) -> CGFloat { max(0, value) }
    static func compactTopOffset(clearance: CGFloat) -> CGFloat { clearance > 0 ? 0 : 8 }
    static func compactWidth(clearance: CGFloat, preferred: CGFloat) -> CGFloat {
        clearance > 0 ? expandedWidth : preferred
    }
    static func hasCameraSafeEars(_ clearance: CGFloat) -> Bool { clearance > 0 }
    static var reservedCameraGap: CGFloat { expandedWidth - 2 * notchEarWidth - 10 }
}
