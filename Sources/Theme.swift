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

/// Pengaturan sederhana (disimpan di UserDefaults). Diubah lewat panel Quick Status (ketuk bar atas).
enum Settings {
    static var hrMax: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: "hrMax")
            return v > 0 ? v : 190
        }
        set { UserDefaults.standard.set(newValue, forKey: "hrMax") }
    }
    static var autoPause: Bool {
        get { return (UserDefaults.standard.object(forKey: "autoPause") as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoPause") }
    }
    static var dark: Bool {
        get { return UserDefaults.standard.bool(forKey: "dark") }
        set { UserDefaults.standard.set(newValue, forKey: "dark") }
    }
    static let pauseBelowKmh = 2.0
    static let resumeAboveKmh = 3.0
    static let pauseAfterSeconds = 3
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
    if r < 0.6 { return 1 }
    if r < 0.7 { return 2 }
    if r < 0.8 { return 3 }
    if r < 0.9 { return 4 }
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
