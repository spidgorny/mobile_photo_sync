import '../models/photo_upload.dart';
import 'api_service.dart';
import 'photo_scanner_service.dart';
import 'upload_history_service.dart';

enum PhotoUploadStatus { pending, uploading, success, skipped, error }

class SyncProgress {
  SyncProgress({
    required this.message,
    required this.completed,
    required this.total,
    required this.statuses,
    this.currentFileProgress,
  });

  final String message;
  final int completed;
  final int total;
  final List<PhotoUploadStatus> statuses;
  final double? currentFileProgress;
}

class SyncSummary {
  SyncSummary(
      {required this.scanned, required this.uploaded, required this.skipped});
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
    List<PhotoUpload>? photos,
  }) async {
    final list =
        photos ?? await _scanner.findCameraPhotos(start: start, end: end);
    final statuses =
        List.generate(list.length, (_) => PhotoUploadStatus.pending);

    if (photos == null) {
      onProgress(SyncProgress(
        message: 'Scanning DCIM/Camera...',
        completed: 0,
        total: list.length,
        statuses: statuses,
      ));
    }

    var uploaded = 0;
    var skipped = 0;

    for (var i = 0; i < list.length; i++) {
      final photo = list[i];
      final key = photo.uploadKey(folder);

      if (await _history.isUploaded(key)) {
        skipped++;
        statuses[i] = PhotoUploadStatus.skipped;
        onProgress(SyncProgress(
          message: 'Skipped ${photo.filename}',
          completed: i + 1,
          total: list.length,
          statuses: statuses,
        ));
        continue;
      }

      statuses[i] = PhotoUploadStatus.uploading;
      onProgress(SyncProgress(
        message: 'Requesting upload URL for ${photo.filename}',
        completed: i,
        total: list.length,
        statuses: statuses,
      ));

      try {
        final url = await _api.presign(key: key, contentType: photo.mimeType);
        await _api.uploadToPresignedUrl(
          url: url,
          stream: photo.file.openRead(),
          length: photo.size,
          contentType: photo.mimeType,
          onProgress: (sent, total) {
            onProgress(SyncProgress(
              message: 'Uploading ${photo.filename}',
              completed: i,
              total: list.length,
              statuses: statuses,
              currentFileProgress: total <= 0 ? null : sent / total,
            ));
          },
        );
        await _history.markUploaded(key);
        uploaded++;
        statuses[i] = PhotoUploadStatus.success;
      } catch (e) {
        statuses[i] = PhotoUploadStatus.error;
        rethrow;
      }

      onProgress(SyncProgress(
        message: 'Uploaded ${photo.filename}',
        completed: i + 1,
        total: list.length,
        statuses: statuses,
      ));
    }

    return SyncSummary(
        scanned: list.length, uploaded: uploaded, skipped: skipped);
  }
}
