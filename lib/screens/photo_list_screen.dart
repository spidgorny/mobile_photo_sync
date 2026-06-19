import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/photo_scanner_service.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';
import '../services/upload_history_service.dart';
import 'folder_screen.dart';
import 'preview_screen.dart';

class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({super.key, required this.folder});

  final String folder;

  @override
  State<PhotoListScreen> createState() => _PhotoListScreenState();
}

class _PhotoListScreenState extends State<PhotoListScreen> {
  late final SettingsService _settings;
  late final AuthService _auth;
  late final ApiService _api;
  late final SyncService _sync;
  late final UploadHistoryService _history;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _status = 'Ready';
  bool _busy = false;
  int _completed = 0;
  int _total = 0;
  double? _fileProgress;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _auth = AuthService(_settings);
    _api = ApiService(_settings, _auth);
    _history = UploadHistoryService();
    _sync = SyncService(_api, PhotoScannerService(), _history);
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          folder: widget.folder,
          start: _startDate,
          end: _endDate,
          sync: _sync,
        ),
      ),
    );
  }

  Future<void> _upload() async {
    await _runBusy(() async {
      final summary = await _sync.uploadRange(
        folder: widget.folder,
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

  String _date(DateTime date) => DateFormat.yMMMd().format(date);

  void _changeFolder() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FolderScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? null : _completed / _total;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder),
        actions: [
          IconButton(
            onPressed: _busy ? null : _changeFolder,
            icon: const Icon(Icons.folder_open),
            tooltip: 'Change folder',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _preview, icon: const Icon(Icons.search), label: const Text('Preview'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(onPressed: _busy ? null : _upload, icon: const Icon(Icons.cloud_upload), label: const Text('Upload'))),
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
