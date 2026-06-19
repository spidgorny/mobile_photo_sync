import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // In debug mode, prefill from environment variables
    // In production mode, only load stored values (force manual entry)
    if (kDebugMode) {
      _apiController.text = await widget.settings.apiBaseUrl ?? '';
      _webClientIdController.text =
          await widget.settings.googleWebClientId ?? '';
      _androidClientIdController.text =
          await widget.settings.googleAndroidClientId ?? '';
    } else {
      // In production, only load stored values (no defaults from env)
      _apiController.text = await widget.settings.apiBaseUrlStored ?? '';
      _webClientIdController.text =
          await widget.settings.googleWebClientIdStored ?? '';
      _androidClientIdController.text =
          await widget.settings.googleAndroidClientIdStored ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await widget.settings.setApiBaseUrl(_apiController.text);
    await widget.settings.setGoogleWebClientId(_webClientIdController.text);
    await widget.settings
        .setGoogleAndroidClientId(_androidClientIdController.text);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
      Navigator.pop(context);
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
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
    );
  }
}
