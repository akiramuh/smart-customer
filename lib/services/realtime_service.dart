import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_stats.dart';

class RealtimeService {
  RealtimeService({
    FirebaseFirestore? firestore,
    this.cameraId = 'minimarket-main',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String cameraId;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('visitor_activity');

  DocumentReference<Map<String, dynamic>> get _currentDocument =>
      _collection.doc('current_$cameraId');

  static DateTime? _readTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Membaca dokumen kondisi terkini, bukan snapshot historis terbaru.
  Stream<CustomerStats> watchStats() {
    return _currentDocument
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return CustomerStats(
          currentVisitors: 0,
          totalEntry: 0,
          totalExit: 0,
          cameraCvOnline: false,
          fromCache: snapshot.metadata.isFromCache,
        );
      }

      int readInt(String field) {
        final value = data[field];
        if (value is num) return value.toInt();
        return 0;
      }

      // Field cameraCvOnline adalah nama baru. sensorOnline dibaca
      // sebagai fallback untuk dokumen lama yang belum diperbarui.
      final cameraStatus = data.containsKey('cameraCvOnline')
          ? data['cameraCvOnline'] == true
          : data['sensorOnline'] == true;

      return CustomerStats(
        currentVisitors: readInt('jumlahDiDalam'),
        totalEntry: readInt('totalMasuk'),
        totalExit: readInt('totalKeluar'),
        maxCapacity:
            readInt('maxCapacity') > 0 ? readInt('maxCapacity') : 40,
        cameraCvOnline: cameraStatus,
        lastUpdated: _readTime(data['timestamp']),
        fromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  /// Mengambil snapshot historis untuk grafik dan tidak memasukkan
  /// dokumen current_* yang dapat berubah setiap heartbeat.
  Stream<List<double>> watchChartValues() {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final history = snapshot.docs.where((doc) {
        final data = doc.data();
        return !doc.id.startsWith('current_') &&
            data['isSnapshot'] != false;
      }).toList()
        ..sort((a, b) {
          final aTime = _readTime(a.data()['timestamp']);
          final bTime = _readTime(b.data()['timestamp']);
          if (aTime == null || bTime == null) return 0;
          return aTime.compareTo(bTime);
        });

      final recent = history.length > 24
          ? history.sublist(history.length - 24)
          : history;

      return recent.map((doc) {
        final value = doc.data()['jumlahDiDalam'];
        return value is num ? value.toDouble() : 0.0;
      }).toList();
    });
  }
}
