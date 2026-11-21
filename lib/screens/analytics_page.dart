import 'package:flutter/material.dart';

import '../models/customer_event.dart';
import '../services/api_service.dart';
import '../widgets/info_card.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  static final Stream<AnalyticsSummary> _summaryStream =
      ApiService().watchAnalyticsSummary();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analitik'),
            Text(
              'Ringkasan performa kunjungan',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<AnalyticsSummary>(
        stream: _summaryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _AnalyticsMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Analitik belum dapat dimuat',
              message:
                  'Periksa koneksi dan hak akses Firestore, lalu buka kembali halaman ini.',
            );
          }

          final summary = snapshot.data ??
              const AnalyticsSummary(
                averageVisitors: 'Belum ada data',
                busiestHour: 'Belum ada data',
                highestDensity: 'Belum ada data',
                lowestDensity: 'Belum ada data',
              );

          return LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth >= 900 ? 32.0 : 20.0;
              final columns = constraints.maxWidth >= 980 ? 4 : 2;
              final cardWidth =
                  (constraints.maxWidth - padding * 2 - 14 * (columns - 1)) /
                      columns;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1220),
                  child: ListView(
                    padding: EdgeInsets.all(padding),
                    children: [
                      const Text(
                        'Analitik Pengunjung',
                        style: TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gunakan ringkasan historis untuk memahami pola kunjungan minimarket.',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF175CD3),
                              size: 19,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Analitik dihitung dari snapshot historis pengunjung yang tersimpan di Firestore. Data transaksi POS belum termasuk dalam analisis.',
                                style: TextStyle(
                                  color: Color(0xFF1849A9),
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Ringkasan Utama',
                        style: TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: InfoCard(
                              title: 'Rata-rata Pengunjung',
                              value: summary.averageVisitors,
                              icon: Icons.people_alt_outlined,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: InfoCard(
                              title: 'Jam Paling Ramai',
                              value: summary.busiestHour,
                              icon: Icons.schedule_rounded,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: InfoCard(
                              title: 'Kepadatan Tertinggi',
                              value: summary.highestDensity,
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: InfoCard(
                              title: 'Kepadatan Terendah',
                              value: summary.lowestDensity,
                              icon: Icons.trending_down_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnalyticsMessage extends StatelessWidget {
  const _AnalyticsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF98A2B3), size: 46),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF172B4D),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
