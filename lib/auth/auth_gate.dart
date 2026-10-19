import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_page.dart';

/// Requires a signed-in Firebase Auth user and an administrator-provisioned
/// /users/{uid} document whose role is admin, operator, or viewer.
class AuthGate extends StatelessWidget {
  const AuthGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Memeriksa sesi login...');
        }

        if (authSnapshot.hasError) {
          return const _AccessMessage(
            title: 'Autentikasi tidak tersedia',
            message: 'Tidak dapat memeriksa sesi login. Periksa koneksi lalu coba lagi.',
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const LoginPage();

        return _RoleGate(user: user, child: child);
      },
    );
  }
}

class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.user, required this.child});

  final User user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final roleDocument = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: roleDocument,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Memverifikasi hak akses...');
        }

        if (snapshot.hasError) {
          return _AccessMessage(
            title: 'Tidak dapat memverifikasi akses',
            message: 'Periksa koneksi internet dan aturan Firestore. UID: ${user.uid}',
            showSignOut: true,
          );
        }

        final data = snapshot.data?.data();
        final role = data?['role'];
        const allowedRoles = {'admin', 'operator', 'viewer'};
        if (data == null || role is! String || !allowedRoles.contains(role)) {
          return _AccessMessage(
            title: 'Akun belum diberi akses',
            message: 'Minta administrator menambahkan dokumen users/${user.uid} '
                'dengan field role bernilai admin, operator, atau viewer.',
            showSignOut: true,
          );
        }

        return child;
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({
    required this.title,
    required this.message,
    this.showSignOut = false,
  });

  final String title;
  final String message;
  final bool showSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                SelectableText(message, textAlign: TextAlign.center),
                if (showSignOut) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Keluar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
