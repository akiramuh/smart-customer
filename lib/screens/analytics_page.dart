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
        title: const Text('Analitik'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<AnalyticsSummary>(
        stream: _summaryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat analitik dari Firestore. Periksa koneksi dan izin akses.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final summary = snapshot.data ??
              const AnalyticsSummary(
                averageVisitors: 'Belum ada data',
                busiestHour: 'Belum ada data',
                highestDensity: 'Belum ada data',
                lowestDensity: 'Belum ada data',
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Analitik Pengunjung',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ringkasan berdasarkan snapshot historis dari Firestore',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              InfoCard(
                title: 'Rata-rata Pengunjung',
                value: summary.averageVisitors,
                icon: Icons.people,
              ),
              InfoCard(
                title: 'Jam Paling Ramai',
                value: summary.busiestHour,
                icon: Icons.access_time,
              ),
              InfoCard(
                title: 'Kepadatan Tertinggi',
                value: summary.highestDensity,
                icon: Icons.trending_up,
              ),
              InfoCard(
                title: 'Kepadatan Terendah',
                value: summary.lowestDensity,
                icon: Icons.trending_down,
              ),
            ],
          );
        },
      ),
    );
  }
}
