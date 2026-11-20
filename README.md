# Gowes iOS v2 (cyclocomputer untuk iPhone 5s, iOS 12.5.7)

Empat halaman (geser kiri/kanan):
1. **Utama**: kecepatan, HR + grafik batang zona (tiap batang = rata-rata 5 detik), jarak, waktu, tanjakan, rata-rata, tombol Mulai/Jeda/Lap/Simpan.
2. **Peta jejak**: titik awal ditandai otomatis dari GPS pertama yang akurat (<= 25 m) setelah Mulai, garis biru jejak mengikuti posisi, jarak dan arah lurus ke titik awal.
3. **Tanjakan** (versi awal): ketinggian, kemiringan, total naik/turun, profil jalur terakhir.
4. **Ringkasan**: HR rata-rata/maks, waktu di zona, waktu bergerak/diam, tabel lap.

Jeda otomatis: kecepatan < 2 km/jam selama 3 detik, lanjut otomatis saat > 3 km/jam.
Tombol Simpan hanya muncul saat dijeda.

Jam ada di bar atas semua halaman. Ketuk bar atas untuk membuka **Pengaturan**:
status, paket peta offline, rekaman (jeda otomatis, jarak titik, lap otomatis), zona HR, hemat baterai dan redup layar, tema (terang/gelap/otomatis), riwayat rekaman.

## Simpan rekaman
- Tiap 30 detik jalur ditulis ke `Documents/gowes-draft.gpx` (aman kalau baterai habis atau aplikasi tertutup).
- Saat Simpan: `Documents/gowes-YYYYMMDD-HHMMSS.gpx` (berisi posisi, ketinggian, HR), draft dihapus.
- Daftar rekaman ada di Pengaturan > Riwayat (bagikan atau hapus). Draft yang tertinggal bisa dipulihkan dari sana.

## Peta offline (MBTiles)
Satu wilayah = satu file `.mbtiles` di `Documents/maps/` (misalnya `tegal-kota.mbtiles`, `tegal-kab.mbtiles`, `brebes.mbtiles`).
1. Di laptop: ambil data OSM wilayah, render dengan Maperitive (`generate-mbtiles minzoom=10 maxzoom=16`).
2. Salin file ke iPhone lewat kabel (`ifuse`) atau SSH ke folder Documents/maps.
3. Buka Pengaturan > Peta offline > Muat ulang, lalu aktifkan paketnya.
- Beberapa paket boleh aktif bersamaan. Di luar area paket, peta tampil kosong.
- Jangan mengunduh massal dari server resmi OpenStreetMap (dilarang kebijakannya).
- Tanpa paket aktif, peta memakai peta Apple (butuh internet) dan label bawah peta menjadi "Peta online".

## Build tanpa Mac (GitHub Actions)
**Cara zip (sama seperti sebelumnya):** ganti `gowes-ios.zip` di repo dengan zip ini. Workflow lama tetap jalan.
**Cara langsung:** ekstrak isi folder `gowes-ios` ke akar repo, termasuk `.github/workflows/build.yml`.

Pasang di iPhone 5s (setelah checkra1n + AppSync Unified):
    ideviceinstaller -i Gowes.ipa

## Catatan
- Kode belum pernah dikompilasi. Kalau build gagal, kirim log `error:` dari tab Actions.
- Halaman Tanjakan sengaja sederhana dan akan direvisi.
- Navigasi rute impor (GPX/TCX) belum ada.
