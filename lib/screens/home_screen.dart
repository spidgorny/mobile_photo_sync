import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_upload.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/photo_scanner_service.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../services/upload_history_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SettingsService _settings;
  late final AuthService _auth;
  late final ApiService _api;
  late final SyncService _sync;
  late final UploadHistoryService _history;

  AuthState _authState = const AuthState(email: null, isLoggedIn: false);
  List<String> _folders = [];
  String? _selectedFolder;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _status = 'Ready';
  bool _busy = false;
  int _completed = 0;
  int _total = 0;
  double? _fileProgress;
  bool _showNewFolderForm = false;
  List<PhotoUpload> _previewPhotos = [];

  final _newFolderController = TextEditingController();
  final _newFolderFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _auth = AuthService(_settings);
    _api = ApiService(_settings, _auth);
    _history = UploadHistoryService();
    _sync = SyncService(_api, PhotoScannerService(), _history);
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await _auth.getState();
    setState(() => _authState = state);
    if (state.isLoggedIn) {
      await _loadFolders();
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
        await _loadFolders();
      });

  Future<void> _logout() => _runBusy(() async {
        await _auth.signOut();
        setState(() {
          _authState = const AuthState(email: null, isLoggedIn: false);
          _folders = [];
          _selectedFolder = null;
          _status = 'Signed out';
        });
      });

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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _preview() async {
    await _runBusy(() async {
      setState(() => _status = 'Scanning DCIM/Camera...');
      final photos = await _sync.preview(_startDate, _endDate);
      setState(() {
        _previewPhotos = photos;
        _status = 'Found ${photos.length} camera photos in date range.';
      });
    });
  }

  Future<void> _upload() async {
    final folder = _selectedFolder;
    if (folder == null || folder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create or select a folder first.')));
      return;
    }
    await _runBusy(() async {
      final summary = await _sync.uploadRange(
        folder: folder,
        start: _startDate,
        end: _endDate,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _status = progress.message;
            _completed = progress.completed;
            _total = progress.total;
            _fileProgress = progress.currentFileProgress;
          });
        },
      );
      setState(() {
        _status = 'Done. Scanned ${summary.scanned}, uploaded ${summary.uploaded}, skipped ${summary.skipped}.';
        _fileProgress = null;
      });
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)));
  }

  String _date(DateTime date) => DateFormat.yMMMd().format(date);

  @override
  Widget build(BuildContext context) {
    final signedIn = _authState.isLoggedIn;
    final progress = _total == 0 ? null : _completed / _total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Sync'),
        actions: [
          IconButton(onPressed: _busy ? null : _openSettings, icon: const Icon(Icons.settings)),
          if (signedIn) IconButton(onPressed: _busy ? null : _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 16),
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
              IconButton(onPressed: _busy || !signedIn ? null : _loadFolders, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          if (!_showNewFolderForm)
            FilledButton.icon(
              onPressed: _busy || !signedIn ? null : () {
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
                FilledButton(onPressed: _busy || !signedIn ? null : _createFolder, child: const Text('Create')),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _showNewFolderForm = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text('Date range', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(onPressed: _busy ? null : _pickStartDate, icon: const Icon(Icons.calendar_today), label: Text('From ${_date(_startDate)}')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(onPressed: _busy ? null : _pickEndDate, icon: const Icon(Icons.event), label: Text('To ${_date(_endDate)}')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: _busy || !signedIn ? null : _preview, icon: const Icon(Icons.search), label: const Text('Preview'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: _busy || !signedIn ? null : _upload, icon: const Icon(Icons.cloud_upload), label: const Text('Upload'))),
            ],
          ),
          const SizedBox(height: 24),
          if (_busy) const LinearProgressIndicator(),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            Text('Overall: $_completed / $_total'),
          ],
          if (_fileProgress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _fileProgress!.clamp(0, 1)),
            Text('Current file: ${(_fileProgress! * 100).toStringAsFixed(0)}%'),
          ],
          const SizedBox(height: 16),
          Text(_status),
          const SizedBox(height: 16),
          if (_previewPhotos.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _previewPhotos.length,
              itemBuilder: (context, index) {
                final photo = _previewPhotos[index];
                return FutureBuilder<Uint8List?>(
                  future: photo.assetId.isNotEmpty
                      ? AssetEntity.fromId(photo.assetId).then((asset) => asset?.thumbnailData)
                      : null,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return const Icon(Icons.image);
                  },
                );
              },
            ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _busy ? null : () async => _runBusy(() => _history.clear().then((_) => setState(() => _status = 'Local upload history cleared.'))),
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Clear local upload history'),
          ),
        ],
      ),
    );
  }
}
