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
    _apiController.text = await widget.settings.apiBaseUrl ?? '';
    _webClientIdController.text = await widget.settings.googleWebClientId ?? '';
    _androidClientIdController.text = await widget.settings.googleAndroidClientId ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await widget.settings.setApiBaseUrl(_apiController.text);
    await widget.settings.setGoogleWebClientId(_webClientIdController.text);
    await widget.settings.setGoogleAndroidClientId(_androidClientIdController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
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
                    labelText: 'Google Web Client ID (optional)',
                    helperText: 'Needed if the backend later verifies Google idToken.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _androidClientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Google Android Client ID (required for physical devices)',
                    helperText: 'Required for Google Sign-In on Android devices. Add both debug and release SHA-1 fingerprints to this client ID in Google Cloud Console.',
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
