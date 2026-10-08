import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_customer_flutter/models/customer_stats.dart';
import 'package:smart_customer_flutter/screens/settings_page.dart';

void main() {
  group('CustomerStats', () {
    test('densityStatus sesuai jumlah pengunjung', () {
      CustomerStats s(int n) => CustomerStats(
            currentVisitors: n,
            totalEntry: 0,
            totalExit: 0,
          );

      expect(s(0).densityStatus, 'SEPI');
      expect(s(10).densityStatus, 'SEPI');
      expect(s(11).densityStatus, 'NORMAL');
      expect(s(25).densityStatus, 'NORMAL');
      expect(s(26).densityStatus, 'RAMAI');
      expect(s(35).densityStatus, 'RAMAI');
      expect(s(36).densityStatus, 'SANGAT RAMAI');
    });

    test('capacityPercentage dibatasi 0..1', () {
      const over = CustomerStats(
        currentVisitors: 80,
        totalEntry: 0,
        totalExit: 0,
        maxCapacity: 40,
      );
      expect(over.capacityPercentage, 1.0);
    });
  });

  group('CustomerStats data basi', () {
    final now = DateTime(2026, 10, 14, 10, 0, 0);

    CustomerStats stats({DateTime? updated, bool online = true}) =>
        CustomerStats(
          currentVisitors: 5,
          totalEntry: 10,
          totalExit: 5,
          sensorOnline: online,
          lastUpdated: updated,
        );

    test('tanpa timestamp dianggap basi', () {
      expect(stats().isStale(now), isTrue);
      expect(stats().isSensorActive(now), isFalse);
    });

    test('data baru dianggap aktif', () {
      final s = stats(updated: now.subtract(const Duration(seconds: 30)));
      expect(s.isStale(now), isFalse);
      expect(s.isSensorActive(now), isTrue);
    });

    test('data lebih lama dari batas dianggap basi', () {
      final s = stats(updated: now.subtract(const Duration(minutes: 6)));
      expect(s.isStale(now), isTrue);
      expect(s.isSensorActive(now), isFalse);
    });

    test('sensorOnline=false tetap nonaktif walau data baru', () {
      final s = stats(updated: now, online: false);
      expect(s.isSensorActive(now), isFalse);
    });
  });

  testWidgets('SettingsPage menampilkan judul', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Profil Admin'), findsOneWidget);
  });
}
