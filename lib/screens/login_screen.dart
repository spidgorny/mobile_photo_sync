import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'folder_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final SettingsService _settings;
  late final AuthService _auth;

  AuthState _authState = const AuthState(email: null, isLoggedIn: false);
  bool _busy = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _auth = AuthService(_settings);
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await _auth.getState();
    setState(() => _authState = state);
    if (state.isLoggedIn) {
      _navigateToFolderScreen();
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() => _runBusy(() async {
        final apiBaseUrl = await _settings.apiBaseUrl;
        if (apiBaseUrl == null) {
          await _openSettings();
          if (await _settings.apiBaseUrl == null) return;
        }
        final state = await _auth.signInWithGoogle();
        setState(() {
          _authState = state;
          _status = 'Signed in as ${state.email}';
        });
        _navigateToFolderScreen();
      });

  Future<void> _logout() => _runBusy(() async {
        await _auth.signOut();
        setState(() {
          _authState = const AuthState(email: null, isLoggedIn: false);
          _status = 'Signed out';
        });
      });

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)));
  }

  void _navigateToFolderScreen() {
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FolderScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _authState.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Sync'),
        actions: [
          IconButton(onPressed: _busy ? null : _openSettings, icon: const Icon(Icons.settings)),
          if (signedIn) IconButton(onPressed: _busy ? null : _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text('Photo Sync', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sync your Android photos to S3', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 48),
              Card(
                child: ListTile(
                  leading: Icon(signedIn ? Icons.verified_user : Icons.account_circle),
                  title: Text(signedIn ? _authState.email ?? 'Signed in' : 'Not signed in'),
                  subtitle: const Text('Authenticate to the photo-folder website'),
                  trailing: signedIn
                      ? null
                      : FilledButton.icon(onPressed: _busy ? null : _login, icon: const Icon(Icons.login), label: const Text('Google')),
                ),
              ),
              const SizedBox(height: 24),
              if (_busy) const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
