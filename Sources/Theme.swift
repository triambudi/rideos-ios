import UIKit
import CoreLocation

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                  green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(hex & 0xFF) / 255.0,
                  alpha: 1)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("gowes.settingsChanged")
    static let packsChanged = Notification.Name("gowes.packsChanged")
}

/// Pengaturan (disimpan di UserDefaults). Diubah lewat layar Pengaturan (ketuk bar atas).
enum Settings {
    private static let d = UserDefaults.standard

    static var hrMax: Int {
        get {
            let v = d.integer(forKey: "hrMax")
            return v > 0 ? v : 190
        }
        set { d.set(newValue, forKey: "hrMax") }
    }
    static var autoPause: Bool {
        get { return (d.object(forKey: "autoPause") as? Bool) ?? true }
        set { d.set(newValue, forKey: "autoPause") }
    }
    static var pauseBelowKmh: Double {
        get { return (d.object(forKey: "pauseBelow") as? Double) ?? 2.0 }
        set { d.set(newValue, forKey: "pauseBelow") }
    }
    static var resumeAboveKmh: Double {
        get { return max((d.object(forKey: "resumeAbove") as? Double) ?? 3.0, pauseBelowKmh + 0.5) }
        set { d.set(newValue, forKey: "resumeAbove") }
    }
    static var pauseAfterSeconds: Int {
        get { return (d.object(forKey: "pauseAfter") as? Int) ?? 3 }
        set { d.set(newValue, forKey: "pauseAfter") }
    }
    static var minPointM: Double {
        get { return (d.object(forKey: "minPointM") as? Double) ?? 5.0 }
        set { d.set(newValue, forKey: "minPointM") }
    }
    /// 0 = mati
    static var autoLapKm: Int {
        get { return (d.object(forKey: "autoLapKm") as? Int) ?? 0 }
        set { d.set(newValue, forKey: "autoLapKm") }
    }
    /// Batas awal zona 2, 3, 4, 5 sebagai pecahan HR maks.
    static var zoneBounds: [Double] {
        get {
            if let a = d.array(forKey: "zoneBounds") as? [Double], a.count == 4 { return a }
            return [0.6, 0.7, 0.8, 0.9]
        }
        set { d.set(newValue, forKey: "zoneBounds") }
    }
    static func setZoneBound(_ i: Int, _ v: Double) {
        var b = zoneBounds
        b[i] = v
        if i < 3 { for j in (i + 1)..<4 { b[j] = max(b[j], b[j - 1] + 0.01) } }
        if i > 0 { for j in stride(from: i - 1, through: 0, by: -1) { b[j] = min(b[j], b[j + 1] - 0.01) } }
        zoneBounds = b
    }
    static func resetZones() { d.removeObject(forKey: "zoneBounds") }

    static var batterySaver: Bool {
        get { return d.bool(forKey: "batterySaver") }
        set { d.set(newValue, forKey: "batterySaver") }
    }
    static var autoDim: Bool {
        get { return d.bool(forKey: "autoDim") }
        set { d.set(newValue, forKey: "autoDim") }
    }
    static var batteryWarn: Bool {
        get { return (d.object(forKey: "batteryWarn") as? Bool) ?? true }
        set { d.set(newValue, forKey: "batteryWarn") }
    }
    /// 0 = terang, 1 = gelap, 2 = otomatis (gelap jam 18.00-06.00)
    static var themeMode: Int {
        get { return d.integer(forKey: "themeMode") }
        set { d.set(newValue, forKey: "themeMode") }
    }
    static var dark: Bool {
        switch themeMode {
        case 1: return true
        case 2:
            let h = Calendar.current.component(.hour, from: Date())
            return h < 6 || h >= 18
        default: return false
        }
    }
}

enum Theme {
    static var bg: UIColor { return Settings.dark ? UIColor(white: 0.06, alpha: 1) : UIColor.white }
    static var fg: UIColor { return Settings.dark ? UIColor(white: 0.96, alpha: 1) : UIColor(white: 0.07, alpha: 1) }
    static var muted: UIColor { return Settings.dark ? UIColor(white: 0.66, alpha: 1) : UIColor(white: 0.42, alpha: 1) }
    static var cell: UIColor { return Settings.dark ? UIColor(white: 0.115, alpha: 1) : UIColor(hex: 0xF1EFE8) }
    static var line: UIColor { return Settings.dark ? UIColor(white: 0.23, alpha: 1) : UIColor(hex: 0xD3D1C7) }

    static let zones: [UIColor] = [
        UIColor(hex: 0x888780), UIColor(hex: 0x378ADD), UIColor(hex: 0x639922),
        UIColor(hex: 0xEF9F27), UIColor(hex: 0xE24B4A)
    ]
    static let green = UIColor(hex: 0x3B6D11)
    static let amber = UIColor(hex: 0x854F0B)
    static let red = UIColor(hex: 0xA32D2D)
    static let blue = UIColor(hex: 0x378ADD)
}

/// Zona HR 1...5 berdasarkan persen dari HR maks.
func zoneIndex(_ hr: Double) -> Int {
    let r = hr / Double(Settings.hrMax)
    let b = Settings.zoneBounds
    if r < b[0] { return 1 }
    if r < b[1] { return 2 }
    if r < b[2] { return 3 }
    if r < b[3] { return 4 }
    return 5
}

func gradeColor(_ g: Double) -> UIColor {
    if g < 0 { return UIColor(hex: 0x888780) }
    if g < 3 { return UIColor(hex: 0x639922) }
    if g < 6 { return UIColor(hex: 0xEF9F27) }
    if g < 9 { return UIColor(hex: 0xD85A30) }
    return UIColor(hex: 0xE24B4A)
}

func formatDuration(_ s: TimeInterval) -> String {
    let n = Int(s)
    return String(format: "%d:%02d:%02d", n / 3600, (n % 3600) / 60, n % 60)
}

func formatShort(_ s: TimeInterval) -> String {
    let n = Int(s)
    return String(format: "%d:%02d", n / 60, n % 60)
}

func formatDistance(_ m: Double) -> String {
    if m < 1000 { return "\(Int((m / 10).rounded()) * 10) m" }
    return String(format: "%.1f km", m / 1000)
}

func padL(_ s: String, _ n: Int) -> String {
    return String(repeating: " ", count: max(0, n - s.count)) + s
}

/// Arah (radian, searah jarum jam dari utara) dari titik a ke titik b.
func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
    let lat1 = a.latitude * Double.pi / 180
    let lat2 = b.latitude * Double.pi / 180
    let dLon = (b.longitude - a.longitude) * Double.pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    return atan2(y, x)
}
