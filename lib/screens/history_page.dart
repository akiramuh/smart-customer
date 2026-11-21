import 'package:flutter/material.dart';

import '../models/customer_event.dart';
import '../services/api_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  static final Stream<List<CustomerEvent>> _historyStream =
      ApiService().watchHistory();

  Color _statusColor(String status) {
    switch (status) {
      case 'SEPI':
        return const Color(0xFF15803D);
      case 'RAMAI':
        return const Color(0xFFB54708);
      case 'SANGAT RAMAI':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF175CD3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riwayat'),
            Text(
              'Catatan aktivitas pengunjung',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<CustomerEvent>>(
        stream: _historyStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const _HistoryMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Riwayat belum dapat dimuat',
              message:
                  'Periksa koneksi dan izin akses Firestore, kemudian coba kembali.',
            );
          }

          final history = snapshot.data ?? const <CustomerEvent>[];
          if (history.isEmpty) {
            return const _HistoryMessage(
              icon: Icons.history_rounded,
              title: 'Belum ada riwayat',
              message:
                  'Catatan akan muncul setelah program Computer Vision menyimpan snapshot historis.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth >= 900 ? 32.0 : 18.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: EdgeInsets.all(padding),
                    children: [
                      const Text(
                        'Riwayat Pengunjung',
                        style: TextStyle(
                          color: Color(0xFF172B4D),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${history.length} catatan snapshot tersedia',
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...history.asMap().entries.map((entry) {
                        final index = entry.key;
                        final event = entry.value;
                        final statusColor = _statusColor(event.densityStatus);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE7ECF3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF4FF),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: const Icon(
                                  Icons.groups_2_rounded,
                                  color: Color(0xFF175CD3),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${event.customersInside} pengunjung',
                                      style: const TextStyle(
                                        color: Color(0xFF172B4D),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      event.time,
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  event.densityStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
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
