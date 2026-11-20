import Foundation
import MapKit
import SQLite3

/// Pembaca satu file .mbtiles (SQLite). Sumbu y di MBTiles terbalik (TMS), jadi dikonversi dari XYZ.
final class MBTilesStore {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "my.idubma.gowes.mbtiles")

    init?(path: String) {
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            sqlite3_close(db)
            return nil
        }
    }

    deinit { sqlite3_close(db) }

    func tile(z: Int, x: Int, y: Int) -> Data? {
        return queue.sync { () -> Data? in
            let row = (1 << z) - 1 - y
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
    }

    /// Nilai dari tabel metadata (minzoom, maxzoom, name, bounds, ...). Kunci hanya konstanta dari kode.
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

    static func scan() -> [MapPack] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { return [] }
        var out: [MapPack] = []
        for n in names.sorted() where n.lowercased().hasSuffix(".mbtiles") {
            let u = folder.appendingPathComponent(n)
            let size = ((try? fm.attributesOfItem(atPath: u.path))?[.size] as? NSNumber)?.int64Value ?? 0
            var minZ = 0
            var maxZ = 17
            if let st = MBTilesStore(path: u.path) {
                minZ = Int(st.metadata("minzoom") ?? "") ?? 0
                maxZ = Int(st.metadata("maxzoom") ?? "") ?? 17
            }
            out.append(MapPack(file: n, url: u, size: size, minZoom: minZ, maxZoom: maxZ))
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
        for p in scan() where isActive(p) {
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
}
