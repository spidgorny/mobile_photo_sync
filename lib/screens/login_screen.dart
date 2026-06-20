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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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
        });
        _navigateToFolderScreen();
      });

  Future<void> _logout() => _runBusy(() async {
        await _auth.signOut();
        setState(() {
          _authState = const AuthState(email: null, isLoggedIn: false);
        });
      });

  Future<void> _openSettings() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)));
  }

  void _navigateToFolderScreen() {
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const FolderScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _authState.isLoggedIn;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _busy ? null : _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          if (signedIn)
            IconButton(
              onPressed: _busy ? null : _logout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_sync_rounded,
                  size: 100,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),

              // Title Section
              Text(
                'Photo Sync',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your memories safe on S3',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 64),

              // Status/Action Section
              if (signedIn) ...[
                Text(
                  'Signed in as',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _authState.email ?? '',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _navigateToFolderScreen,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Open My Folders',
                        style: TextStyle(fontSize: 18)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    onPressed: _busy ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded),
                        const SizedBox(width: 12),
                        Text(
                          _busy ? 'Signing in...' : 'Sign in with Google',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Required to sync with your S3 bucket',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: 48),
              if (_busy) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
