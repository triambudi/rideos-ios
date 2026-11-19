import Foundation
import CoreLocation
import CoreBluetooth
import UIKit

struct TrackPoint {
    let lat: Double
    let lon: Double
    let ele: Double
    let time: Date
    let hr: Int
}

struct LapRecord {
    let n: Int
    let km: Double
    let seconds: TimeInterval
    let avgKmh: Double
    let avgHR: Int
}

protocol RideEngineDelegate: AnyObject {
    func engineDidUpdate(_ engine: RideEngine)
}

final class RideEngine: NSObject, CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    enum State { case idle, running, paused, autoPaused }

    static var documentsURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    weak var delegate: RideEngineDelegate?

    // Live
    private(set) var state: State = .idle
    private(set) var speedKmh = 0.0
    private(set) var heartRate = 0
    private(set) var gpsAccuracy: Double?
    private(set) var hrStatus = "HR: mencari..."
    private(set) var message = ""
    private(set) var currentLocation: CLLocation?

    // Statistik rekaman
    private(set) var distanceM = 0.0
    private(set) var elapsed: TimeInterval = 0
    private(set) var stoppedTime: TimeInterval = 0
    private(set) var maxSpeedKmh = 0.0
    private(set) var gainM = 0.0
    private(set) var lossM = 0.0
    private(set) var altitude = 0.0
    private(set) var hasAltitude = false
    private(set) var grade = 0.0
    private(set) var hrSum = 0
    private(set) var hrCount = 0
    private(set) var hrMaxSeen = 0
    private(set) var zoneSeconds = [Double](repeating: 0, count: 5)
    private(set) var laps: [LapRecord] = []
    private(set) var points: [TrackPoint] = []
    private(set) var trail: [CLLocationCoordinate2D] = []
    private(set) var hrBars: [Double] = []
    private(set) var profile: [(ele: Double, grade: Double)] = []

    var avgKmh: Double { return elapsed > 0 ? (distanceM / 1000) / (elapsed / 3600) : 0 }
    var currentBar: Double? { return barCount > 0 ? Double(barSum) / Double(barCount) : nil }

    // Internal
    private let lm = CLLocationManager()
    private var central: CBCentralManager!
    private var hrPeripheral: CBPeripheral?
    private let hrService = CBUUID(string: "180D")
    private let hrChar = CBUUID(string: "2A37")
    private var lastHrTime: Date?
    private var timer: Timer?
    private var lastTick: Date?
    private var lastFix: Date?
    private var lastRecorded: CLLocation?
    private var still = 0
    private var autosaveCounter = 0
    private var barSum = 0
    private var barCount = 0
    private var altSmooth: Double?
    private var altRef: Double?
    private var profileAcc = 0.0
    private var lastProfileEle: Double?
    private var lapStartDist = 0.0
    private var lapStartElapsed: TimeInterval = 0
    private var lapHrSum = 0
    private var lapHrCount = 0
    private let ioQueue = DispatchQueue(label: "my.idubma.gowes.io")

    override init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        lm.activityType = .fitness
        lm.distanceFilter = kCLDistanceFilterNone
        lm.allowsBackgroundLocationUpdates = true
        lm.pausesLocationUpdatesAutomatically = false
        central = CBCentralManager(delegate: self, queue: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResign),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    func begin() {
        lm.requestWhenInUseAuthorization()
        lm.startUpdatingLocation()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func appWillResign() { saveDraft() }

    // MARK: - Kontrol

    func startPause() {
        switch state {
        case .idle:
            resetRide()
            state = .running
            lastTick = Date()
            if let l = currentLocation { record(l) }
        case .running:
            state = .paused
        case .paused, .autoPaused:
            resume()
        }
        delegate?.engineDidUpdate(self)
    }

    func lap() {
        guard state == .running else { return }
        let n = laps.count + 1
        let km = (distanceM - lapStartDist) / 1000
        let secs = elapsed - lapStartElapsed
        let avg = secs > 0 ? km / (secs / 3600) : 0
        let hrAvg = lapHrCount > 0 ? lapHrSum / lapHrCount : 0
        laps.insert(LapRecord(n: n, km: km, seconds: secs, avgKmh: avg, avgHR: hrAvg), at: 0)
        lapStartDist = distanceM
        lapStartElapsed = elapsed
        lapHrSum = 0
        lapHrCount = 0
        flash("Lap \(n)")
        delegate?.engineDidUpdate(self)
    }

    /// Simpan GPX lalu reset. Mengembalikan URL file bila ada data.
    @discardableResult
    func finish() -> URL? {
        guard state != .idle else { return nil }
        var url: URL?
        if points.count > 1 {
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd-HHmmss"
            let target = RideEngine.documentsURL.appendingPathComponent("gowes-\(df.string(from: Date())).gpx")
            let text = RideEngine.gpx(points)
            let draft = RideEngine.documentsURL.appendingPathComponent("gowes-draft.gpx")
            ioQueue.sync {
                do {
                    try text.write(to: target, atomically: true, encoding: .utf8)
                    url = target
                    try? FileManager.default.removeItem(at: draft)
                } catch {
                    url = nil
                }
            }
        }
        state = .idle
        resetRide()
        flash(url != nil ? "Tersimpan (GPX)" : "Tidak ada data")
        delegate?.engineDidUpdate(self)
        return url
    }

    private func resume() {
        state = .running
        still = 0
        lastRecorded = currentLocation
        altRef = altSmooth
        lastTick = Date()
    }

    private func resetRide() {
        distanceM = 0; elapsed = 0; stoppedTime = 0; maxSpeedKmh = 0
        gainM = 0; lossM = 0; grade = 0
        hrSum = 0; hrCount = 0; hrMaxSeen = 0
        zoneSeconds = [Double](repeating: 0, count: 5)
        laps = []; points = []; trail = []; profile = []
        lapStartDist = 0; lapStartElapsed = 0; lapHrSum = 0; lapHrCount = 0
        lastRecorded = nil; altRef = nil; still = 0; autosaveCounter = 0
        profileAcc = 0; lastProfileEle = nil
    }

    private func flash(_ text: String) {
        message = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.message == text else { return }
            self.message = ""
            self.delegate?.engineDidUpdate(self)
        }
    }

    // MARK: - Tick 1 Hz

    private func tick() {
        let now = Date()
        let dt = lastTick.map { now.timeIntervalSince($0) } ?? 1
        lastTick = now

        if let t = lastFix, now.timeIntervalSince(t) > 3 { speedKmh = 0 }
        if let t = lastHrTime, now.timeIntervalSince(t) > 6 { heartRate = 0 }

        switch state {
        case .running:
            elapsed += dt
            if heartRate > 0 {
                let z = zoneIndex(Double(heartRate))
                zoneSeconds[z - 1] += dt
                hrSum += heartRate
                hrCount += 1
                hrMaxSeen = max(hrMaxSeen, heartRate)
                lapHrSum += heartRate
                lapHrCount += 1
            }
            if Settings.autoPause {
                if speedKmh < Settings.pauseBelowKmh { still += 1 } else { still = 0 }
                if still >= Settings.pauseAfterSeconds { state = .autoPaused; still = 0 }
            }
            autosaveCounter += 1
            if autosaveCounter >= 30 { autosaveCounter = 0; saveDraft() }
        case .autoPaused:
            stoppedTime += dt
            if speedKmh > Settings.resumeAboveKmh { resume() }
        case .paused:
            stoppedTime += dt
        case .idle:
            break
        }

        if heartRate > 0 {
            barSum += heartRate
            barCount += 1
            if barCount >= 5 {
                hrBars.append(Double(barSum) / Double(barCount))
                if hrBars.count > 17 { hrBars.removeFirst() }
                barSum = 0
                barCount = 0
            }
        }
        delegate?.engineDidUpdate(self)
    }

    // MARK: - GPS

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for l in locations {
            guard l.horizontalAccuracy >= 0 else { continue }
            gpsAccuracy = l.horizontalAccuracy
            guard l.horizontalAccuracy < 30 else { continue }
            lastFix = Date()
            currentLocation = l
            var v = l.speed >= 0 ? l.speed * 3.6 : 0
            if v < 1.5 { v = 0 }
            speedKmh = v
            updateAltitude(l)
            if state == .running { record(l) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        gpsAccuracy = nil
    }

    private func updateAltitude(_ l: CLLocation) {
        guard l.verticalAccuracy >= 0, l.verticalAccuracy < 20 else { return }
        let a: Double
        if let s = altSmooth { a = s * 0.8 + l.altitude * 0.2 } else { a = l.altitude }
        altSmooth = a
        altitude = a
        hasAltitude = true
        guard state == .running else { return }
        guard let ref = altRef else { altRef = a; return }
        let diff = a - ref
        if diff > 3 { gainM += diff; altRef = a }
        else if diff < -3 { lossM += -diff; altRef = a }
    }

    private func record(_ l: CLLocation) {
        maxSpeedKmh = max(maxSpeedKmh, speedKmh)
        if let last = lastRecorded {
            let d = l.distance(from: last)
            if d < 5 { return }
            distanceM += d
            profileAcc += d
        }
        lastRecorded = l
        points.append(TrackPoint(lat: l.coordinate.latitude, lon: l.coordinate.longitude,
                                 ele: hasAltitude ? altitude : l.altitude, time: l.timestamp, hr: heartRate))
        trail.append(l.coordinate)
        if hasAltitude {
            if lastProfileEle == nil { lastProfileEle = altitude }
            if profileAcc >= 20, let prev = lastProfileEle {
                let g = max(-25, min(25, (altitude - prev) / profileAcc * 100))
                grade = grade * 0.7 + g * 0.3
                profile.append((ele: altitude, grade: grade))
                if profile.count > 100 { profile.removeFirst() }
                lastProfileEle = altitude
                profileAcc = 0
            }
        }
    }

    // MARK: - Simpan

    private func saveDraft() {
        guard points.count > 1 else { return }
        let pts = points
        let url = RideEngine.documentsURL.appendingPathComponent("gowes-draft.gpx")
        ioQueue.async {
            let text = RideEngine.gpx(pts)
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func gpx(_ pts: [TrackPoint]) -> String {
        let iso = ISO8601DateFormatter()
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        s += "<gpx version=\"1.1\" creator=\"Gowes\" xmlns=\"http://www.topografix.com/GPX/1/1\" "
        s += "xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\">\n"
        s += "<trk><name>Gowes</name><trkseg>\n"
        for p in pts {
            s += "<trkpt lat=\"\(p.lat)\" lon=\"\(p.lon)\"><ele>\(p.ele)</ele><time>\(iso.string(from: p.time))</time>"
            if p.hr > 0 {
                s += "<extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>\(p.hr)</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions>"
            }
            s += "</trkpt>\n"
        }
        s += "</trkseg></trk></gpx>\n"
        return s
    }

    // MARK: - Bluetooth HR

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        if c.state == .poweredOn { scan() } else { hrStatus = "HR: Bluetooth mati" }
    }

    private func scan() {
        hrStatus = "HR: mencari..."
        central.scanForPeripherals(withServices: [hrService], options: nil)
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        hrPeripheral = p
        p.delegate = self
        c.stopScan()
        c.connect(p, options: nil)
        hrStatus = "HR: menyambung..."
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        hrStatus = "HR: tersambung"
        p.discoverServices([hrService])
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        hrPeripheral = nil
        scan()
    }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        heartRate = 0
        hrPeripheral = nil
        scan()
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics([hrChar], for: s) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for c in s.characteristics ?? [] where c.uuid == hrChar { p.setNotifyValue(true, for: c) }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard let data = c.value else { return }
        let b = [UInt8](data)
        guard b.count >= 2 else { return }
        var v = 0
        if (b[0] & 0x01) == 0 {
            v = Int(b[1])
        } else if b.count >= 3 {
            v = Int(b[1]) | (Int(b[2]) << 8)
        }
        if v > 0 {
            heartRate = v
            lastHrTime = Date()
        }
    }
}
