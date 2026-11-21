import 'package:flutter/material.dart';

class CustomerStats {
  final int currentVisitors;
  final int totalEntry;
  final int totalExit;
  final int maxCapacity;

  /// Status gabungan kamera dan proses Computer Vision.
  final bool cameraCvOnline;

  /// Waktu terakhir data dipublikasikan ke Firestore.
  final DateTime? lastUpdated;

  /// True ketika snapshot dibaca dari cache lokal.
  final bool fromCache;

  /// Heartbeat Python adalah 15 detik; data dianggap basi setelah 60 detik.
  static const Duration staleAfter = Duration(seconds: 60);

  const CustomerStats({
    required this.currentVisitors,
    required this.totalEntry,
    required this.totalExit,
    this.maxCapacity = 40,
    bool? cameraCvOnline,
    bool? sensorOnline,
    this.lastUpdated,
    this.fromCache = false,
  }) : cameraCvOnline = cameraCvOnline ?? sensorOnline ?? false;

  bool isStale(DateTime now) {
    final updated = lastUpdated;
    if (updated == null) return true;
    return now.difference(updated) > staleAfter;
  }

  bool isCameraCvOnline(DateTime now) {
    return cameraCvOnline && !isStale(now);
  }

  @Deprecated('Gunakan cameraCvOnline')
  bool get sensorOnline => cameraCvOnline;

  @Deprecated('Gunakan isCameraCvOnline')
  bool isSensorActive(DateTime now) => isCameraCvOnline(now);

  String get densityStatus {
    if (currentVisitors <= 1) return 'SEPI';
    if (currentVisitors <= 3) return 'NORMAL';
    return 'RAMAI';
  }

  Color get densityColor {
    switch (densityStatus) {
      case 'SEPI':
        return const Color(0xFF15803D);
      case 'NORMAL':
        return const Color(0xFF175CD3);
      case 'RAMAI':
        return const Color(0xFFB54708);
      default:
        return const Color(0xFFB42318);
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
    bool? cameraCvOnline,
    bool? sensorOnline,
    DateTime? lastUpdated,
    bool? fromCache,
  }) {
    return CustomerStats(
      currentVisitors: currentVisitors ?? this.currentVisitors,
      totalEntry: totalEntry ?? this.totalEntry,
      totalExit: totalExit ?? this.totalExit,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      cameraCvOnline:
          cameraCvOnline ?? sensorOnline ?? this.cameraCvOnline,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}
