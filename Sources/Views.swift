import UIKit

/// Dasar semua halaman.
class PageView: UIView {
    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(_ e: RideEngine) {}
    func applyTheme() {}
}

func makeLabel(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UILabel {
    let l = UILabel()
    l.font = .systemFont(ofSize: size, weight: weight)
    l.textColor = Theme.fg
    return l
}

/// Kotak data: judul kecil + angka besar.
final class CellView: UIView {
    let titleLabel = UILabel()
    let valueLabel = UILabel()

    init(title: String, valueSize: CGFloat = 26) {
        super.init(frame: .zero)
        layer.cornerRadius = 10
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: valueSize, weight: .medium)
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        valueLabel.text = "0"
        let s = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        s.axis = .vertical
        s.spacing = 2
        s.translatesAutoresizingMaskIntoConstraints = false
        addSubview(s)
        NSLayoutConstraint.activate([
            s.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            s.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            s.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyTheme() {
        backgroundColor = Theme.cell
        titleLabel.textColor = Theme.muted
        valueLabel.textColor = Theme.fg
    }
}

/// Grafik HR: batang penuh dari dasar, warna menurut zona, tiap batang = rata-rata 5 detik.
final class BarGraphView: UIView {
    var values: [Double] = [] { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let hrMax = Double(Settings.hrMax)
        let lo = 80.0
        let h = bounds.height
        let w = bounds.width
        ctx.setLineWidth(0.5)
        ctx.setStrokeColor(Theme.line.cgColor)
        ctx.setLineDash(phase: 0, lengths: [2, 3])
        for b in Settings.zoneBounds {
            let y = h - CGFloat((hrMax * b - lo) / (hrMax - lo)) * h
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: w, y: y))
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])
        let slot = w / 18
        for (i, v) in values.enumerated() {
            let bh = max(2, CGFloat((v - lo) / (hrMax - lo)) * h)
            let r = CGRect(x: CGFloat(i) * slot + 1, y: h - bh, width: slot - 2, height: bh)
            Theme.zones[zoneIndex(v) - 1].setFill()
            UIBezierPath(roundedRect: r, cornerRadius: 2).fill()
        }
    }
}

/// Bar tumpuk waktu di tiap zona HR.
final class ZoneBarView: UIView {
    var seconds = [Double](repeating: 0, count: 5) { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        let total = seconds.reduce(0, +)
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 4)
        Theme.line.setFill()
        path.fill()
        guard total > 0, let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        path.addClip()
        var x: CGFloat = 0
        for (i, s) in seconds.enumerated() {
            let w = bounds.width * CGFloat(s / total)
            Theme.zones[i].setFill()
            UIRectFill(CGRect(x: x, y: 0, width: w, height: bounds.height))
            x += w
        }
        ctx.restoreGState()
    }
}

/// Profil ketinggian jalur terakhir, batang diwarnai menurut kemiringan.
final class ProfileView: UIView {
    var samples: [(ele: Double, grade: Double)] = [] { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard samples.count >= 2 else { return }
        let eles = samples.map { $0.ele }
        var lo = (eles.min() ?? 0) - 2
        var hi = (eles.max() ?? 0) + 2
        if hi - lo < 12 {
            let mid = (hi + lo) / 2
            lo = mid - 6
            hi = mid + 6
        }
        let slot = bounds.width / 100
        let n = samples.count
        for (i, s) in samples.enumerated() {
            let h = CGFloat((s.ele - lo) / (hi - lo)) * (bounds.height - 6) + 6
            let x = bounds.width - slot * CGFloat(n - i)
            gradeColor(s.grade).setFill()
            UIRectFill(CGRect(x: x, y: bounds.height - h, width: slot + 0.5, height: h))
        }
    }
}
