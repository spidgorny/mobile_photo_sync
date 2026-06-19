import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String _status = '';
  bool _showNewFolderForm = false;

  final _newFolderController = TextEditingController();
  final _newFolderFocusNode = FocusNode();

  static const _selectedFolderKey = 'selected_folder';

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _auth = AuthService(_settings);
    _api = ApiService(_settings, _auth);
    _loadFolders();
    _loadSelectedFolder();
  }

  Future<void> _loadSelectedFolder() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedFolder = prefs.getString(_selectedFolderKey);
    if (selectedFolder != null) {
      setState(() => _selectedFolder = selectedFolder);
    }
  }

  Future<void> _saveSelectedFolder(String folder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFolderKey, folder);
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
      await _saveSelectedFolder(name);
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)));
  }

  void _navigateToPhotoList(String folder) {
    setState(() => _selectedFolder = folder);
    _saveSelectedFolder(folder);
    Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoListScreen(folder: folder)));
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
      body: Column(
        children: [
          if (_showNewFolderForm)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
            ),
          Expanded(
            child: _folders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No folders found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('Create a folder to get started'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final folder = _folders[index];
                      final isSelected = folder == _selectedFolder;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.folder,
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          title: Text(folder),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                          onTap: _busy ? null : () => _navigateToPhotoList(folder),
                        ),
                      );
                    },
                  ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_status),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () {
          setState(() => _showNewFolderForm = true);
          Future.delayed(const Duration(milliseconds: 100), () => _newFolderFocusNode.requestFocus());
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Folder'),
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
