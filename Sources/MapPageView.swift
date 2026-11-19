import UIKit
import MapKit

/// Ubin peta offline dari folder Documents/tiles/{z}/{x}/{y}.png
final class LocalTileOverlay: MKTileOverlay {
    private let root: URL

    init(root: URL) {
        self.root = root
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 0
        maximumZ = 19
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        return root.appendingPathComponent("\(path.z)/\(path.x)/\(path.y).png")
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let u = url(forTilePath: path)
        if let d = try? Data(contentsOf: u) {
            result(d, nil)
        } else {
            result(nil, NSError(domain: "gowes.tile", code: 404, userInfo: nil))
        }
    }
}

final class MapPageView: PageView, MKMapViewDelegate {
    private let map = MKMapView()
    private let banner = UIView()
    private let arrow = UILabel()
    private let distLabel = UILabel()
    private let subLabel = UILabel()
    private let zoomIn = UIButton(type: .custom)
    private let zoomOut = UIButton(type: .custom)
    private let info = UIView()
    private let jejak = UILabel()
    private let titik = UILabel()
    private let mode = UILabel()
    private var trailPoly: MKPolyline?
    private var startPin: MKPointAnnotation?
    private var lastTrailCount = -1
    private var lastTrailRefresh = Date.distantPast
    private var hasLocalTiles = false
    private var didSetCamera = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        map.translatesAutoresizingMaskIntoConstraints = false
        map.layer.cornerRadius = 10
        map.clipsToBounds = true
        map.delegate = self
        map.showsUserLocation = true
        // Gerak peta dimatikan agar geser halaman tetap bisa dilakukan; peta selalu mengikuti posisi.
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false

        let tilesDir = RideEngine.documentsURL.appendingPathComponent("tiles")
        if FileManager.default.fileExists(atPath: tilesDir.path) {
            map.addOverlay(LocalTileOverlay(root: tilesDir), level: .aboveLabels)
            hasLocalTiles = true
        }

        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 10
        banner.layer.borderWidth = 0.5
        arrow.font = .systemFont(ofSize: 30)
        arrow.textAlignment = .center
        arrow.text = "📍"
        distLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        distLabel.text = "Siap merekam"
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.text = "Tekan Mulai untuk menandai titik awal"
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

        info.translatesAutoresizingMaskIntoConstraints = false
        info.layer.cornerRadius = 10
        for l in [jejak, titik, mode] { l.font = .systemFont(ofSize: 12) }
        jejak.text = "Jejak 0.00 km"
        titik.text = "Titik 0"
        mode.text = hasLocalTiles ? "Peta offline" : "Peta online"
        let infoStack = UIStackView(arrangedSubviews: [jejak, titik, mode])
        infoStack.axis = .horizontal
        infoStack.distribution = .equalSpacing
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        info.addSubview(infoStack)

        addSubview(map)
        addSubview(banner)
        addSubview(zoomIn)
        addSubview(zoomOut)
        addSubview(info)

        NSLayoutConstraint.activate([
            info.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            info.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            info.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            info.heightAnchor.constraint(equalToConstant: 40),
            infoStack.leadingAnchor.constraint(equalTo: info.leadingAnchor, constant: 10),
            infoStack.trailingAnchor.constraint(equalTo: info.trailingAnchor, constant: -10),
            infoStack.centerYAnchor.constraint(equalTo: info.centerYAnchor),

            map.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            map.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            map.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            map.bottomAnchor.constraint(equalTo: info.topAnchor, constant: -6),

            banner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            banner.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            banner.heightAnchor.constraint(equalToConstant: 58),
            h.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 10),
            h.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -10),
            h.centerYAnchor.constraint(equalTo: banner.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 36),

            zoomIn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            zoomIn.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 6),
            zoomIn.widthAnchor.constraint(equalToConstant: 36),
            zoomIn.heightAnchor.constraint(equalToConstant: 36),
            zoomOut.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            zoomOut.topAnchor.constraint(equalTo: zoomIn.bottomAnchor, constant: 4),
            zoomOut.widthAnchor.constraint(equalToConstant: 36),
            zoomOut.heightAnchor.constraint(equalToConstant: 36)
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

    override func applyTheme() {
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

    override func update(_ e: RideEngine) {
        let now = Date()
        if e.trail.count != lastTrailCount &&
            (now.timeIntervalSince(lastTrailRefresh) >= 3 || e.trail.count < 2 || lastTrailCount > e.trail.count) {
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
            arrow.text = "📍"
            arrow.transform = CGAffineTransform.identity
            distLabel.text = "Siap merekam"
            subLabel.text = "Tekan Mulai untuk menandai titik awal"
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
