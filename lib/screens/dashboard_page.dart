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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Customer',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Monitoring Minimarket',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF175CD3),
                size: 20,
              ),
            ),
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
            if (snapshot.data != null) {
              return _DashboardContent(
                stats: snapshot.data!,
                connectionError: true,
              );
            }
            return const _DashboardMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Data tidak dapat dimuat',
              message:
                  'Periksa koneksi internet, izin Firestore, lalu coba kembali.',
            );
          }

          if (!snapshot.hasData) {
            return const _DashboardMessage(
              icon: Icons.hourglass_empty_rounded,
              title: 'Menunggu data pengunjung',
              message:
                  'Data akan muncul setelah program Computer Vision mulai mengirimkan pembaruan.',
            );
          }

          return _DashboardContent(stats: snapshot.data!);
        },
      ),
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({
    required this.stats,
    this.connectionError = false,
  });

  final CustomerStats stats;
  final bool connectionError;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  String _lastUpdateText(CustomerStats stats) {
    final updated = stats.lastUpdated;
    if (updated == null) return 'Belum pernah diperbarui';

    final difference = _now.difference(updated);
    if (difference.isNegative || difference.inSeconds < 60) {
      return '${_formatTime(updated)} (baru saja)';
    }
    if (difference.inMinutes < 60) {
      return '${_formatTime(updated)} (${difference.inMinutes} menit lalu)';
    }
    if (difference.inHours < 24) {
      return '${_formatTime(updated)} (${difference.inHours} jam lalu)';
    }
    return '${updated.day}/${updated.month}/${updated.year} ${_formatTime(updated)}';
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final stale = stats.isStale(_now);
    final cameraCvOnline = stats.isCameraCvOnline(_now);
    final capacity = stats.maxCapacity;
    final live = !widget.connectionError &&
        !stats.fromCache &&
        cameraCvOnline;

    final connectionStatus = widget.connectionError
        ? 'Error'
        : stats.fromCache
            ? 'Cache'
            : 'Live';
    final connectionColor = widget.connectionError
        ? const Color(0xFFB42318)
        : stats.fromCache
            ? const Color(0xFFB54708)
            : const Color(0xFF15803D);

    final cameraCvStatus = stats.lastUpdated == null
        ? 'Belum ada data'
        : cameraCvOnline
            ? 'Online'
            : 'Offline';
    final cameraCvColor = stats.lastUpdated == null
        ? const Color(0xFF667085)
        : cameraCvOnline
            ? const Color(0xFF15803D)
            : const Color(0xFFB42318);

    final dashboardStatus = widget.connectionError
        ? 'ERROR DATA'
        : stats.fromCache
            ? 'CACHE'
            : stats.lastUpdated == null
                ? 'MENUNGGU DATA'
                : cameraCvOnline
                    ? 'LIVE'
                    : 'CV OFFLINE';

    final dashboardStatusColor = live
        ? const Color(0xFF86EFAC)
        : stats.fromCache
            ? const Color(0xFFFCD34D)
            : const Color(0xFFFCA5A5);

    final updateColor = stats.lastUpdated == null
        ? const Color(0xFF667085)
        : stale
            ? const Color(0xFFB54708)
            : const Color(0xFF175CD3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 1000
            ? 32.0
            : constraints.maxWidth >= 600
                ? 24.0
                : 16.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                32,
              ),
              children: [
                const _PageHeading(
                  title: 'Dashboard',
                  subtitle:
                      'Pantau kondisi dan pergerakan pengunjung minimarket.',
                ),
                const SizedBox(height: 22),
                _OccupancyCard(
                  stats: stats,
                  status: dashboardStatus,
                  statusColor: dashboardStatusColor,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, metricConstraints) {
                    final columns =
                        metricConstraints.maxWidth >= 740 ? 3 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: columns == 3 ? 1.75 : 1.5,
                      children: [
                        StatCard(
                          icon: Icons.login_rounded,
                          title: 'Masuk Hari Ini',
                          value: '${stats.totalEntry}',
                          iconColor: const Color(0xFF175CD3),
                        ),
                        StatCard(
                          icon: Icons.logout_rounded,
                          title: 'Keluar Hari Ini',
                          value: '${stats.totalExit}',
                          iconColor: const Color(0xFF0E9384),
                        ),
                        StatCard(
                          icon: Icons.groups_2_rounded,
                          title: 'Kapasitas Maksimal',
                          value: '$capacity orang',
                          iconColor: const Color(0xFF7A5AF8),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const _SectionHeading(
                  title: 'Tren Pengunjung',
                  subtitle: 'Perubahan jumlah pengunjung dari snapshot historis.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  decoration: _panelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Jumlah pengunjung',
                              style: TextStyle(
                                color: Color(0xFF344054),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '24 data terakhir',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 190,
                        child: CustomerChart(
                          maxValue: capacity > 0 ? capacity.toDouble() : 40,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeading(
                  title: 'Status Sistem',
                  subtitle: 'Kondisi koneksi data dan proses pemantauan.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _panelDecoration(),
                  child: Column(
                    children: [
                      StatusItem(
                        label: 'Koneksi Data',
                        value: connectionStatus,
                        color: connectionColor,
                      ),
                      const Divider(height: 18),
                      StatusItem(
                        label: 'Kamera & Computer Vision',
                        value: cameraCvStatus,
                        color: cameraCvColor,
                      ),
                      const Divider(height: 18),
                      StatusItem(
                        label: 'Update Terakhir',
                        value: _lastUpdateText(stats),
                        color: updateColor,
                      ),
                    ],
                  ),
                ),
                if (widget.connectionError) ...[
                  const SizedBox(height: 12),
                  const _InlineNotice(
                    icon: Icons.info_outline,
                    message:
                        'Koneksi ke Firestore mengalami gangguan. Informasi yang terlihat mungkin merupakan data terakhir yang berhasil diterima.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({
    required this.stats,
    required this.status,
    required this.statusColor,
  });

  final CustomerStats stats;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1849A9), Color(0xFF175CD3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF175CD3).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PENGUNJUNG DI DALAM TOKO',
                style: TextStyle(
                  color: Color(0xFFD1E0FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${stats.currentVisitors}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          height: 0.95,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 10, bottom: 7),
                    child: Text(
                      'orang',
                      style: TextStyle(
                        color: Color(0xFFD1E0FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: stats.densityColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Kepadatan: ${stats.densityStatus}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );

          final capacity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Status pemantauan',
                    style: TextStyle(
                      color: Color(0xFFD1E0FF),
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Penggunaan kapasitas',
                style: TextStyle(
                  color: Color(0xFFD1E0FF),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: stats.capacityPercentage,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(stats.capacityPercentage * 100).round()}% terisi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Kapasitas ${stats.maxCapacity}',
                    style: const TextStyle(
                      color: Color(0xFFD1E0FF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          );

          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(flex: 5, child: details),
                const SizedBox(width: 32),
                Expanded(flex: 4, child: capacity),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 24),
              capacity,
            ],
          );
        },
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF172B4D),
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF172B4D),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
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
              Icon(icon, size: 48, color: const Color(0xFF98A2B3)),
              const SizedBox(height: 16),
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEDF89)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFB54708), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF93370D),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE7ECF3)),
  );
}
