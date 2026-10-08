import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer_stats.dart';
import '../services/realtime_service.dart';
import '../widgets/customer_chart.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_item.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Stream<CustomerStats> _statsStream =
      RealtimeService().watchStats();

  static const _textDark = Color(0xFF152033);
  static const _muted = Color(0xFF657184);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Customer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textDark,
              ),
            ),
            Text(
              'Monitoring Minimarket',
              style: TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        actions: const [
          IconButton(
            onPressed: null,
            icon: Icon(Icons.notifications_none, color: _textDark),
          ),
        ],
      ),
      body: StreamBuilder<CustomerStats>(
        stream: _statsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Gagal mengambil data: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'Belum ada data pengunjung dari Firestore.',
                textAlign: TextAlign.center,
              ),
            );
          }

        return _DashboardContent(stats: snapshot.data!);
        },
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  final CustomerStats stats;

  const _DashboardContent({required this.stats});

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  // Firestore hanya mengirim event saat data berubah, jadi tanpa timer
  // status "data basi" tidak akan pernah muncul ketika ESP32 mati.
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  String _lastUpdateText(CustomerStats stats) {
    final updated = stats.lastUpdated;
    if (updated == null) return 'Tidak ada data';

    final diff = _now.difference(updated);
    if (diff.inSeconds < 60) return '${_formatTime(updated)} (baru saja)';
    if (diff.inMinutes < 60) {
      return '${_formatTime(updated)} (${diff.inMinutes} mnt lalu)';
    }
    if (diff.inHours < 24) {
      return '${_formatTime(updated)} (${diff.inHours} jam lalu)';
    }
    return '${updated.day}/${updated.month}/${updated.year} ${_formatTime(updated)}';
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final sensorActive = stats.isSensorActive(_now);
    final stale = stats.isStale(_now);
    final live = !stats.fromCache && sensorActive;
    final capacity = stats.maxCapacity;
    final capacityText = '${(stats.capacityPercentage * 100).round()}%';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF152033),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pemantauan kepadatan pengunjung secara real-time',
            style: TextStyle(color: Color(0xFF657184), fontSize: 14),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'MONITORING REAL-TIME',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: live ? Colors.greenAccent : Colors.redAccent,
                            size: 9,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            live ? 'LIVE' : (stale ? 'TERTUNDA' : 'OFFLINE'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pengunjung Saat Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stats.currentVisitors}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'orang',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: stats.capacityPercentage,
                    minHeight: 10,
                    backgroundColor: Colors.white30,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Kapasitas maksimal $capacity orang',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      capacityText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: stats.densityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${stats.densityStatus}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.login,
                  title: 'Masuk Hari Ini',
                  value: '${stats.totalEntry}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.logout,
                  title: 'Keluar Hari Ini',
                  value: '${stats.totalExit}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.groups,
                  title: 'Kapasitas',
                  value: '$capacity',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.sensors,
                  title: 'Sensor',
                  value: sensorActive ? 'Online' : 'Offline',
                  valueColor: sensorActive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tren Pengunjung',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Data pengunjung beberapa jam terakhir',
                  style: TextStyle(fontSize: 12, color: Color(0xFF657184)),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: CustomerChart(maxValue: capacity.toDouble()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Sistem',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                StatusItem(
                  label: 'Internet',
                  value: stats.fromCache ? 'Tidak terhubung' : 'Terhubung',
                  color: stats.fromCache ? Colors.red : Colors.green,
                ),
                StatusItem(
                  label: 'ESP32',
                  value: stale ? 'Tidak merespons' : 'Online',
                  color: stale ? Colors.red : Colors.green,
                ),
                StatusItem(
                  label: 'Sensor',
                  value: sensorActive ? 'Aktif' : 'Nonaktif',
                  color: sensorActive ? Colors.green : Colors.red,
                ),
                StatusItem(
                  label: 'Update terakhir',
                  value: _lastUpdateText(stats),
                  color: stale ? Colors.orange : Colors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
