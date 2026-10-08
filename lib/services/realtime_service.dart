
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_stats.dart';

class RealtimeService {
  RealtimeService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('visitor_activity');

  static DateTime? _readTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // Mengambil statistik pengunjung terbaru dari Firestore.
  Stream<CustomerStats> watchStats() {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return CustomerStats(
          currentVisitors: 0,
          totalEntry: 0,
          totalExit: 0,
          sensorOnline: false,
          fromCache: snapshot.metadata.isFromCache,
        );
      }

      final data = snapshot.docs.first.data();

      int readInt(String field) {
        final value = data[field];
        if (value is num) return value.toInt();
        return 0;
      }

      return CustomerStats(
        currentVisitors: readInt('jumlahDiDalam'),
        totalEntry: readInt('totalMasuk'),
        totalExit: readInt('totalKeluar'),
        maxCapacity: readInt('maxCapacity') > 0
            ? readInt('maxCapacity')
            : 40,
        sensorOnline: data['sensorOnline'] == true,
        lastUpdated: _readTime(data['timestamp']),
        fromCache: snapshot.metadata.isFromCache,
      );
    });
  }

  // Mengambil riwayat jumlah pengunjung untuk grafik.
  Stream<List<double>> watchChartValues() {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(24)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.toList().reversed;

      return docs.map((doc) {
        final data = doc.data();
        final value = data['jumlahDiDalam'];

        if (value is num) {
          return value.toDouble();
        }

        return 0.0;
      }).toList();
    });
  }
}
