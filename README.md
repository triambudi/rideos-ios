# Gowes iOS v2 (cyclocomputer untuk iPhone 5s, iOS 12.5.7)

Empat halaman (geser kiri/kanan):
1. **Utama**: kecepatan, HR + grafik batang zona (tiap batang = rata-rata 5 detik), jarak, waktu, tanjakan, rata-rata, tombol Mulai/Jeda/Lap/Simpan.
2. **Peta jejak**: titik awal ditandai saat Mulai, garis biru jejak mengikuti posisi, jarak dan arah lurus ke titik awal.
3. **Tanjakan** (versi awal): ketinggian, kemiringan, total naik/turun, profil jalur terakhir.
4. **Ringkasan**: HR rata-rata/maks, waktu di zona, waktu bergerak/diam, tabel lap.

Jeda otomatis: kecepatan < 2 km/jam selama 3 detik, lanjut otomatis saat > 3 km/jam.
Tombol Simpan hanya muncul saat dijeda.

Ketuk bar atas (GPS / status / HR) untuk membuka panel: HR maks, jeda otomatis, tema gelap.

## Simpan rekaman
- Tiap 30 detik jalur ditulis ke `Documents/gowes-draft.gpx` (aman kalau baterai habis atau aplikasi tertutup).
- Saat Simpan: `Documents/gowes-YYYYMMDD-HHMMSS.gpx` (berisi posisi, ketinggian, HR), draft dihapus.
- Ambil lewat Filza (`/var/mobile/Containers/Data/Application/.../Documents`) atau `ifuse`.

## Peta offline
Letakkan ubin peta di `Documents/tiles/{z}/{x}/{y}.png` (skema XYZ, 256 px).
- Buat sendiri dengan MOBAC atau Maperitive di laptop, lalu salin folder `tiles` ke iPhone.
- Jangan mengunduh massal dari server resmi OpenStreetMap (dilarang kebijakannya).
- Tanpa folder `tiles`, peta memakai peta Apple (butuh internet) dan label di bawah jadi "Peta online".

## Build tanpa Mac (GitHub Actions)
**Cara zip (sama seperti sebelumnya):** ganti `gowes-ios.zip` di repo dengan zip ini. Workflow lama tetap jalan.
**Cara langsung:** ekstrak isi folder `gowes-ios` ke akar repo, termasuk `.github/workflows/build.yml`.

Pasang di iPhone 5s (setelah checkra1n + AppSync Unified):
    ideviceinstaller -i Gowes.ipa

## Catatan
- Kode belum pernah dikompilasi. Kalau build gagal, kirim log `error:` dari tab Actions.
- Halaman Tanjakan sengaja sederhana dan akan direvisi.
- Navigasi rute impor (GPX/TCX) belum ada.
