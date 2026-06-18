import '../models/photo_upload.dart';
import 'api_service.dart';
import 'photo_scanner_service.dart';
import 'upload_history_service.dart';

class SyncProgress {
  SyncProgress({
    required this.message,
    required this.completed,
    required this.total,
    this.currentFileProgress,
  });

  final String message;
  final int completed;
  final int total;
  final double? currentFileProgress;
}

class SyncSummary {
  SyncSummary({required this.scanned, required this.uploaded, required this.skipped});
  final int scanned;
  final int uploaded;
  final int skipped;
}

class SyncService {
  SyncService(this._api, this._scanner, this._history);

  final ApiService _api;
  final PhotoScannerService _scanner;
  final UploadHistoryService _history;

  Future<List<PhotoUpload>> preview(DateTime start, DateTime end) {
    return _scanner.findCameraPhotos(start: start, end: end);
  }

  Future<SyncSummary> uploadRange({
    required String folder,
    required DateTime start,
    required DateTime end,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    onProgress(SyncProgress(message: 'Scanning DCIM/Camera...', completed: 0, total: 0));
    final photos = await _scanner.findCameraPhotos(start: start, end: end);
    var uploaded = 0;
    var skipped = 0;

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final key = photo.uploadKey(folder);
      if (await _history.isUploaded(key)) {
        skipped++;
        onProgress(SyncProgress(message: 'Skipped ${photo.filename}', completed: i + 1, total: photos.length));
        continue;
      }

      onProgress(SyncProgress(message: 'Requesting upload URL for ${photo.filename}', completed: i, total: photos.length));
      final url = await _api.presign(key: key, contentType: photo.mimeType);
      onProgress(SyncProgress(message: 'Uploading ${photo.filename}', completed: i, total: photos.length, currentFileProgress: 0));
      await _api.uploadToPresignedUrl(
        url: url,
        stream: photo.file.openRead(),
        length: photo.size,
        contentType: photo.mimeType,
        onProgress: (sent, total) {
          onProgress(SyncProgress(
            message: 'Uploading ${photo.filename}',
            completed: i,
            total: photos.length,
            currentFileProgress: total <= 0 ? null : sent / total,
          ));
        },
      );
      await _history.markUploaded(key);
      uploaded++;
      onProgress(SyncProgress(message: 'Uploaded ${photo.filename}', completed: i + 1, total: photos.length));
    }

    return SyncSummary(scanned: photos.length, uploaded: uploaded, skipped: skipped);
  }
}
