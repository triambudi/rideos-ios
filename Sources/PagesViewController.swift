import UIKit

final class PagesViewController: UIViewController, UIScrollViewDelegate, RideEngineDelegate {
    private let engine = RideEngine()

    private let strip = UIView()
    private let gpsLabel = UILabel()
    private let stateLabel = UILabel()
    private let hrLabel = UILabel()

    private let scroll = UIScrollView()
    private let mainPage = MainPageView()
    private let mapPage = MapPageView()
    private let climbPage = ClimbPageView()
    private let summaryPage = SummaryPageView()
    private var pages: [PageView] { return [mainPage, mapPage, climbPage, summaryPage] }

    private let footer = UIView()
    private let dots = UIPageControl()
    private let nameLabel = UILabel()
    private let names = ["Utama", "Peta jejak", "Tanjakan", "Ringkasan"]

    // Panel Quick Status (ketuk bar atas)
    private let panel = UIView()
    private var panelLabels: [UILabel] = []
    private let clockVal = UILabel()
    private let gpsVal = UILabel()
    private let hrVal = UILabel()
    private let batVal = UILabel()
    private let hrMaxVal = UILabel()
    private let autoSwitch = UISwitch()
    private let darkSwitch = UISwitch()
    private let hrStepper = UIStepper()

    override var prefersStatusBarHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()
        UIDevice.current.isBatteryMonitoringEnabled = true
        buildStrip()
        buildFooter()
        buildScroll()
        buildPanel()

        mainPage.onStartPause = { [weak self] in self?.engine.startPause() }
        mainPage.onLap = { [weak self] in self?.engine.lap() }
        mainPage.onStop = { [weak self] in self?.engine.finish() }

