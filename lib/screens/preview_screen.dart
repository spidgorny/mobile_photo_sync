import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/photo_upload.dart';
import '../services/sync_service.dart';
import '../services/upload_history_service.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
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
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  List<PhotoUpload> _photos = [];
  Set<String> _uploadedKeys = {};
  bool _busy = false;
  String _status = 'Loading...';
  int _completed = 0;
  int _total = 0;
  double? _fileProgress;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _busy = true);
    try {
      final photos = await widget.sync.preview(widget.start, widget.end);
      final history = UploadHistoryService();
      
      final uploadedKeys = <String>{};
      for (final photo in photos) {
        final key = photo.uploadKey(widget.folder);
        if (await history.isUploaded(key)) {
          uploadedKeys.add(key);
        }
      }

      final newCount = photos.length - uploadedKeys.length;
      setState(() {
        _photos = photos;
        _uploadedKeys = uploadedKeys;
        _status = 'Found ${photos.length} photos ($newCount new)';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
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
        _status = 'Done. Scanned ${summary.scanned}, uploaded ${summary.uploaded}, skipped ${summary.skipped}.';
        _fileProgress = null;
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? null : _completed / _total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Photos'),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (progress != null) ...[
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            Text('Overall: $_completed / $_total'),
          ],
          if (_fileProgress != null) ...[
            LinearProgressIndicator(value: _fileProgress!.clamp(0, 1)),
            Text('Current file: ${(_fileProgress! * 100).toStringAsFixed(0)}%'),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_status),
          ),
          Expanded(
            child: _photos.isEmpty
                ? Center(child: Text(_busy ? 'Loading...' : 'No photos found'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _photos.length,
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      final isUploaded = _uploadedKeys.contains(photo.uploadKey(widget.folder));
                      return FutureBuilder<Uint8List?>(
                        future: photo.assetId.isNotEmpty
                            ? AssetEntity.fromId(photo.assetId).then((asset) => asset?.thumbnailData)
                            : null,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasData && snapshot.data != null) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                ),
                                if (isUploaded)
                                  const Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      Icons.cloud_done,
                                      color: Colors.white,
                                      size: 20,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 2,
                                          color: Colors.black,
                                          offset: Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          }
                          return const Icon(Icons.image);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _upload,
        icon: const Icon(Icons.cloud_upload),
        label: const Text('Upload'),
      ),
    );
  }
}
