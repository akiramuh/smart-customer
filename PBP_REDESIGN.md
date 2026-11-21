# Redesign UI Smart Customer — PBP

Tanggal pengerjaan: 21 November 2026  
Branch: `feature/pbp-ui-redesign`  
Repository: `akiramuh/smart-customer`

## Tujuan

Melakukan perbaikan antarmuka Smart Customer untuk tugas Pemrograman Berorientasi Platform (PBP), tanpa mengubah alur utama autentikasi, penghitungan pengunjung, penyimpanan Firestore, dan notifikasi Android.

## Keputusan desain

1. Menggunakan warna utama biru, latar belakang abu-abu muda, panel putih, border tipis, dan tipografi dengan hierarki yang konsisten.
2. Pada perangkat sempit/ponsel, navigasi tetap menggunakan bottom navigation.
3. Pada layar lebar, navigasi beralih menjadi NavigationRail agar ruang konten lebih luas.
4. Dashboard memprioritaskan jumlah pengunjung saat ini, kapasitas, total masuk/keluar, tren, dan status sistem.
5. Status sistem hanya menampilkan Koneksi Data, Kamera & Computer Vision, serta Update Terakhir. Label ESP32 dan Sensor dihapus karena proyek tidak memakai perangkat tersebut.
6. Status kamera dan Computer Vision memakai heartbeat Python 15 detik dan batas data basi 60 detik.
7. Riwayat dan Analitik tetap menggunakan snapshot historis Firestore. Tidak ada data transaksi POS yang ditambahkan.
8. Halaman Pengaturan menampilkan akun Firebase, informasi sistem yang benar-benar tersedia, dan tombol logout dengan konfirmasi. Kontrol notifikasi lokal yang sebelumnya hanya mengubah state UI dihapus agar tidak memberi kesan bahwa pengaturan tersebut sudah terhubung ke FCM.

## Perubahan kode

- `lib/main.dart`: tema Material 3, warna, kartu, input, dan AppBar diselaraskan.
- `lib/screens/main_navigation.dart`: bottom navigation untuk ponsel dan NavigationRail untuk layar lebar.
- `lib/screens/dashboard_page.dart`: hierarki dashboard, kartu occupancy, KPI, tren, status sistem, dan state error/empty diperbarui.
- `lib/screens/analytics_page.dart`: ringkasan analitik menggunakan grid responsif.
- `lib/screens/history_page.dart`: item histori dirapikan dan state kosong/error dibuat lebih jelas.
- `lib/screens/settings_page.dart`: profil akun, informasi sistem, dan logout ditata ulang; referensi ESP32 dihapus.
- `lib/widgets/stat_card.dart`, `lib/widgets/info_card.dart`, `lib/widgets/status_item.dart`: komponen UI diseragamkan.
- `lib/models/customer_stats.dart`: status sumber data menggunakan nama kamera dan Computer Vision; batas basi 60 detik.
- `lib/services/realtime_service.dart`: dashboard membaca dokumen khusus `visitor_activity/current_<cameraId>`, bukan dokumen terbaru dari kumpulan snapshot.
- `computer_vision/count_customers.py`: menulis field `cameraCvOnline`; field lama `sensorOnline` sementara tetap disertakan untuk kompatibilitas.
- `test/widget_test.dart`: tes status kamera/CV dan halaman Pengaturan diselaraskan.
- `README.md`: dokumentasi antarmuka dan field status diperbarui.

## Pemeriksaan lokal yang wajib dilakukan

Perubahan di branch ini belum dianggap tervalidasi di perangkat sampai langkah berikut dijalankan dari root proyek.

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build web
python -m py_compile .\\computer_vision\\count_customers.py
```

Uji tampilan pada:
- Flutter Web di Chrome, lebar desktop.
- Flutter Web pada lebar sempit/mobile viewport.
- HP Android portrait.
- HP Android landscape.

## Checklist bukti tugas

- [ ] Simpan commit/titik balik sebelum redesign.
- [ ] Ambil screenshot sebelum dari HP Android.
- [ ] Ambil screenshot sesudah dari HP Android yang sama, orientasi dan ukuran layar sama.
- [ ] Pastikan tidak ada overflow pada setiap halaman.
- [ ] Pastikan Dashboard, Analitik, Riwayat, dan Pengaturan dapat dibuka.
- [ ] Pastikan login dan logout tetap berfungsi.
- [ ] Pastikan data Dashboard tetap berubah ketika Python menulis ke Firestore.
- [ ] Pastikan status Kamera & Computer Vision berubah menjadi Offline setelah heartbeat melewati 60 detik.
- [ ] Jalankan seluruh perintah pemeriksaan di atas dan simpan output-nya.
- [ ] Lampirkan screenshot dan hasil pengujian pada laporan PBP.

Nama file bukti yang disarankan:
- `docs/evidence/before-dashboard-android.png`
- `docs/evidence/after-dashboard-android.png`
- `docs/evidence/after-analytics-android.png`
- `docs/evidence/after-history-android.png`
- `docs/evidence/after-settings-android.png`

Screenshot harus diambil dari aplikasi yang benar-benar berjalan; jangan menggantinya dengan mockup.

## Status verifikasi

Kode UI dan dokumentasi telah diperbarui pada branch kerja. Pemeriksaan `flutter analyze`, `flutter test`, build, dan screenshot langsung dari HP masih harus dilakukan di lingkungan lokal proyek. Jangan menyatakan tugas selesai sepenuhnya sebelum bukti tersebut tersedia.
