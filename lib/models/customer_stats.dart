import 'package:flutter/material.dart';

class CustomerStats {
  final int currentVisitors;
  final int totalEntry;
  final int totalExit;
  final int maxCapacity;
  final bool sensorOnline;

  /// Waktu dokumen terakhir ditulis (dari field `timestamp`), null jika tidak ada.
  final DateTime? lastUpdated;

  /// True jika data berasal dari cache lokal (tidak terhubung ke server).
  final bool fromCache;

  /// Batas data dianggap basi: jika lebih lama dari ini, sensor dianggap mati.
  static const Duration staleAfter = Duration(minutes: 5);

  const CustomerStats({
    required this.currentVisitors,
    required this.totalEntry,
    required this.totalExit,
    this.maxCapacity = 40,
    this.sensorOnline = true,
    this.lastUpdated,
    this.fromCache = false,
  });

  /// Data dianggap basi jika tidak ada timestamp atau sudah terlalu lama.
  bool isStale(DateTime now) {
    final updated = lastUpdated;
    if (updated == null) return true;
    return now.difference(updated) > staleAfter;
  }

  /// Sensor benar-benar aktif: dilaporkan online DAN datanya masih baru.
  bool isSensorActive(DateTime now) => sensorOnline && !isStale(now);

  String get densityStatus {
    if (currentVisitors <= 10) return 'SEPI';
    if (currentVisitors <= 25) return 'NORMAL';
    if (currentVisitors <= 35) return 'RAMAI';
    return 'SANGAT RAMAI';
  }

  Color get densityColor {
    switch (densityStatus) {
      case 'SEPI':
        return Colors.green;
      case 'NORMAL':
        return Colors.blue;
      case 'RAMAI':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  double get capacityPercentage {
    if (maxCapacity <= 0) return 0;
    return (currentVisitors / maxCapacity).clamp(0.0, 1.0);
  }

  CustomerStats copyWith({
    int? currentVisitors,
    int? totalEntry,
    int? totalExit,
    int? maxCapacity,
    bool? sensorOnline,
    DateTime? lastUpdated,
    bool? fromCache,
  }) {
    return CustomerStats(
      currentVisitors: currentVisitors ?? this.currentVisitors,
      totalEntry: totalEntry ?? this.totalEntry,
      totalExit: totalExit ?? this.totalExit,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      sensorOnline: sensorOnline ?? this.sensorOnline,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}
