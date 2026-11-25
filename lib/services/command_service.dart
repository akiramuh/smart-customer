import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/visitor_command.dart';

/// Baca/tulis perintah aplikasi pada koleksi `visitor_commands`.
///
/// Satu dokumen per cameraId. Proses Computer Vision (Python) membaca dokumen
/// yang sama dan menerapkan perintahnya, sehingga aplikasi tidak menulis
/// langsung ke `visitor_activity`/`visitor_state`.
class CommandService {
  CommandService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String defaultCameraId = 'minimarket-main';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('visitor_commands');

  DocumentReference<Map<String, dynamic>> _doc(String cameraId) =>
      _collection.doc(cameraId);

  /// Perintah saat ini untuk kamera tertentu.
  ///
  /// Mengembalikan null bila dokumen belum pernah dibuat.
  Future<VisitorCommand?> fetchCommand(String cameraId) async {
    final snapshot = await _doc(cameraId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return VisitorCommand.fromMap(data);
  }

  /// Aliran perubahan perintah, dipakai untuk mencerminkan perubahan dari
  /// perangkat lain.
  Stream<VisitorCommand?> watchCommand(String cameraId) {
    return _doc(cameraId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return VisitorCommand.fromMap(data);
    });
  }

  /// Mengubah ambang batas kapasitas yang tampil di dashboard.
  Future<void> setMaxCapacity(String cameraId, int maxCapacity) async {
    await _doc(cameraId).set(
      <String, dynamic>{
        'maxCapacity': maxCapacity,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Mengubah ambang notifikasi FCM.
  Future<void> setAlertThreshold(String cameraId, int threshold) async {
    await _doc(cameraId).set(
      <String, dynamic>{
        'alertThreshold': threshold,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Meminta proses Computer Vision mereset jumlah orang di dalam ke 0.
  ///
  /// Perintah ditandai dengan timestamp baru agar proses mengenalinya sebagai
  /// perintah baru, bukan perintah yang sudah pernah diterapkan.
  Future<void> requestOccupancyReset(String cameraId) async {
    await _doc(cameraId).set(
      <String, dynamic>{
        'resetOccupancyAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
