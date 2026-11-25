import 'package:cloud_firestore/cloud_firestore.dart';

/// Perintah yang dikirim aplikasi Flutter ke proses Computer Vision.
///
/// Dokumen ini hidup di koleksi `visitor_commands` dengan id = cameraId.
/// Proses Python membacanya secara berkala dan menerapkannya ke state RAM-nya,
/// sehingga perubahan yang dilakukan di aplikasi tidak tertimpa pada publish
/// berikutnya.
class VisitorCommand {
  /// Kapasitas toko yang diinginkan (ditampilkan di dashboard).
  final int? maxCapacity;

  /// Ambang notifikasi FCM ketika occupancy mencapai nilai ini.
  final int? alertThreshold;

  /// Timestamp (epoch milliseconds) dari perintah reset occupancy terakhir.
  ///
  /// Nilainya berubah setiap kali pengguna menekan tombol reset. Proses Python
  /// membandingkan nilai ini dengan yang terakhirSeen; bila berbeda, occupancy
  /// di-reset ke 0.
  final int? resetOccupancyAt;

  /// Waktu dokumen terakhir diperbarui (server timestamp), null jika belum ada.
  final DateTime? updatedAt;

  const VisitorCommand({
    this.maxCapacity,
    this.alertThreshold,
    this.resetOccupancyAt,
    this.updatedAt,
  });

  factory VisitorCommand.fromMap(Map<String, dynamic> data) {
    return VisitorCommand(
      maxCapacity: _readInt(data['maxCapacity']),
      alertThreshold: _readInt(data['alertThreshold']),
      resetOccupancyAt: _readInt(data['resetOccupancyAt']),
      updatedAt: _readTime(data['updatedAt']),
    );
  }

  static int? _readInt(Object? value) {
    if (value is num && value.isFinite) return value.toInt();
    return null;
  }

  static DateTime? _readTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  VisitorCommand copyWith({
    int? maxCapacity,
    int? alertThreshold,
    int? resetOccupancyAt,
  }) {
    return VisitorCommand(
      maxCapacity: maxCapacity ?? this.maxCapacity,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      resetOccupancyAt: resetOccupancyAt ?? this.resetOccupancyAt,
      updatedAt: updatedAt,
    );
  }

  /// Identitas perintah reset: nilai berbeda berarti perintah baru.
  ///
  /// `null` berarti belum ada perintah reset, dan dianggap sama dengan
  /// apa pun yang belum pernah ada.
  int get resetKey => resetOccupancyAt ?? 0;

  @override
  bool operator ==(Object other) {
    return other is VisitorCommand &&
        other.maxCapacity == maxCapacity &&
        other.alertThreshold == alertThreshold &&
        other.resetOccupancyAt == resetOccupancyAt;
  }

  @override
  int get hashCode =>
      Object.hash(maxCapacity, alertThreshold, resetOccupancyAt);
}
