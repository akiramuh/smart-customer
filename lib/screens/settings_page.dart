import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/visitor_command.dart';
import '../services/command_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.commandService});

  /// Disuntikkan pada test; bila null memakai [CommandService] bawaan.
  final CommandService? commandService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Nilai bawaan yang sama dengan argumen default script Computer Vision.
  static const int defaultMaxCapacity = 40;
  static const int defaultAlertThreshold = 5;

  static const _textDark = Color(0xFF152033);
  static const _muted = Color(0xFF657184);

  CommandService? _service;
  StreamSubscription<VisitorCommand?>? _subscription;

  int _maxCapacity = defaultMaxCapacity;
  int _alertThreshold = defaultAlertThreshold;
  bool _loading = true;
  bool _notificationsEnabled = true;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _service = widget.commandService ?? _createDefaultService();
    if (_service == null) {
      // Firebase belum siap (mis. pada test); tampilkan nilai bawaan saja.
      _loading = false;
      return;
    }
    _subscription = _service!
        .watchCommand(CommandService.defaultCameraId)
        .handleError((Object _) {
          if (mounted) setState(() => _loading = false);
        })
        .listen((command) {
          if (!mounted) return;
          setState(() {
            _maxCapacity = command?.maxCapacity ?? defaultMaxCapacity;
            _alertThreshold = command?.alertThreshold ?? defaultAlertThreshold;
            _loading = false;
          });
        });
  }

  CommandService? _createDefaultService() {
    try {
      return CommandService();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// True bila perintah boleh ditulis (layanan tersedia & data sudah termuat).
  bool get _canEdit => _service != null && !_loading;

  Future<void> _editCapacity() async {
    final value = await _showNumberDialog(
      title: 'Kapasitas Maksimum',
      label: 'Jumlah orang maksimum yang boleh berada di minimarket',
      initialValue: _maxCapacity,
    );
    if (value == null || !mounted) return;
    final service = _service;
    if (service == null) return;

    try {
      await service.setMaxCapacity(CommandService.defaultCameraId, value);
      if (!mounted) return;
      setState(() => _maxCapacity = value);
      _showSnack('Kapasitas maksimum diubah menjadi $value orang.');
    } catch (_) {
      _showSnack('Gagal menyimpan kapasitas maksimum.');
    }
  }

  Future<void> _editThreshold() async {
    final value = await _showNumberDialog(
      title: 'Ambang Notifikasi',
      label: 'Notifikasi dikirim saat jumlah pengunjung mencapai nilai ini',
      initialValue: _alertThreshold,
    );
    if (value == null || !mounted) return;

    try {
      await _service!.setAlertThreshold(CommandService.defaultCameraId, value);
      if (!mounted) return;
      setState(() => _alertThreshold = value);
      _showSnack('Ambang notifikasi diubah menjadi $value orang.');
    } catch (_) {
      _showSnack('Gagal menyimpan ambang notifikasi.');
    }
  }

  Future<void> _resetOccupancy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset jumlah pengunjung?'),
        content: const Text(
          'Jumlah orang di dalam minimarket akan disetel ulang menjadi 0.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service!.requestOccupancyReset(CommandService.defaultCameraId);
      _showSnack('Permintaan reset dikirim ke sensor.');
    } catch (_) {
      _showSnack('Gagal mengirim permintaan reset.');
    }
  }

  Future<void> _confirmAndSignOut() async {
    if (_signingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari aplikasi?'),
        content: const Text(
          'Anda harus login kembali untuk mengakses dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnack('Gagal keluar (${error.code}).');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Gagal keluar dari aplikasi.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<int?> _showNumberDialog({
    required String title,
    required String label,
    required int initialValue,
  }) {
    final controller = TextEditingController(text: '$initialValue');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Contoh: 40',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                final value = _parseValue(controller.text);
                if (value != null) Navigator.of(context).pop(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = _parseValue(controller.text);
              if (value != null) Navigator.of(context).pop(value);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  int? _parseValue(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 1) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('Profil Admin'),
            subtitle: Text('Administrator'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifikasi'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),
          ),

          const _SectionHeader('Ambang Batas'),
          ListTile(
            leading: const Icon(Icons.groups),
            title: const Text('Kapasitas Maksimum'),
            subtitle: const Text(
              'Batas jumlah orang di minimarket (dashboard)',
              style: TextStyle(color: _muted),
            ),
            trailing: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '$_maxCapacity orang',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
            onTap: _canEdit ? _editCapacity : null,
          ),
          ListTile(
            leading: const Icon(Icons.notification_important),
            title: const Text('Ambang Notifikasi'),
            subtitle: const Text(
              'Notifikasi dikirim saat pengunjung mencapai nilai ini',
              style: TextStyle(color: _muted),
            ),
            trailing: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '$_alertThreshold orang',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
            onTap: _canEdit ? _editThreshold : null,
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Reset Jumlah Pengunjung'),
            subtitle: const Text(
              'Setel ulang jumlah orang di dalam ke 0',
              style: TextStyle(color: _muted),
            ),
            onTap: _canEdit ? _resetOccupancy : null,
          ),

          const _SectionHeader('Perangkat'),
          const ListTile(
            leading: Icon(Icons.sensors),
            title: Text('Status Sensor'),
            subtitle: Text('ESP32 Online'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Tentang Aplikasi'),
            subtitle: Text('Smart Customer v1.0'),
          ),
          const _SectionHeader('Sesi'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Keluar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Keluar dari akun administrator'),
            trailing: _signingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _signingOut ? null : _confirmAndSignOut,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF657184),
        ),
      ),
    );
  }
}
