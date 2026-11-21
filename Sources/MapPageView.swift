import UIKit
import MapKit

final class MapPageView: PageView, MKMapViewDelegate {
    private let map = MKMapView()
    private let banner = UIView()
    private let arrow = UILabel()
    private let distLabel = UILabel()
    private let subLabel = UILabel()
    private let zoomIn = UIButton(type: .custom)
    private let zoomOut = UIButton(type: .custom)
    private let speedCell = CellView(title: "Kecepatan km/jam", valueSize: 38)
    private let hrCell = CellView(title: "Detak jantung bpm", valueSize: 38)
    private let hrZone = UILabel()
    private let info = UIView()
    private let jejak = UILabel()
    private let titik = UILabel()
    private let mode = UILabel()
    private var tileOverlay: MKTileOverlay?
    private var trailPoly: MKPolyline?
    private var startPin: MKPointAnnotation?
    private var lastTrailCount = -1
    private var lastTrailRefresh = Date.distantPast
    private var didSetCamera = false
    private var packBounds: [[Double]] = []
    private var packCount = 0
    private var centeredOnPack = false
    private var followStarted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        applyTheme()
        reloadTiles()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTiles),
                                               name: .packsChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        map.translatesAutoresizingMaskIntoConstraints = false
        map.layer.cornerRadius = 10
        map.clipsToBounds = true
        map.delegate = self
        map.showsUserLocation = true
        // Gerak peta dimatikan agar geser halaman tetap bisa; peta selalu mengikuti posisi.
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false

        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 10
        banner.layer.borderWidth = 0.5
        arrow.font = .systemFont(ofSize: 26)
        arrow.textAlignment = .center
        arrow.text = "📍"
        distLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        distLabel.text = "Siap merekam"
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.text = "Titik awal ditandai otomatis saat Mulai"
        subLabel.adjustsFontSizeToFitWidth = true
        subLabel.minimumScaleFactor = 0.7
        let texts = UIStackView(arrangedSubviews: [distLabel, subLabel])
        texts.axis = .vertical
        let h = UIStackView(arrangedSubviews: [arrow, texts])
        h.axis = .horizontal
        h.spacing = 10
        h.alignment = .center
        h.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(h)

        for (b, t, sel) in [(zoomIn, "+", #selector(zoomInTapped)), (zoomOut, "-", #selector(zoomOutTapped))] {
            b.setTitle(t, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 20)
            b.layer.cornerRadius = 8
            b.layer.borderWidth = 0.5
            b.translatesAutoresizingMaskIntoConstraints = false
            b.addTarget(self, action: sel, for: .touchUpInside)
        }

        // Strip data di bawah peta
        speedCell.valueLabel.text = "0.0"
        hrCell.valueLabel.text = "--"
        hrZone.font = .systemFont(ofSize: 11, weight: .bold)
        hrZone.translatesAutoresizingMaskIntoConstraints = false
        hrCell.addSubview(hrZone)
        NSLayoutConstraint.activate([
            hrZone.topAnchor.constraint(equalTo: hrCell.topAnchor, constant: 6),
            hrZone.trailingAnchor.constraint(equalTo: hrCell.trailingAnchor, constant: -8)
        ])
        let strip = UIStackView(arrangedSubviews: [speedCell, hrCell])
        strip.axis = .horizontal
        strip.spacing = 6
        strip.distribution = .fillEqually
        strip.translatesAutoresizingMaskIntoConstraints = false

        info.translatesAutoresizingMaskIntoConstraints = false
        info.layer.cornerRadius = 10
        for l in [jejak, titik, mode] { l.font = .systemFont(ofSize: 11) }
        jejak.text = "Jejak 0.00 km"
        titik.text = "Titik 0"
        mode.text = "Peta online"
        let infoStack = UIStackView(arrangedSubviews: [jejak, titik, mode])
        infoStack.axis = .horizontal
        infoStack.distribution = .equalSpacing
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        info.addSubview(infoStack)

        addSubview(map)
        addSubview(banner)
        addSubview(zoomIn)
        addSubview(zoomOut)
        addSubview(strip)
        addSubview(info)

        NSLayoutConstraint.activate([
            info.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            info.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            info.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            info.heightAnchor.constraint(equalToConstant: 26),
            infoStack.leadingAnchor.constraint(equalTo: info.leadingAnchor, constant: 10),
            infoStack.trailingAnchor.constraint(equalTo: info.trailingAnchor, constant: -10),
            infoStack.centerYAnchor.constraint(equalTo: info.centerYAnchor),

            strip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            strip.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            strip.bottomAnchor.constraint(equalTo: info.topAnchor, constant: -6),
            strip.heightAnchor.constraint(equalToConstant: 72),

            map.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            map.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            map.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            map.bottomAnchor.constraint(equalTo: strip.topAnchor, constant: -6),

            banner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            banner.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            banner.heightAnchor.constraint(equalToConstant: 52),
            h.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 10),
            h.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -10),
            h.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 34),

            zoomIn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            zoomIn.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 6),
            zoomIn.widthAnchor.constraint(equalToConstant: 34),
            zoomIn.heightAnchor.constraint(equalToConstant: 34),
            zoomOut.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            zoomOut.topAnchor.constraint(equalTo: zoomIn.bottomAnchor, constant: 4),
            zoomOut.widthAnchor.constraint(equalToConstant: 34),
            zoomOut.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !didSetCamera else { return }
        didSetCamera = true
        map.setUserTrackingMode(.follow, animated: false)
        if let c = map.camera.copy() as? MKMapCamera {
            c.altitude = 1500
            map.setCamera(c, animated: false)
        }
    }

    @objc private func zoomInTapped() { zoom(0.6) }
    @objc private func zoomOutTapped() { zoom(1 / 0.6) }

    private func zoom(_ factor: Double) {
        guard let c = map.camera.copy() as? MKMapCamera else { return }
        c.altitude = max(200, min(30000, c.altitude * factor))
        map.setCamera(c, animated: true)
    }

    /// Pasang ulang lapisan peta offline dari paket .mbtiles yang aktif.
    @objc private func reloadTiles() {
        if let o = tileOverlay {
            map.removeOverlay(o)
            tileOverlay = nil
        }
        let stores = MapPacks.activeStores()
        packBounds = stores.compactMap { $0.1.bounds() }
        packCount = stores.count
        centeredOnPack = false
        if stores.isEmpty {
            mode.text = "Peta online"
            return
        }
        let minZ = stores.map { $0.0.minZoom }.min() ?? 0
        let maxZ = stores.map { $0.0.maxZoom }.max() ?? 17
        let o = MBTilesOverlay(stores: stores.map { $0.1 }, minZ: minZ, maxZ: maxZ)
        map.insertOverlay(o, at: 0, level: .aboveLabels)
        tileOverlay = o
        mode.text = "Peta offline (\(stores.count))"
    }

    override func applyTheme() {
        speedCell.applyTheme()
        hrCell.applyTheme()
        banner.backgroundColor = Theme.bg
        banner.layer.borderColor = Theme.line.cgColor
        arrow.textColor = Theme.fg
        distLabel.textColor = Theme.fg
        subLabel.textColor = Theme.muted
        info.backgroundColor = Theme.cell
        for l in [jejak, titik, mode] { l.textColor = Theme.muted }
        for b in [zoomIn, zoomOut] {
            b.backgroundColor = Theme.bg
            b.setTitleColor(Theme.fg, for: .normal)
            b.layer.borderColor = Theme.line.cgColor
        }
    }

    /// Sebelum ada GPS: tampilkan area paket peta. Setelah GPS ada: ikuti posisi.
    private func updateCamera(_ e: RideEngine) {
        if let loc = e.currentLocation {
            if !followStarted {
                followStarted = true
                map.setUserTrackingMode(.follow, animated: false)
                if let c = map.camera.copy() as? MKMapCamera {
                    c.altitude = 3000
                    map.setCamera(c, animated: false)
                }
            }
            if tileOverlay != nil {
                let c = loc.coordinate
                let inside = packBounds.isEmpty || packBounds.contains {
                    c.longitude >= $0[0] && c.latitude >= $0[1] && c.longitude <= $0[2] && c.latitude <= $0[3]
                }
                mode.text = inside ? "Peta offline (\(packCount))" : "Di luar area peta"
            }
        } else if !centeredOnPack, let b = packBounds.first {
            centeredOnPack = true
            followStarted = false
            map.setUserTrackingMode(.none, animated: false)
            let center = CLLocationCoordinate2D(latitude: (b[1] + b[3]) / 2, longitude: (b[0] + b[2]) / 2)
            map.setCamera(MKMapCamera(lookingAtCenter: center, fromDistance: 25000, pitch: 0, heading: 0), animated: false)
        }
    }

    override func update(_ e: RideEngine) {
        updateCamera(e)
        speedCell.valueLabel.text = String(format: "%.1f", e.speedKmh)
        let hr = e.heartRate
        hrCell.valueLabel.text = hr > 0 ? "\(hr)" : "--"
        let z = hr > 0 ? zoneIndex(Double(hr)) : 0
        hrZone.text = z > 0 ? "Z\(z)" : ""
        let col = z > 0 ? Theme.zones[z - 1] : Theme.fg
        hrCell.valueLabel.textColor = col
        hrZone.textColor = col

        let now = Date()
        let refreshEvery: TimeInterval = Settings.batterySaver ? 6 : 3
        if e.trail.count != lastTrailCount &&
            (now.timeIntervalSince(lastTrailRefresh) >= refreshEvery || e.trail.count < 2 || lastTrailCount > e.trail.count) {
            refreshTrail(e.trail)
            lastTrailCount = e.trail.count
            lastTrailRefresh = now
        }

        if let start = e.trail.first, let cur = e.currentLocation {
            let d = CLLocation(latitude: start.latitude, longitude: start.longitude).distance(from: cur)
            distLabel.text = formatDistance(d)
            subLabel.text = "lurus ke titik awal"
            let brg = bearing(from: cur.coordinate, to: start)
            let heading = map.camera.heading * Double.pi / 180
            arrow.text = "↑"
            arrow.transform = CGAffineTransform(rotationAngle: CGFloat(brg - heading))
        } else {
            arrow.transform = CGAffineTransform.identity
            if e.waitingForStart {
                arrow.text = "📡"
                distLabel.text = "Menunggu GPS"
                subLabel.text = "Titik awal ditandai otomatis dari GPS"
            } else {
                arrow.text = "📍"
                distLabel.text = "Siap merekam"
                subLabel.text = "Titik awal ditandai otomatis saat Mulai"
            }
        }
        jejak.text = String(format: "Jejak %.2f km", e.distanceM / 1000)
        titik.text = "Titik \(e.trail.count)"
    }

    private func refreshTrail(_ coords: [CLLocationCoordinate2D]) {
        if let p = trailPoly {
            map.removeOverlay(p)
            trailPoly = nil
        }
        if coords.count >= 2 {
            let p = MKPolyline(coordinates: coords, count: coords.count)
            map.addOverlay(p, level: .aboveLabels)
            trailPoly = p
        }
        if let first = coords.first {
            if startPin == nil {
                let a = MKPointAnnotation()
                a.coordinate = first
                map.addAnnotation(a)
                startPin = a
            }
        } else if let a = startPin {
            map.removeAnnotation(a)
            startPin = nil
        }
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let t = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: t)
        }
        if let p = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: p)
            r.strokeColor = Theme.blue
            r.lineWidth = 5
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        let id = "start"
        let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
        v.annotation = annotation
        v.markerTintColor = Theme.green
        v.glyphText = "S"
        v.canShowCallout = false
        return v
    }
}
