import UIKit

final class PagesViewController: UIViewController, UIScrollViewDelegate, RideEngineDelegate {
    private let engine = RideEngine()

    private let strip = UIView()
    private let clockLabel = UILabel()
    private let stateLabel = UILabel()
    private let gpsLabel = UILabel()

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

    private let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var appliedDark = Settings.dark
    private var savedBrightness: CGFloat?
    private var inactiveSince: Date?
    private var warned20 = false
    private var warned10 = false

    override var prefersStatusBarHidden: Bool { return true }

    override func viewDidLoad() {
        super.viewDidLoad()
        UIDevice.current.isBatteryMonitoringEnabled = true
        buildStrip()
        buildFooter()
        buildScroll()

        mainPage.onStartPause = { [weak self] in self?.engine.startPause() }
        mainPage.onLap = { [weak self] in self?.engine.lap() }
        mainPage.onStop = { [weak self] in self?.engine.finish() }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(settingsDidChange), name: .settingsChanged, object: nil)
        nc.addObserver(self, selector: #selector(batteryChanged),
                       name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(restoreBrightness),
                       name: UIApplication.willResignActiveNotification, object: nil)
        let tap = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        applyTheme()
        engine.delegate = self
        engine.begin()
        engineDidUpdate(engine)
    }

    // MARK: - Susunan

    private func buildStrip() {
        strip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(strip)
        clockLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        stateLabel.font = .systemFont(ofSize: 11, weight: .medium)
        gpsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        stateLabel.textAlignment = .center
        gpsLabel.textAlignment = .right
        let s = UIStackView(arrangedSubviews: [clockLabel, stateLabel, gpsLabel])
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
        // Ketuk bar atas = buka Pengaturan
        strip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(openSettings)))
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

    @objc private func openSettings() {
        restoreBrightness()
        let vc = SettingsViewController(engine: engine)
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true, completion: nil)
    }

    @objc private func settingsDidChange() {
        appliedDark = Settings.dark
        applyTheme()
        engineDidUpdate(engine)
    }

    private func applyTheme() {
        view.backgroundColor = Theme.bg
        clockLabel.textColor = Theme.fg
        gpsLabel.textColor = Theme.muted
        nameLabel.textColor = Theme.muted
        dots.pageIndicatorTintColor = Theme.line
        dots.currentPageIndicatorTintColor = Theme.fg
        pages.forEach { $0.applyTheme() }
    }

    // MARK: - Redup layar dan baterai

    private func updateDim(_ e: RideEngine) {
        let paused = (e.state == .paused || e.state == .autoPaused)
        if Settings.autoDim && paused {
            if inactiveSince == nil { inactiveSince = Date() }
            if savedBrightness == nil, let t = inactiveSince, Date().timeIntervalSince(t) > 10 {
                savedBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 0.15
            }
        } else {
            inactiveSince = nil
            restoreBrightness()
        }
    }

    @objc private func restoreBrightness() {
        if let b = savedBrightness {
            UIScreen.main.brightness = b
            savedBrightness = nil
        }
    }

    /// Ketuk layar saat redup: terang lagi, redup ulang setelah 10 detik.
    @objc private func screenTapped() {
        if savedBrightness != nil {
            restoreBrightness()
            inactiveSince = Date()
        }
    }

    @objc private func batteryChanged() {
        guard Settings.batteryWarn else { return }
        let lvl = UIDevice.current.batteryLevel
        guard lvl >= 0, UIDevice.current.batteryState != .charging else { return }
        if lvl > 0.25 {
            warned20 = false
            warned10 = false
        }
        if lvl <= 0.10 && !warned10 {
            warned10 = true
            warned20 = true
            engine.notice("Baterai 10%")
        } else if lvl <= 0.20 && !warned20 {
            warned20 = true
            engine.notice("Baterai 20%")
        }
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
        if Settings.dark != appliedDark {
            appliedDark = Settings.dark
            applyTheme()
        }
        clockLabel.text = clockFormatter.string(from: Date())
        if let a = e.gpsAccuracy {
            gpsLabel.text = "GPS ±\(Int(a)) m"
        } else {
            gpsLabel.text = "GPS: mencari..."
        }

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
        updateDim(e)
    }
}
