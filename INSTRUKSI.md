# Integrasi notifikasi Smart Customer (Android + Computer Vision)

Paket ini berisi tiga file untuk ditimpa di root repo `smart_customer_flutter`:

- `lib/main.dart`
- `lib/services/notification_service.dart`
- `computer_vision/count_customers.py`

## Cara menerapkan

1. Salin cadangan file lama di luar repo bila perlu.
2. Ekstrak ZIP ini tepat ke root repo `smart_customer_flutter`, pilih replace/overwrite untuk tiga file tersebut.
3. Pastikan `firebase-admin` terinstal dalam virtualenv Computer Vision (sudah tercantum di `computer_vision/requirements.txt`).
4. Jalankan `flutter pub get`, `flutter analyze`, dan `flutter test`.
5. Jalankan aplikasi Android dan izinkan notifikasi. Log aplikasi harus menampilkan `Berhasil subscribe FCM topic: smart_customer_alerts`.
6. Jalankan Computer Vision dari PowerShell dengan akun service Firebase yang disimpan di luar repo:

```powershell
python .\computer_vision\count_customers.py `
  --credentials "$HOME\firebase-keys\smart-customer-ecc66-service-account.json" `
  --project-id "smart-customer-ecc66" `
  --camera-id "minimarket-main" `
  --alert-threshold 5 `
  --publish-seconds 15 `
  --snapshot-seconds 60 `
  --preview
```

`--preview` menampilkan video YOLO untuk demo. Jika tidak ingin preview, hapus argumen tersebut. Ambang notifikasi terpisah dari `--max-capacity`: `--alert-threshold 5` memicu pemberitahuan, sedangkan `--max-capacity` mengatur kapasitas yang ditulis ke dashboard.

## Cara kerja

- Script Python mengirim notifikasi FCM saat occupancy terhitung bergerak dari bawah ambang ke 5 atau lebih.
- Pesan dikirim ke topic `smart_customer_alerts`; Android app yang telah diberi izin otomatis subscribe ke topic tersebut.
- Saat aplikasi Android berada di foreground, listener `onMessage` menampilkan local notification. Saat di background, notification payload ditampilkan oleh Android/FCM.
- Notifikasi tidak diulang terus-menerus ketika jumlah tetap 5 atau lebih. Jika jumlah turun di bawah ambang lalu naik menembusnya lagi, alert dapat dikirim lagi.
- Bila FCM gagal dikirim, script mencetak pesan error dan mencoba ulang dengan jeda sekitar 10 detik selama jumlah masih di atas ambang.
- Jika script dimulai ketika occupancy yang tersimpan sudah 5 atau lebih, alert tidak otomatis dikirim hanya karena startup; trigger akan terjadi setelah jumlah turun di bawah 5 lalu menembus ambang kembali.

## Syarat & batasan

- HP harus menjalankan build Android dari Firebase project `smart-customer-ecc66`, memiliki koneksi internet dan izin notifikasi aktif.
- Python Firebase Admin SDK memerlukan credential service-account yang sah dengan izin mengirim Firebase Cloud Messaging. File itu tetap di luar repo dan tidak boleh di-commit.
- FCM topic nyaman untuk demo tim, tetapi siapa pun yang memiliki build aplikasi dapat mencoba subscribe ke nama topic. Untuk production, gunakan mekanisme otorisasi dan pengiriman ke token perangkat terdaftar.
- Akurasi jumlah orang mengikuti logika YOLO crossing-line saat ini; integrasi ini tidak meningkatkan akurasi penghitungannya.
