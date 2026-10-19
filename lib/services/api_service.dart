import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_event.dart';

/// Reads historical visitor snapshots produced by the Python CV process.
///
/// Current operational state is stored at `visitor_activity/current_<cameraId>`;
/// this service excludes those live-state documents and reads snapshot documents
/// from the same collection. Legacy activity documents without `isSnapshot`
/// are accepted for backwards compatibility.
class ApiService {
  ApiService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('visitor_activity');

  static const int _maxRecords = 500;

  Stream<List<_HistoryRecord>> _watchRecords() {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(_maxRecords)
        .snapshots()
        .map((snapshot) {
      final records = <_HistoryRecord>[];

      for (final doc in snapshot.docs) {
        // The mutable current document is used by the live dashboard, not history.
        if (doc.id.startsWith('current_')) continue;

        final data = doc.data();
        // New snapshots explicitly set isSnapshot=true. Accept old documents
        // without this field so existing history is not silently discarded.
        if (data['isSnapshot'] == false) continue;

        final timestamp = _readTime(data['timestamp']);
        if (timestamp == null) continue;

        final visitors = _readInt(data['jumlahDiDalam']).clamp(0, 1000000).toInt();
        final capacity = _readInt(data['maxCapacity']);
        final safeCapacity = capacity > 0 ? capacity : 40;
        final declaredStatus = data['densityStatus'];

        records.add(
          _HistoryRecord(
            timestamp: timestamp.toLocal(),
            customersInside: visitors,
            maxCapacity: safeCapacity,
            densityStatus: declaredStatus is String && declaredStatus.isNotEmpty
                ? declaredStatus
                : _densityStatus(visitors, safeCapacity),
          ),
        );
      }

      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    });
  }

  /// A reactive list of real historical readings for the History page.
  Stream<List<CustomerEvent>> watchHistory() {
    return _watchRecords().map((records) {
      return records
          .map(
            (record) => CustomerEvent(
              time: _formatHistoryTime(record.timestamp),
              customersInside: record.customersInside,
              densityStatus: record.densityStatus,
            ),
          )
          .toList(growable: false);
    });
  }

  /// A reactive summary computed from the same historical readings.
  Stream<AnalyticsSummary> watchAnalyticsSummary() {
    return _watchRecords().map(_summarize);
  }

  // Kept as Future methods for compatibility with any existing callers.
  Future<List<CustomerEvent>> fetchHistory() => watchHistory().first;

  Future<AnalyticsSummary> fetchAnalyticsSummary() =>
      watchAnalyticsSummary().first;

  static DateTime? _readTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _readInt(Object? value) {
    if (value is num && value.isFinite) return value.toInt();
    return 0;
  }

  static String _densityStatus(int visitors, int capacity) {
    final ratio = visitors / capacity;
    if (ratio < 0.10) return 'SEPI';
    if (ratio < 0.50) return 'NORMAL';
    if (ratio < 0.80) return 'RAMAI';
    return 'SANGAT RAMAI';
  }

  static String _formatHistoryTime(DateTime timestamp) {
    String two(int value) => value.toString().padLeft(2, '0');
    final now = DateTime.now();
    final time = '${two(timestamp.hour)}:${two(timestamp.minute)}';
    if (timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day) {
      return time;
    }
    return '${two(timestamp.day)}/${two(timestamp.month)} $time';
  }

  static AnalyticsSummary _summarize(List<_HistoryRecord> records) {
    if (records.isEmpty) {
      return const AnalyticsSummary(
        averageVisitors: 'Belum ada data',
        busiestHour: 'Belum ada data',
        highestDensity: 'Belum ada data',
        lowestDensity: 'Belum ada data',
      );
    }

    final total = records.fold<int>(
      0,
      (runningTotal, record) => runningTotal + record.customersInside,
    );
    final average = (total / records.length).round();
    final highest = records
        .map((record) => record.customersInside)
        .reduce((a, b) => a > b ? a : b);
    final lowest = records
        .map((record) => record.customersInside)
        .reduce((a, b) => a < b ? a : b);

    // Determine the busiest hour by average occupancy for each hour-of-day,
    // rather than selecting the hour of a single possibly noisy sample.
    final valuesByHour = <int, List<int>>{};
    for (final record in records) {
      valuesByHour.putIfAbsent(record.timestamp.hour, () => <int>[]).add(
            record.customersInside,
          );
    }

    var busiestHour = valuesByHour.keys.first;
    var busiestAverage = -1.0;
    for (final entry in valuesByHour.entries) {
      final hourAverage =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (hourAverage > busiestAverage) {
        busiestAverage = hourAverage;
        busiestHour = entry.key;
      }
    }

    String two(int value) => value.toString().padLeft(2, '0');
    final nextHour = (busiestHour + 1) % 24;

    return AnalyticsSummary(
      averageVisitors: '$average orang',
      busiestHour: '${two(busiestHour)}:00 - ${two(nextHour)}:00',
      highestDensity: '$highest orang',
      lowestDensity: '$lowest orang',
    );
  }
}

class _HistoryRecord {
  const _HistoryRecord({
    required this.timestamp,
    required this.customersInside,
    required this.maxCapacity,
    required this.densityStatus,
  });

  final DateTime timestamp;
  final int customersInside;
  final int maxCapacity;
  final String densityStatus;
}
