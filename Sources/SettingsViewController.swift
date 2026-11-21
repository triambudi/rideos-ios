import UIKit

final class ActionSwitch: UISwitch {
    var onChange: ((Bool) -> Void)?
    func attach() { addTarget(self, action: #selector(changed), for: .valueChanged) }
    @objc private func changed() { onChange?(isOn) }
}

final class ActionStepper: UIStepper {
    var onChange: ((Double) -> Void)?
    func attach() { addTarget(self, action: #selector(changed), for: .valueChanged) }
    @objc private func changed() { onChange?(value) }
}

/// Layar Pengaturan: paket peta, rekaman, zona HR, layar dan baterai, tema, riwayat.
final class SettingsViewController: UITableViewController {
    private enum Kind {
        case info(String)
        case toggle(() -> Bool, (Bool) -> Void)
        case stepper(Double, Double, Double, () -> Double, (Double) -> Void, (Double) -> String)
        case action(String?, () -> Void)
        case pack(MapPack)
        case file(URL, Int64)
    }

    private struct Row {
        let title: String
        let kind: Kind
    }

    private struct Section {
        let title: String
        let footer: String?
        var rows: [Row]
    }

    private let engine: RideEngine
    private var sections: [Section] = []
    private let draftName = "gowes-draft.gpx"

    init(engine: RideEngine) {
        self.engine = engine
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pengaturan"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                                            action: #selector(donePressed))
        rebuild()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    private func applyTheme() {
        tableView.backgroundColor = Theme.bg
        tableView.separatorColor = Theme.line
        if let bar = navigationController?.navigationBar {
            bar.isTranslucent = false
            bar.barTintColor = Theme.bg
            bar.tintColor = Theme.blue
            bar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: Theme.fg]
        }
        tableView.reloadData()
    }

    @objc private func donePressed() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        dismiss(animated: true, completion: nil)
    }

    private func changed() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    // MARK: - Susunan baris

    private func rebuild() {
        var s: [Section] = []

        let lvl = UIDevice.current.batteryLevel
        let gps = engine.gpsAccuracy.map { "±\(Int($0)) m" } ?? "mencari..."
        s.append(Section(title: "Status", footer: nil, rows: [
            Row(title: "GPS", kind: .info(gps)),
            Row(title: "Sensor HR", kind: .info(engine.hrStatus.replacingOccurrences(of: "HR: ", with: ""))),
            Row(title: "Baterai", kind: .info(lvl >= 0 ? "\(Int(lvl * 100))%" : "--"))
        ]))

        // Peta offline
        var mapRows: [Row] = []
        let packs = MapPacks.scan()
        if packs.isEmpty { mapRows.append(Row(title: "Belum ada paket peta", kind: .info("kosong"))) }
        for p in packs { mapRows.append(Row(title: p.title, kind: .pack(p))) }
        mapRows.append(Row(title: "Muat ulang daftar paket", kind: .action(nil, { [weak self] in self?.reloadPacks() })))
        mapRows.append(Row(title: "Diagnosa peta", kind: .action(nil, { [weak self] in self?.showDiagnostics() })))
        s.append(Section(
            title: "Peta offline",
            footer: "Salin file .mbtiles ke folder Documents/maps lewat kabel atau SSH, lalu muat ulang. Saklar mengaktifkan paket, geser ke kiri untuk menghapus.",
            rows: mapRows))

        // Rekaman
        s.append(Section(title: "Rekaman", footer: nil, rows: [
            Row(title: "Jeda otomatis", kind: .toggle({ Settings.autoPause }, { Settings.autoPause = $0 })),
            Row(title: "Jeda jika di bawah", kind: .stepper(1, 5, 0.5, { Settings.pauseBelowKmh },
                { Settings.pauseBelowKmh = $0 }, { String(format: "%.1f km/j", $0) })),
            Row(title: "Lanjut jika di atas", kind: .stepper(1.5, 8, 0.5, { Settings.resumeAboveKmh },
                { Settings.resumeAboveKmh = $0 }, { String(format: "%.1f km/j", $0) })),
            Row(title: "Jeda setelah", kind: .stepper(2, 10, 1, { Double(Settings.pauseAfterSeconds) },
                { Settings.pauseAfterSeconds = Int($0) }, { "\(Int($0)) dtk" })),
            Row(title: "Jarak antar titik", kind: .stepper(3, 20, 1, { Settings.minPointM },
                { Settings.minPointM = $0 }, { "\(Int($0)) m" })),
            Row(title: "Lap otomatis", kind: .stepper(0, 20, 1, { Double(Settings.autoLapKm) },
                { Settings.autoLapKm = Int($0) }, { $0 == 0 ? "mati" : "\(Int($0)) km" }))
        ]))

        // Zona HR
        var zoneRows: [Row] = [
            Row(title: "HR maks", kind: .stepper(140, 220, 1, { Double(Settings.hrMax) },
                { Settings.hrMax = Int($0) }, { "\(Int($0)) bpm" }))
        ]
        for i in 0..<4 {
            zoneRows.append(Row(title: "Zona \(i + 2) mulai", kind: .stepper(40, 99, 1,
                { Settings.zoneBounds[i] * 100 },
                { [weak self] v in
                    let before = Settings.zoneBounds
                    Settings.setZoneBound(i, v / 100)
                    let after = Settings.zoneBounds
                    for j in 0..<4 where j != i && abs(after[j] - before[j]) > 0.0001 {
                        self?.reloadSoon()
                        break
                    }
                },
                { String(format: "%.0f%% HR maks", $0) })))
        }
        zoneRows.append(Row(title: "Kembalikan zona bawaan", kind: .action(nil, { [weak self] in
            Settings.resetZones()
            self?.rebuild()
            self?.tableView.reloadData()
        })))
        s.append(Section(title: "Zona HR", footer: "Batas zona dipakai di grafik, warna HR, dan ringkasan.", rows: zoneRows))

        // Layar dan baterai
        s.append(Section(title: "Layar dan baterai",
                         footer: "Hemat baterai memakai GPS standar dan memperbarui layar lebih jarang. Redup bekerja saat dijeda.",
                         rows: [
            Row(title: "Hemat baterai", kind: .toggle({ Settings.batterySaver }, { [weak self] in
                Settings.batterySaver = $0
                self?.changed()
            })),
            Row(title: "Redup saat berhenti", kind: .toggle({ Settings.autoDim }, { Settings.autoDim = $0 })),
            Row(title: "Peringatan baterai", kind: .toggle({ Settings.batteryWarn }, { Settings.batteryWarn = $0 }))
        ]))

        // Tampilan
        let modes = ["Terang", "Gelap", "Otomatis"]
        s.append(Section(title: "Tampilan", footer: "Otomatis: gelap pukul 18.00 sampai 06.00.", rows: [
            Row(title: "Tema", kind: .action(modes[Settings.themeMode % 3], { [weak self] in
                Settings.themeMode = (Settings.themeMode + 1) % 3
                self?.changed()
                self?.rebuild()
                self?.applyTheme()
            }))
        ]))

        // Riwayat
        var hist: [Row] = []
        for f in historyFiles() { hist.append(Row(title: f.0.lastPathComponent, kind: .file(f.0, f.1))) }
        if hist.isEmpty { hist.append(Row(title: "Belum ada rekaman", kind: .info("kosong"))) }
        s.append(Section(
            title: "Riwayat",
            footer: "Ketuk untuk membagikan, geser ke kiri untuk menghapus. gowes-draft.gpx adalah rekaman yang belum disimpan.",
            rows: hist))

        sections = s
    }

    private func historyFiles() -> [(URL, Int64)] {
        let fm = FileManager.default
        let dir = RideEngine.documentsURL
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        var items: [(URL, Int64, Date)] = []
        for n in names where n.hasPrefix("gowes-") && n.hasSuffix(".gpx") {
            let u = dir.appendingPathComponent(n)
            let attrs = try? fm.attributesOfItem(atPath: u.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let date = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
            items.append((u, size, date))
        }
        items.sort { $0.2 > $1.2 }
        return items.map { ($0.0, $0.1) }
    }

    private func reloadPacks() {
        NotificationCenter.default.post(name: .packsChanged, object: nil)
        rebuild()
        tableView.reloadData()
    }

    private func showDiagnostics() {
        let a = UIAlertController(title: "Diagnosa peta", message: MapPacks.diagnosticText(), preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Tutup", style: .cancel, handler: nil))
        present(a, animated: true, completion: nil)
    }

    private func reloadSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.rebuild()
            self?.tableView.reloadData()
        }
    }

    // MARK: - Tabel

    override func numberOfSections(in tableView: UITableView) -> Int { return sections.count }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    override func tableView(_ tv: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footer
    }

    override func tableView(_ tv: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Theme.muted
    }

    override func tableView(_ tv: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Theme.muted
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = Theme.cell
        cell.textLabel?.text = row.title
        cell.textLabel?.textColor = Theme.fg
        cell.detailTextLabel?.textColor = Theme.muted
        cell.selectionStyle = .none

        switch row.kind {
        case .info(let v):
            cell.detailTextLabel?.text = v
        case .toggle(let get, let set):
            let sw = ActionSwitch()
            sw.isOn = get()
            sw.onChange = set
            sw.attach()
            cell.accessoryView = sw
        case .stepper(let mn, let mx, let st, let get, let set, let fmt):
            let stp = ActionStepper()
            stp.minimumValue = mn
            stp.maximumValue = mx
            stp.stepValue = st
            stp.value = get()
            cell.detailTextLabel?.text = fmt(get())
            stp.onChange = { [weak cell] v in
                set(v)
                cell?.detailTextLabel?.text = fmt(get())
            }
            stp.attach()
            cell.accessoryView = stp
        case .action(let detail, _):
            cell.textLabel?.textColor = Theme.blue
            cell.detailTextLabel?.text = detail
            cell.selectionStyle = .default
        case .pack(let p):
            if let st = p.status {
                cell.detailTextLabel?.text = st
            } else {
                cell.detailTextLabel?.text = "\(MapPacks.sizeText(p.size)), z\(p.minZoom)-\(p.maxZoom)"
            }
            let sw = ActionSwitch()
            sw.isOn = MapPacks.isActive(p)
            sw.onChange = { on in MapPacks.setActive(p, on) }
            sw.attach()
            cell.accessoryView = sw
        case .file(_, let size):
            cell.detailTextLabel?.text = MapPacks.sizeText(size)
            cell.selectionStyle = .default
        }
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row.kind {
        case .action(_, let handler):
            handler()
        case .file(let url, _):
            handleFile(url)
        default:
            break
        }
    }

    override func tableView(_ tv: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section].rows[indexPath.row].kind {
        case .pack, .file: return true
        default: return false
        }
    }

    override func tableView(_ tv: UITableView, commit style: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard style == .delete else { return }
        switch sections[indexPath.section].rows[indexPath.row].kind {
        case .pack(let p):
            try? FileManager.default.removeItem(at: p.url)
            NotificationCenter.default.post(name: .packsChanged, object: nil)
        case .file(let url, _):
            try? FileManager.default.removeItem(at: url)
        default:
            return
        }
        rebuild()
        tableView.reloadData()
    }

    // MARK: - Riwayat

    private func handleFile(_ url: URL) {
        if url.lastPathComponent == draftName {
            let a = UIAlertController(title: "Draft rekaman",
                                      message: "Rekaman yang belum disimpan (misalnya baterai habis).",
                                      preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Pulihkan sebagai rekaman", style: .default) { [weak self] _ in
                let df = DateFormatter()
                df.dateFormat = "yyyyMMdd-HHmmss"
                let target = url.deletingLastPathComponent().appendingPathComponent("gowes-pulih-\(df.string(from: Date())).gpx")
                try? FileManager.default.moveItem(at: url, to: target)
                self?.rebuild()
                self?.tableView.reloadData()
            })
            a.addAction(UIAlertAction(title: "Bagikan", style: .default) { [weak self] _ in self?.share(url) })
            a.addAction(UIAlertAction(title: "Batal", style: .cancel, handler: nil))
            present(a, animated: true, completion: nil)
        } else {
            share(url)
        }
    }

    private func share(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(vc, animated: true, completion: nil)
    }
}
