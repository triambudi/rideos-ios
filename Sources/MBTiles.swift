import Foundation
import MapKit
import SQLite3

/// Pembaca satu file .mbtiles (SQLite).
/// Sumbu y standar MBTiles terbalik (TMS); skema dideteksi otomatis dari metadata bila memungkinkan.
final class MBTilesStore {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "my.idubma.gowes.mbtiles")
    private(set) var flipY = true

    init?(path: String) {
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            sqlite3_close(db)
            return nil
        }
        detectScheme()
    }

    deinit { sqlite3_close(db) }

    // Hanya dipanggil di dalam queue.
    private func fetch(z: Int, x: Int, row: Int) -> Data? {
        var stmt: OpaquePointer?
        let sql = "SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(z))
        sqlite3_bind_int(stmt, 2, Int32(x))
        sqlite3_bind_int(stmt, 3, Int32(row))
        if sqlite3_step(stmt) == SQLITE_ROW, let bytes = sqlite3_column_blob(stmt, 0) {
            let n = Int(sqlite3_column_bytes(stmt, 0))
            return Data(bytes: bytes, count: n)
        }
        return nil
    }

    func tile(z: Int, x: Int, y: Int) -> Data? {
        return queue.sync { () -> Data? in
            let row = flipY ? (1 << z) - 1 - y : y
            return fetch(z: z, x: x, row: row)
        }
    }

    /// Nilai dari tabel metadata (minzoom, maxzoom, bounds, scheme, ...). Kunci hanya konstanta dari kode.
    func metadata(_ key: String) -> String? {
        return queue.sync { () -> String? in
            var stmt: OpaquePointer?
            let sql = "SELECT value FROM metadata WHERE name = '\(key)' LIMIT 1"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
                return String(cString: c)
            }
            return nil
        }
    }

    /// Rentang zoom yang benar-benar ada di tabel tiles. nil bila tabel tidak terbaca atau kosong.
    func zoomRange() -> (Int, Int)? {
        return queue.sync { () -> (Int, Int)? in
            var stmt: OpaquePointer?
            let sql = "SELECT MIN(zoom_level), MAX(zoom_level) FROM tiles"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return nil }
            return (Int(sqlite3_column_int(stmt, 0)), Int(sqlite3_column_int(stmt, 1)))
        }
    }

    /// Area paket: [minLon, minLat, maxLon, maxLat] dari metadata "bounds".
    func bounds() -> [Double]? {
        guard let b = metadata("bounds") else { return nil }
        let p = b.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return p.count == 4 ? p : nil
    }

    /// Tentukan TMS atau XYZ: dari metadata "scheme", atau dengan mengecek ubin di tengah "bounds".
    private func detectScheme() {
        if let sch = metadata("scheme")?.lowercased() {
            if sch == "xyz" { flipY = false; return }
            if sch == "tms" { flipY = true; return }
        }
        guard let b = metadata("bounds") else { return }
        let p = b.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard p.count == 4, let zr = zoomRange() else { return }
        let lon = (p[0] + p[2]) / 2
        let lat = (p[1] + p[3]) / 2
        let z = zr.0
        let n = Double(1 << z)
        let x = Int(floor((lon + 180) / 360 * n))
        let latRad = lat * Double.pi / 180
        let y = Int(floor((1 - asinh(tan(latRad)) / Double.pi) / 2 * n))
        let tmsRow = (1 << z) - 1 - y
        let hasTMS = queue.sync { fetch(z: z, x: x, row: tmsRow) != nil }
        let hasXYZ = queue.sync { fetch(z: z, x: x, row: y) != nil }
        if hasXYZ && !hasTMS { flipY = false }
    }
}

/// Satu lapisan peta yang mencari ubin di beberapa paket (urut), tanpa internet.
final class MBTilesOverlay: MKTileOverlay {
    private let stores: [MBTilesStore]

