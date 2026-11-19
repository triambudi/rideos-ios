import UIKit

final class MainPageView: PageView {
    var onStartPause: (() -> Void)?
    var onLap: (() -> Void)?
    var onStop: (() -> Void)?

    private let speed = CellView(title: "Kecepatan km/jam", valueSize: 64)
    private let maxLabel = UILabel()
    private let hrCell = UIView()
    private let hrTitle = UILabel()
    private let hrZone = UILabel()
    private let hrValue = UILabel()
    private let graph = BarGraphView()
    private let dist = CellView(title: "Jarak km", valueSize: 30)
    private let time = CellView(title: "Waktu gowes", valueSize: 30)
    private let gain = CellView(title: "Tanjakan m", valueSize: 30)
    private let avg = CellView(title: "Rata-rata km/jam", valueSize: 30)
    private let startBtn = UIButton(type: .custom)
    private let lapBtn = UIButton(type: .custom)
    private let stopBtn = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        // Kotak kecepatan + label maks
        speed.valueLabel.font = .monospacedDigitSystemFont(ofSize: 64, weight: .bold)
        speed.valueLabel.text = "0.0"
        maxLabel.font = .systemFont(ofSize: 11, weight: .medium)
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        speed.addSubview(maxLabel)
        NSLayoutConstraint.activate([
            maxLabel.topAnchor.constraint(equalTo: speed.topAnchor, constant: 6),
            maxLabel.trailingAnchor.constraint(equalTo: speed.trailingAnchor, constant: -8)
        ])

        // Kotak HR + grafik
        hrCell.layer.cornerRadius = 10
        hrTitle.text = "Detak jantung bpm"
        hrTitle.font = .systemFont(ofSize: 11, weight: .medium)
        hrZone.font = .systemFont(ofSize: 11, weight: .bold)
        hrValue.font = .monospacedDigitSystemFont(ofSize: 36, weight: .medium)
        hrValue.text = "--"
        let subs: [UIView] = [hrTitle, hrZone, hrValue, graph]
        for v in subs {
            v.translatesAutoresizingMaskIntoConstraints = false
            hrCell.addSubview(v)
        }
        NSLayoutConstraint.activate([
            hrTitle.topAnchor.constraint(equalTo: hrCell.topAnchor, constant: 8),
            hrTitle.leadingAnchor.constraint(equalTo: hrCell.leadingAnchor, constant: 8),
            hrZone.topAnchor.constraint(equalTo: hrCell.topAnchor, constant: 8),
            hrZone.trailingAnchor.constraint(equalTo: hrCell.trailingAnchor, constant: -8),
            hrValue.topAnchor.constraint(equalTo: hrTitle.bottomAnchor, constant: 0),
            hrValue.leadingAnchor.constraint(equalTo: hrCell.leadingAnchor, constant: 8),
            graph.leadingAnchor.constraint(equalTo: hrCell.leadingAnchor, constant: 8),
            graph.trailingAnchor.constraint(equalTo: hrCell.trailingAnchor, constant: -8),
            graph.bottomAnchor.constraint(equalTo: hrCell.bottomAnchor, constant: -6),
            graph.heightAnchor.constraint(equalToConstant: 64)
        ])

        // Grid 2x2
        let row1 = UIStackView(arrangedSubviews: [dist, time])
        let row2 = UIStackView(arrangedSubviews: [gain, avg])
        for r in [row1, row2] {
            r.axis = .horizontal
            r.spacing = 6
            r.distribution = .fillEqually
        }
        let grid = UIStackView(arrangedSubviews: [row1, row2])
        grid.axis = .vertical
        grid.spacing = 6
        grid.distribution = .fillEqually
        grid.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)

        // Tombol
        style(startBtn, "Mulai", Theme.green, #selector(startTapped))
        style(lapBtn, "Lap", Theme.cell, #selector(lapTapped))
        style(stopBtn, "Simpan", Theme.red, #selector(stopTapped))
        lapBtn.isHidden = true
        stopBtn.isHidden = true
        let btns = UIStackView(arrangedSubviews: [startBtn, lapBtn, stopBtn])
        btns.axis = .horizontal
        btns.spacing = 6
        btns.distribution = .fillEqually

        let main = UIStackView(arrangedSubviews: [speed, hrCell, grid, btns])
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
            speed.heightAnchor.constraint(equalToConstant: 100),
            hrCell.heightAnchor.constraint(equalToConstant: 140),
            btns.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func style(_ b: UIButton, _ title: String, _ color: UIColor, _ action: Selector) {
        b.setTitle(title, for: .normal)
        b.setTitleColor(UIColor.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        b.backgroundColor = color
        b.layer.cornerRadius = 10
        b.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func startTapped() { onStartPause?() }
    @objc private func lapTapped() { onLap?() }
    @objc private func stopTapped() { onStop?() }

    override func applyTheme() {
        [speed, dist, time, gain, avg].forEach { $0.applyTheme() }
        hrCell.backgroundColor = Theme.cell
        hrTitle.textColor = Theme.muted
        maxLabel.textColor = Theme.muted
        lapBtn.backgroundColor = Theme.cell
        lapBtn.setTitleColor(Theme.fg, for: .normal)
        graph.setNeedsDisplay()
    }

    override func update(_ e: RideEngine) {
        speed.valueLabel.text = String(format: "%.1f", e.speedKmh)
        maxLabel.text = String(format: "Maks %.1f", e.maxSpeedKmh)

        let hr = e.heartRate
        hrValue.text = hr > 0 ? "\(hr)" : "--"
        let z = hr > 0 ? zoneIndex(Double(hr)) : 0
        hrZone.text = z > 0 ? "Z\(z)" : ""
        let col = z > 0 ? Theme.zones[z - 1] : Theme.fg
        hrValue.textColor = col
        hrZone.textColor = col
        var vals = e.hrBars
        if let c = e.currentBar { vals.append(c) }
        graph.values = vals

        dist.valueLabel.text = String(format: "%.2f", e.distanceM / 1000)
        time.valueLabel.text = formatDuration(e.elapsed)
        gain.valueLabel.text = "\(Int(e.gainM.rounded()))"
        avg.valueLabel.text = String(format: "%.1f", e.avgKmh)

        switch e.state {
        case .idle:
            startBtn.setTitle("Mulai", for: .normal)
            startBtn.backgroundColor = Theme.green
            lapBtn.isHidden = true
            stopBtn.isHidden = true
        case .running:
            startBtn.setTitle("Jeda", for: .normal)
            startBtn.backgroundColor = Theme.amber
            lapBtn.isHidden = false
            stopBtn.isHidden = true
        case .paused, .autoPaused:
            startBtn.setTitle("Lanjut", for: .normal)
            startBtn.backgroundColor = Theme.green
            lapBtn.isHidden = true
            stopBtn.isHidden = false
        }
    }
}
