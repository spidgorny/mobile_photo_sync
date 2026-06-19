import 'package:flutter/material.dart';

import '../services/sync_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.folder,
    required this.start,
    required this.end,
    required this.sync,
  });

  final String folder;
  final DateTime start;
  final DateTime end;
  final SyncService sync;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String _status = 'Starting upload...';
  int _completed = 0;
  int _total = 0;
  double? _fileProgress;
  bool _isComplete = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  Future<void> _upload() async {
    try {
      final summary = await widget.sync.uploadRange(
        folder: widget.folder,
        start: widget.start,
        end: widget.end,
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
        _status =
            'Done. Scanned ${summary.scanned}, uploaded ${summary.uploaded}, skipped ${summary.skipped}.';
        _fileProgress = null;
        _isComplete = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Upload failed: ${e.toString()}';
        _hasError = true;
        _isComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? null : _completed / _total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Progress'),
        automaticallyImplyLeading: !_isComplete,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _hasError
                      ? Icons.error
                      : (_isComplete ? Icons.check_circle : Icons.cloud_upload),
                  size: 80,
                  color: _hasError
                      ? Colors.red
                      : (_isComplete ? Colors.green : Colors.blue),
                ),
                const SizedBox(height: 24),
                Text(
                  _hasError
                      ? 'Upload Failed'
                      : (_isComplete ? 'Upload Complete' : 'Uploading...'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (!_isComplete) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                ],
                if (progress != null && !_isComplete) ...[
                  LinearProgressIndicator(value: progress.clamp(0, 1)),
                  const SizedBox(height: 8),
                  Text('Overall: $_completed / $_total',
                      textAlign: TextAlign.center),
                ],
                if (_fileProgress != null && !_isComplete) ...[
                  LinearProgressIndicator(value: _fileProgress!.clamp(0, 1)),
                  const SizedBox(height: 8),
                  Text(
                      'Current file: ${(_fileProgress! * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isComplete)
                  SizedBox(
                    width: 200,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, size: 28),
                      label: const Text('OK', style: TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
