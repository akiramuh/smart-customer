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
        return Colors.green;
      case 'RAMAI':
        return Colors.orange;
      case 'SANGAT RAMAI':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CustomerEvent>>(
        stream: _historyStream,
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
                  'Gagal memuat riwayat dari Firestore. Periksa koneksi dan izin akses.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final history = snapshot.data ?? const <CustomerEvent>[];
          if (history.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada snapshot riwayat. Data akan muncul setelah Computer Vision menyimpan snapshot berikutnya.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final event = history[index];
              final statusColor = _statusColor(event.densityStatus);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.people, color: Color(0xFF1565C0)),
                  ),
                  title: Text(
                    '${event.customersInside} orang',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Waktu: ${event.time}'),
                  trailing: Text(
                    event.densityStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
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