    init(stores: [MBTilesStore], minZ: Int, maxZ: Int) {
        self.stores = stores
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = minZ
        maximumZ = maxZ
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        for s in stores {
            if let d = s.tile(z: path.z, x: path.x, y: path.y) {
                result(d, nil)
                return
            }
        }
        result(nil, NSError(domain: "gowes.tile", code: 404, userInfo: nil))
    }
}

struct MapPack {
    let file: String
    let url: URL
    let size: Int64
    let minZoom: Int
    let maxZoom: Int
    /// nil = siap dipakai; selain itu alasan gagal.
    let status: String?
    var title: String { return (file as NSString).deletingPathExtension }
}

/// Paket peta = file .mbtiles di Documents/maps
enum MapPacks {
    static var folder: URL {
        return RideEngine.documentsURL.appendingPathComponent("maps", isDirectory: true)
    }

    static func ensureFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func scan() -> [MapPack] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { return [] }
        var out: [MapPack] = []
        for n in names.sorted() where n.lowercased().hasSuffix(".mbtiles") {
            let u = folder.appendingPathComponent(n)
            let size = fileSize(u)
            var minZ = 0
            var maxZ = 17
            var status: String?
            if !fm.isReadableFile(atPath: u.path) {
                status = "izin baca ditolak"
            } else if let st = MBTilesStore(path: u.path) {
                if let zr = st.zoomRange() {
                    minZ = zr.0
                    maxZ = zr.1
                } else {
                    status = "tabel tiles tidak terbaca"
                }
            } else {
                status = "gagal dibuka"
            }
            out.append(MapPack(file: n, url: u, size: size, minZoom: minZ, maxZoom: maxZ, status: status))
        }
        return out
    }

    /// Jika belum pernah diatur, semua paket aktif.
    static func isActive(_ p: MapPack) -> Bool {
        if let a = UserDefaults.standard.stringArray(forKey: "activePacks") { return a.contains(p.file) }
        return true
    }

    static func setActive(_ p: MapPack, _ on: Bool) {
        var a = UserDefaults.standard.stringArray(forKey: "activePacks") ?? scan().map { $0.file }
        a.removeAll { $0 == p.file }
        if on { a.append(p.file) }
        UserDefaults.standard.set(a, forKey: "activePacks")
        NotificationCenter.default.post(name: .packsChanged, object: nil)
    }

    static func activeStores() -> [(MapPack, MBTilesStore)] {
        var out: [(MapPack, MBTilesStore)] = []
        for p in scan() where isActive(p) && p.status == nil {
            if let s = MBTilesStore(path: p.url.path) { out.append((p, s)) }
        }
        return out
    }

    static func sizeText(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }

    /// Teks diagnosa untuk ditampilkan di Pengaturan (bisa di-screenshot).
    static func diagnosticText() -> String {
        let fm = FileManager.default
        var lines: [String] = []
        lines.append("Folder yang dibaca aplikasi:")
        lines.append(folder.path)
        let names = ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
        if names.isEmpty {
            lines.append("")
            lines.append("Folder kosong. Salin file .mbtiles ke folder ini.")
        }
        for n in names {
            let u = folder.appendingPathComponent(n)
            var line = "- \(n) (\(sizeText(fileSize(u))))"
            if !n.lowercased().hasSuffix(".mbtiles") {
                line += ": bukan .mbtiles, diabaikan"
            } else if !fm.isReadableFile(atPath: u.path) {
                line += ": izin baca ditolak"
            } else if let s = MBTilesStore(path: u.path) {
                if let zr = s.zoomRange() {
                    line += ": OK, zoom \(zr.0)-\(zr.1), skema \(s.flipY ? "TMS" : "XYZ")"
                } else {
                    line += ": tabel tiles tidak terbaca atau kosong"
                }
            } else {
                line += ": gagal dibuka"
            }
            lines.append(line)
        }
        let active = activeStores().count
        lines.append("")
        lines.append("Paket aktif: \(active)")
        return lines.joined(separator: "\n")
    }
}
