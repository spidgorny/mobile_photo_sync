import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'photo_list_screen.dart';
import 'settings_screen.dart';

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  late final SettingsService _settings;
  late final AuthService _auth;
  late final ApiService _api;

  List<String> _folders = [];
  String? _selectedFolder;
  bool _busy = false;
  String _status = 'Ready';
  bool _showNewFolderForm = false;

  final _newFolderController = TextEditingController();
  final _newFolderFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _auth = AuthService(_settings);
    _api = ApiService(_settings, _auth);
    _loadFolders();
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

  Future<void> _loadFolders() async {
    await _runBusy(() async {
      final folders = await _api.listFolders();
      setState(() {
        _folders = folders;
        _selectedFolder = folders.contains(_selectedFolder) ? _selectedFolder : (folders.isEmpty ? null : folders.first);
      });
    });
  }

  Future<void> _createFolder() async {
    final name = _newFolderController.text.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (name.isEmpty) return;
    await _runBusy(() async {
      await _api.createFolder(name);
      _newFolderController.clear();
      await _loadFolders();
      setState(() {
        _selectedFolder = name;
        _status = 'Created folder $name';
        _showNewFolderForm = false;
      });
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)));
  }

  void _navigateToPhotoList() {
    if (_selectedFolder != null && _selectedFolder!.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoListScreen(folder: _selectedFolder!)));
    }
  }

  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Folder'),
        actions: [
          IconButton(onPressed: _busy ? null : _openSettings, icon: const Icon(Icons.settings)),
          IconButton(onPressed: _busy ? null : _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Upload folder', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFolder,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Existing folder'),
                  items: _folders.map((folder) => DropdownMenuItem(value: folder, child: Text(folder))).toList(),
                  onChanged: _busy ? null : (value) => setState(() => _selectedFolder = value),
                ),
              ),
              IconButton(onPressed: _busy ? null : _loadFolders, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          if (!_showNewFolderForm)
            FilledButton.icon(
              onPressed: _busy ? null : () {
                setState(() => _showNewFolderForm = true);
                Future.delayed(const Duration(milliseconds: 100), () => _newFolderFocusNode.requestFocus());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Folder'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFolderController,
                    focusNode: _newFolderFocusNode,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'New folder name'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _createFolder, child: const Text('Create')),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _showNewFolderForm = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(_status),
          const SizedBox(height: 24),
          if (_selectedFolder != null && _selectedFolder!.isNotEmpty)
            FilledButton.icon(
              onPressed: _busy ? null : _navigateToPhotoList,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue to Photos'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    _newFolderFocusNode.dispose();
    super.dispose();
  }
}
