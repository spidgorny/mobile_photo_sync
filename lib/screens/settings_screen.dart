import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final SettingsService settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiController = TextEditingController();
  final _webClientIdController = TextEditingController();
  final _androidClientIdController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      String? api;
      String? web;
      String? android;

      if (kDebugMode) {
        api = await widget.settings.apiBaseUrl;
        web = await widget.settings.googleWebClientId;
        android = await widget.settings.googleAndroidClientId;
      } else {
        api = await widget.settings.apiBaseUrlStored;
        web = await widget.settings.googleWebClientIdStored;
        android = await widget.settings.googleAndroidClientIdStored;
      }

      if (mounted) {
        _apiController.text = api ?? '';
        _webClientIdController.text = web ?? '';
        _androidClientIdController.text = android ?? '';
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final url = _apiController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the API URL')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Validate the API URL before saving
      final api = ApiService(widget.settings, AuthService(widget.settings));
      await api.checkHealth(url);

      await widget.settings.setApiBaseUrl(url);
      await widget.settings.setGoogleWebClientId(_webClientIdController.text);
      await widget.settings
          .setGoogleAndroidClientId(_androidClientIdController.text);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid API URL or server unreachable: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _apiController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Website API base URL',
                    hintText: 'https://photos.example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _webClientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Google Web Client ID (Required)',
                    helperText:
                        'Found in Google Cloud Console as "Web client". This MUST be used as the serverClientId to get an idToken for the backend.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _androidClientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Google Android Client ID (Informational)',
                    helperText:
                        'Created in Google Console with SHA-1 and package name (com.androidfromfrankfurt.photo_sync). Android handles this automatically; you don\'t strictly need to paste the ID here.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Checking...' : 'Save'),
                ),
              ],
            ),
    );
  }
}
