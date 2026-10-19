# Smart Customer

Smart Customer adalah prototipe sistem pemantauan pengunjung minimarket. Aplikasi Flutter menampilkan statistik dari Cloud Firestore, sedangkan program Python menggunakan YOLO dan OpenCV untuk mendeteksi orang, memperkirakan jumlah pengunjung yang masuk/keluar, serta mengirimkan data agregat ke Firestore.

> **Status proyek:** login Firebase Authentication, pembacaan dashboard, pengiriman data dari Computer Vision ke Firestore, halaman Riwayat dan Analitik, `flutter analyze`, `flutter test`, dan build web telah diuji pada lingkungan pengembangan. Akurasi penghitungan, uji keamanan menyeluruh, dan ketahanan saat kamera/jaringan terputus masih perlu diuji lebih lanjut.

## Fitur

- Login pengguna melalui Firebase Authentication (Email/Password).
- Akses baca Firestore berdasarkan peran pengguna (`admin`, `operator`, atau `viewer`).
- Dashboard pengunjung yang membaca data Firestore secara real-time.
- Computer Vision berbasis Ultralytics YOLO, OpenCV, dan ByteTrack.
- Penghitungan masuk, keluar, dan estimasi pengunjung di dalam toko.
- Pengiriman statistik agregat ke Firestore; video dan frame mentah tidak dikirim ke Firestore.
- Riwayat dan Analitik menggunakan snapshot historis yang tersedia di Firestore.
- Mode Computer Vision operasional berjalan tanpa jendela preview; preview hanya digunakan saat debugging.

## Arsitektur singkat

```text
Kamera
  ↓
Python + OpenCV + YOLO/ByteTrack
  ↓ data agregat
Firebase Admin SDK
  ↓
Cloud Firestore
  ↓ stream/read
Flutter Web / Dashboard / Riwayat / Analitik
```

## Teknologi

- Flutter dan Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Admin SDK untuk Python
- Python, Ultralytics YOLO, OpenCV, dan ByteTrack

## Struktur direktori penting

```text
smart_customer_flutter/
├── computer_vision/
│   ├── count_customers.py
│   ├── requirements.txt
│   └── yolo26n.pt
├── lib/
│   ├── auth/
│   ├── models/
│   ├── screens/
│   ├── services/
│   └── main.dart
├── test/
├── firebase.json
├── firestore.rules
├── pubspec.yaml
└── README.md
```

## Prasyarat

- Flutter SDK dan Dart yang kompatibel dengan `pubspec.yaml` proyek.
- Python yang kompatibel dengan dependency dalam `computer_vision/requirements.txt`.
- Git.
- Akun dan proyek Firebase yang memiliki akses ke proyek `smart-customer-ecc66`.
- Webcam yang dapat diakses komputer.
- Untuk Windows yang menggunakan plugin Flutter, aktifkan **Developer Mode** jika Flutter meminta dukungan symbolic link.

## Konfigurasi Firebase

### 1. Konfigurasi Flutter

Repository harus memiliki konfigurasi Firebase Flutter yang sesuai, termasuk `lib/firebase_options.dart` dan konfigurasi platform yang dibutuhkan. Jangan menyalin konfigurasi dari proyek Firebase lain tanpa menyesuaikan proyek.

Pasang dependency Flutter dari root proyek:

```powershell
flutter pub get
```

### 2. Aktifkan Authentication

Di Firebase Console untuk proyek `smart-customer-ecc66`:

1. Buka **Authentication → Sign-in method**.
2. Aktifkan penyedia **Email/Password**.
3. Buat pengguna melalui **Authentication → Users**.
4. Di Firestore, buat dokumen `users/{UID}` untuk masing-masing pengguna yang diizinkan, dengan field string `role` yang bernilai `admin`, `operator`, atau `viewer`.

Aplikasi tidak menyediakan pendaftaran publik untuk membuat peran. Jangan memberikan peran istimewa tanpa verifikasi.

### 3. Firestore Rules

File rules utama adalah `firestore.rules`, yang direferensikan dari `firebase.json`. Untuk memvalidasi dan menerapkan rules, pastikan sudah login ke Firebase CLI dan proyek yang dipilih benar:

```powershell
firebase login
firebase projects:list
firebase deploy --only firestore:rules --project smart-customer-ecc66
```

Deployment mengubah aturan database online. Tinjau `firestore.rules` dan pastikan akun serta dokumen peran pengguna sudah tersedia sebelum deploy. Flutter membaca data sesuai rules; proses Python menggunakan Firebase Admin SDK dan hak akses servernya.

## Menjalankan Computer Vision

### 1. Siapkan virtual environment dan dependency

Jalankan perintah ini dari root proyek di PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r .\computer_vision\requirements.txt
```

Jika virtual environment belum ada, buat terlebih dahulu:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r .\computer_vision\requirements.txt
```

### 2. Simpan service account dengan aman

Computer Vision menulis ke Firestore melalui Firebase Admin SDK. Gunakan service account yang memiliki izin data Firestore minimum yang diperlukan. Simpan JSON key di folder lokal yang dilindungi **di luar repository**, misalnya:

```text
C:\Users\<USERNAME>\firebase-keys\smart-customer-ecc66-service-account.json
```