        applyTheme()
        engine.delegate = self
        engine.begin()
        engineDidUpdate(engine)
    }

    // MARK: - Susunan

    private func buildStrip() {
        strip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(strip)
        for l in [gpsLabel, stateLabel, hrLabel] { l.font = .systemFont(ofSize: 11, weight: .medium) }
        stateLabel.textAlignment = .center
        hrLabel.textAlignment = .right
        let s = UIStackView(arrangedSubviews: [gpsLabel, stateLabel, hrLabel])
        s.axis = .horizontal
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        strip.addSubview(s)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: g.topAnchor),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 28),
            s.leadingAnchor.constraint(equalTo: strip.leadingAnchor, constant: 12),
            s.trailingAnchor.constraint(equalTo: strip.trailingAnchor, constant: -12),
            s.centerYAnchor.constraint(equalTo: strip.centerYAnchor)
        ])
        strip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(togglePanel)))
    }

    private func buildFooter() {
        footer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footer)
        dots.numberOfPages = 4
        dots.isUserInteractionEnabled = false
        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.text = names[0]
        let s = UIStackView(arrangedSubviews: [dots, nameLabel])
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(s)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            footer.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.heightAnchor.constraint(equalToConstant: 24),
            s.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            s.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])
    }

    private func buildScroll() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.bounces = false
        scroll.delegate = self
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: strip.bottomAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        for p in pages { scroll.addSubview(p) }
    }

    private func row(_ title: String, _ trailing: UIView) -> UIView {
        let l = UILabel()
        l.text = title
        l.font = .systemFont(ofSize: 14)
        panelLabels.append(l)
        let s = UIStackView(arrangedSubviews: [l, trailing])
        s.axis = .horizontal
        s.distribution = .equalSpacing
        s.alignment = .center
        return s
    }

    private func buildPanel() {
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isHidden = true
        panel.layer.cornerRadius = 12
        panel.layer.borderWidth = 0.5

        for l in [clockVal, gpsVal, hrVal, batVal, hrMaxVal] {
            l.font = .systemFont(ofSize: 14)
            l.textAlignment = .right
            panelLabels.append(l)
        }
        hrStepper.minimumValue = 140
        hrStepper.maximumValue = 220
        hrStepper.stepValue = 1
        hrStepper.value = Double(Settings.hrMax)
        hrStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
        autoSwitch.isOn = Settings.autoPause
        autoSwitch.addTarget(self, action: #selector(autoChanged), for: .valueChanged)
        darkSwitch.isOn = Settings.dark
        darkSwitch.addTarget(self, action: #selector(darkChanged), for: .valueChanged)

        let hrBox = UIStackView(arrangedSubviews: [hrMaxVal, hrStepper])
        hrBox.axis = .horizontal
        hrBox.spacing = 8
        hrBox.alignment = .center

        let rows = UIStackView(arrangedSubviews: [
            row("Jam", clockVal),
            row("GPS", gpsVal),
            row("Sensor HR", hrVal),
            row("Baterai", batVal),
            row("HR maks", hrBox),
            row("Jeda otomatis", autoSwitch),
            row("Tema gelap", darkSwitch)
        ])
        rows.axis = .vertical
        rows.spacing = 10
        rows.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(rows)
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: strip.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            rows.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            rows.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
            rows.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            rows.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = scroll.bounds.width
        let h = scroll.bounds.height
        scroll.contentSize = CGSize(width: w * CGFloat(pages.count), height: h)
        for (i, p) in pages.enumerated() {
            p.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
        }
    }

    // MARK: - Aksi

    @objc private func togglePanel() {
        panel.isHidden = !panel.isHidden
        if !panel.isHidden { updatePanel(engine) }
    }

    @objc private func stepperChanged() {
        Settings.hrMax = Int(hrStepper.value)
        hrMaxVal.text = "\(Settings.hrMax)"
    }

    @objc private func autoChanged() { Settings.autoPause = autoSwitch.isOn }

    @objc private func darkChanged() {
        Settings.dark = darkSwitch.isOn
        applyTheme()
        engineDidUpdate(engine)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.bg
        for l in [gpsLabel, hrLabel, nameLabel] { l.textColor = Theme.muted }
        dots.pageIndicatorTintColor = Theme.line
        dots.currentPageIndicatorTintColor = Theme.fg
        panel.backgroundColor = Theme.bg
        panel.layer.borderColor = Theme.line.cgColor
        for l in panelLabels { l.textColor = Theme.fg }
        pages.forEach { $0.applyTheme() }
    }

    // MARK: - Scroll

    func scrollViewDidScroll(_ sv: UIScrollView) {
        let w = sv.bounds.width
        guard w > 0 else { return }
        let i = max(0, min(names.count - 1, Int((sv.contentOffset.x / w).rounded())))
        if dots.currentPage != i {
            dots.currentPage = i
            nameLabel.text = names[i]
        }
    }

    // MARK: - RideEngineDelegate

    func engineDidUpdate(_ e: RideEngine) {
        if let a = e.gpsAccuracy {
            gpsLabel.text = "GPS ±\(Int(a)) m"
        } else {
            gpsLabel.text = "GPS: mencari..."
        }
        hrLabel.text = e.hrStatus

        var txt = "Siap"
        var col = Theme.muted
        if !e.message.isEmpty {
            txt = e.message
            col = Theme.blue
        } else {
            switch e.state {
            case .idle: txt = "Siap"; col = Theme.muted
            case .running: txt = "Merekam"; col = Theme.zones[2]
            case .paused: txt = "Dijeda"; col = Theme.zones[3]
            case .autoPaused: txt = "Jeda otomatis"; col = Theme.zones[3]
            }
        }
        stateLabel.text = txt
        stateLabel.textColor = col

        pages.forEach { $0.update(e) }
        if !panel.isHidden { updatePanel(e) }
    }

    private func updatePanel(_ e: RideEngine) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        clockVal.text = df.string(from: Date())
        if let a = e.gpsAccuracy { gpsVal.text = "±\(Int(a)) m" } else { gpsVal.text = "mencari..." }
        hrVal.text = e.hrStatus.replacingOccurrences(of: "HR: ", with: "")
        let lvl = UIDevice.current.batteryLevel
        batVal.text = lvl >= 0 ? "\(Int(lvl * 100))%" : "--"
        hrMaxVal.text = "\(Settings.hrMax)"
    }
}
