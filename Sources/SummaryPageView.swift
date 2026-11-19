import UIKit

final class SummaryPageView: PageView {
    private let hrAvg = CellView(title: "HR rata-rata", valueSize: 26)
    private let hrMax = CellView(title: "HR maks", valueSize: 26)
    private let zoneCell = UIView()
    private let zoneTitle = UILabel()
    private let zoneBar = ZoneBarView()
    private let zoneInfo = UILabel()
    private let moveCell = UIView()
    private let moveTitle = UILabel()
    private let stopTitle = UILabel()
    private let moveVal = UILabel()
    private let stopVal = UILabel()
    private let lapCell = UIView()
    private let lapTitle = UILabel()
    private let lapText = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let top = UIStackView(arrangedSubviews: [hrAvg, hrMax])
        top.axis = .horizontal
        top.spacing = 6
        top.distribution = .fillEqually

        // Zona
        zoneCell.layer.cornerRadius = 10
        zoneTitle.text = "Waktu di zona HR"
        zoneTitle.font = .systemFont(ofSize: 11, weight: .medium)
        zoneInfo.font = .systemFont(ofSize: 12)
        zoneInfo.text = "-"
        let zsubs: [UIView] = [zoneTitle, zoneBar, zoneInfo]
        for v in zsubs {
            v.translatesAutoresizingMaskIntoConstraints = false
            zoneCell.addSubview(v)
        }
        NSLayoutConstraint.activate([
            zoneTitle.topAnchor.constraint(equalTo: zoneCell.topAnchor, constant: 8),
            zoneTitle.leadingAnchor.constraint(equalTo: zoneCell.leadingAnchor, constant: 8),
            zoneBar.topAnchor.constraint(equalTo: zoneTitle.bottomAnchor, constant: 8),
            zoneBar.leadingAnchor.constraint(equalTo: zoneCell.leadingAnchor, constant: 8),
            zoneBar.trailingAnchor.constraint(equalTo: zoneCell.trailingAnchor, constant: -8),
            zoneBar.heightAnchor.constraint(equalToConstant: 18),
            zoneInfo.topAnchor.constraint(equalTo: zoneBar.bottomAnchor, constant: 8),
            zoneInfo.leadingAnchor.constraint(equalTo: zoneCell.leadingAnchor, constant: 8)
        ])

        // Bergerak / diam
        moveCell.layer.cornerRadius = 10
        moveTitle.text = "Bergerak"
        stopTitle.text = "Diam"
        for l in [moveTitle, stopTitle] { l.font = .systemFont(ofSize: 11, weight: .medium) }
        for l in [moveVal, stopVal] {
            l.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
            l.text = "0:00:00"
        }
        stopTitle.textAlignment = .right
        stopVal.textAlignment = .right
        let m1 = UIStackView(arrangedSubviews: [moveTitle, moveVal])
        m1.axis = .vertical
        let m2 = UIStackView(arrangedSubviews: [stopTitle, stopVal])
        m2.axis = .vertical
        let mrow = UIStackView(arrangedSubviews: [m1, m2])
        mrow.axis = .horizontal
        mrow.distribution = .fillEqually
        mrow.translatesAutoresizingMaskIntoConstraints = false
        moveCell.addSubview(mrow)
        NSLayoutConstraint.activate([
            mrow.leadingAnchor.constraint(equalTo: moveCell.leadingAnchor, constant: 8),
            mrow.trailingAnchor.constraint(equalTo: moveCell.trailingAnchor, constant: -8),
            mrow.centerYAnchor.constraint(equalTo: moveCell.centerYAnchor)
        ])

        // Lap
        lapCell.layer.cornerRadius = 10
        lapTitle.text = "Lap"
        lapTitle.font = .systemFont(ofSize: 11, weight: .medium)
        lapText.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        lapText.numberOfLines = 0
        lapText.text = RideLapFormat.header
        let lsubs: [UIView] = [lapTitle, lapText]
        for v in lsubs {
            v.translatesAutoresizingMaskIntoConstraints = false
            lapCell.addSubview(v)
        }
        NSLayoutConstraint.activate([
            lapTitle.topAnchor.constraint(equalTo: lapCell.topAnchor, constant: 8),
            lapTitle.leadingAnchor.constraint(equalTo: lapCell.leadingAnchor, constant: 8),
            lapText.topAnchor.constraint(equalTo: lapTitle.bottomAnchor, constant: 6),
            lapText.leadingAnchor.constraint(equalTo: lapCell.leadingAnchor, constant: 8),
            lapText.trailingAnchor.constraint(equalTo: lapCell.trailingAnchor, constant: -8)
        ])

        let main = UIStackView(arrangedSubviews: [top, zoneCell, moveCell, lapCell])
        main.axis = .vertical
        main.spacing = 6
        main.alignment = .fill
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            main.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            main.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            top.heightAnchor.constraint(equalToConstant: 72),
            zoneCell.heightAnchor.constraint(equalToConstant: 100),
            moveCell.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    override func applyTheme() {
        hrAvg.applyTheme()
        hrMax.applyTheme()
        for v in [zoneCell, moveCell, lapCell] { v.backgroundColor = Theme.cell }
        for l in [zoneTitle, moveTitle, stopTitle, lapTitle] { l.textColor = Theme.muted }
        for l in [zoneInfo, moveVal, stopVal, lapText] { l.textColor = Theme.fg }
        zoneBar.setNeedsDisplay()
    }

    override func update(_ e: RideEngine) {
        hrAvg.valueLabel.text = e.hrCount > 0 ? "\(e.hrSum / e.hrCount)" : "--"
        hrMax.valueLabel.text = e.hrMaxSeen > 0 ? "\(e.hrMaxSeen)" : "--"
        zoneBar.seconds = e.zoneSeconds
        let total = e.zoneSeconds.reduce(0, +)
        if total > 0, let top = e.zoneSeconds.enumerated().max(by: { $0.element < $1.element }) {
            zoneInfo.text = "Z\(top.offset + 1) terlama (\(Int((top.element / total * 100).rounded()))%)"
        } else {
            zoneInfo.text = "-"
        }
        moveVal.text = formatDuration(e.elapsed)
        stopVal.text = formatDuration(e.stoppedTime)
        var lines = [RideLapFormat.header]
        for l in e.laps.prefix(12) { lines.append(RideLapFormat.row(l)) }
        lapText.text = lines.joined(separator: "\n")
    }
}

enum RideLapFormat {
    static var header: String {
        return padL("No", 2) + " " + padL("km", 6) + "  " + padL("Waktu", 7) + " " + padL("km/j", 5) + " " + padL("HR", 3)
    }

    static func row(_ l: LapRecord) -> String {
        let hr = l.avgHR > 0 ? "\(l.avgHR)" : "--"
        return padL("\(l.n)", 2) + " " + padL(String(format: "%.2f", l.km), 6) + "  "
            + padL(formatShort(l.seconds), 7) + " " + padL(String(format: "%.1f", l.avgKmh), 5) + " " + padL(hr, 3)
    }
}