Jangan memasukkan key ini ke Git, ZIP yang dibagikan, screenshot, atau repository publik. `.gitignore` mengecualikan pola file service-account dan environment secrets, tetapi tetap periksa `git status` sebelum commit.

### 3. Jalankan proses operasional (headless)

Jalankan dari root proyek pada terminal pertama. Sesuaikan path key jika disimpan di lokasi berbeda:

```powershell
python .\computer_vision\count_customers.py `
  --credentials "$HOME\firebase-keys\smart-customer-ecc66-service-account.json" `
  --project-id "smart-customer-ecc66" `
  --camera-id "minimarket-main" `
  --publish-seconds 15 `
  --snapshot-seconds 60
```

Mode default adalah **headless**: program tidak menampilkan jendela video/bounding box dan hanya mengirim statistik agregat. Biarkan terminal ini tetap terbuka selama program berjalan. Hentikan dengan `Ctrl+C` di terminal tersebut.

Untuk melihat opsi yang tersedia:

```powershell
python .\computer_vision\count_customers.py --help
```

Opsi `--preview` menampilkan video lokal untuk debugging. Jangan gunakan preview saat menguji mode operasional tanpa tampilan video.

## Menjalankan dashboard Flutter secara bersamaan

**Jangan menjalankan kedua proses di terminal yang sama.** Buka dua terminal VS Code pada root proyek.

**Terminal 1 — Computer Vision:** jalankan perintah headless di bagian sebelumnya dan biarkan tetap hidup.

**Terminal 2 — Flutter Web:** jalankan:

```powershell
flutter run -d chrome
```

Dashboard membaca Firestore dan dapat menampilkan pembaruan ketika proses Python masih berjalan. Jika ingin menghentikan Flutter debug, tekan `q` di terminal Flutter; proses Computer Vision di terminal terpisah tetap berjalan.

## Kontrak data Firestore

### `visitor_activity/current_{cameraId}`

Dokumen kondisi terkini yang diperbarui secara periodik. Field inti yang digunakan Flutter:

| Field | Tipe | Arti |
|---|---|---|
| `timestamp` | Firestore Timestamp | Waktu update terakhir |
| `jumlahDiDalam` | integer | Estimasi pengunjung di dalam |
| `totalMasuk` | integer | Total masuk pada hari lokal yang aktif |
| `totalKeluar` | integer | Total keluar pada hari lokal yang aktif |
| `maxCapacity` | integer | Kapasitas maksimal yang dikonfigurasi |
| `sensorOnline` | boolean | Status loop kamera/CV menurut publisher |
| `cameraId` | string | ID logis kamera |

Dokumen kondisi terkini tidak dipakai sebagai titik riwayat agar tidak menghitung sampel terbaru berulang kali.

### Snapshot historis di `visitor_activity`

Program menambahkan snapshot berkala dengan field agregat yang sama dan `isSnapshot: true`. Secara default interval snapshot adalah 60 detik. Halaman Riwayat dan Analitik menggunakan dokumen snapshot historis yang tersedia; jika proses baru berjalan sebentar, periode historis yang tersedia juga masih pendek.

### `visitor_state/{cameraId}`

Menyimpan state penghitung yang digunakan program Python untuk memulihkan hitungan setelah proses dimulai ulang.

### Batasan saat ini

Desain ini mengasumsikan **satu proses Computer Vision aktif per `cameraId`**. Jangan menjalankan dua proses dengan `--camera-id` yang sama karena keduanya dapat saling menimpa data. Beberapa kamera memerlukan strategi agregasi sebelum angka dapat dianggap sebagai total satu toko.

## Pemeriksaan dan build

Dari root proyek Flutter:

```powershell
flutter analyze
flutter test
flutter build web
```

Untuk memeriksa sintaks skrip Python:

```powershell
python -m py_compile .\computer_vision\count_customers.py
```

Build web lokal menghasilkan file di `build/web`; perintah ini belum memublikasikan aplikasi ke hosting.

## Privasi dan keamanan

- Jangan unggah service-account JSON, private key, token, password, atau file `.env` berisi rahasia.
- Flutter client hanya boleh mendapat akses sesuai role dan Firestore Rules.
- Service account Python adalah kredensial server tepercaya; Admin SDK tidak dibatasi oleh Firestore client rules. Lindungi key dan berikan IAM minimal.
- Simpan agregat pengunjung saja; jangan menulis frame atau video mentah ke Firestore.
- Uji akses yang ditolak (pengguna tidak login/tidak punya role) sebelum menyatakan keamanan siap produksi.

## Status dan pekerjaan lanjutan

Yang telah dilaporkan berhasil diuji dalam lingkungan pengembangan: login admin, penerapan Firestore Rules, pengiriman CV ke Firestore, dashboard real-time saat CV dan browser berjalan bersamaan, halaman Riwayat dan Analitik, `flutter analyze`, tujuh tes Flutter, dan `flutter build web`.

Pekerjaan berikutnya tetap diperlukan sebelum produksi: uji keamanan menyeluruh, uji koneksi terputus/pemulihan, validasi nilai hitungan, kalibrasi arah kamera, pengujian lintas platform, dan dokumentasi deployment hosting.
