import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:workmanager/workmanager.dart';

import '../models/photo_upload.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'photo_scanner_service.dart';
import 'settings_service.dart';
import 'sync_service.dart';
import 'sync_settings_service.dart';
import 'upload_history_service.dart';

class BackgroundSyncService {
  BackgroundSyncService(this._settings, this._auth, this._api, this._scanner, this._history);

  final SettingsService _settings;
  final AuthService _auth;
  final ApiService _api;
  final PhotoScannerService _scanner;
  final UploadHistoryService _history;

  static const _notificationChannelId = 'photo_sync_channel';
  static const _notificationChannelName = 'Photo Sync';
  static const _notificationChannelDescription = 'Background photo synchronization notifications';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notifications.initialize(initializationSettings);

    const androidChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: _notificationChannelDescription,
      importance: Importance.high,
    );
    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }

  Future<void> enableBackgroundSync() async {
    await Workmanager().registerOneOffTask(
      'syncTask',
      'syncTask',
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
    );
  }

  Future<void> disableBackgroundSync() async {
    await Workmanager().cancelAll();
  }

  Future<void> schedulePeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      'periodicSyncTask',
      'periodicSyncTask',
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
    );
  }

  Future<void> performSync() async {
    try {
      final settingsService = SyncSettingsService();
      final settings = await settingsService.getSettings();

      if (!settings.enabled || settings.folder.isEmpty) {
        debugPrint('Background sync: Not enabled or no folder selected');
        return;
      }

      await _showNotification('Photo Sync', 'Starting synchronization...');

      final sync = SyncService(_api, _scanner, _history);
      final photos = await sync.preview(settings.startDate, settings.endDate);

      if (photos.isEmpty) {
        await _showNotification('Photo Sync', 'No photos to sync');
        return;
      }

      var uploaded = 0;
      var skipped = 0;

      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final key = photo.uploadKey(settings.folder);

        if (await _history.isUploaded(key)) {
          skipped++;
          continue;
        }

        try {
          final url = await _api.presign(key: key, contentType: photo.mimeType);
          await _api.uploadToPresignedUrl(
            url: url,
            stream: photo.file.openRead(),
            length: photo.size,
            contentType: photo.mimeType,
          );
          await _history.markUploaded(key);
          uploaded++;

          final progress = ((i + 1) / photos.length * 100).toInt();
          await _showNotification(
            'Photo Sync',
            'Uploading: $progress% ($uploaded/${photos.length})',
            progress: progress,
          );
        } catch (e) {
          debugPrint('Background sync: Failed to upload ${photo.filename}: $e');
        }
      }

      await _showNotification(
        'Photo Sync',
        'Sync complete: $uploaded uploaded, $skipped skipped',
      );
    } catch (e) {
      debugPrint('Background sync error: $e');
      await _showNotification('Photo Sync', 'Sync failed: ${e.toString()}');
    }
  }

  Future<void> _showNotification(String title, String body, {int? progress}) async {
    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showProgress: progress != null,
      maxProgress: 100,
      progress: progress ?? 0,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final settings = SettingsService();
      final auth = AuthService(settings);
      final api = ApiService(settings, auth);
      final scanner = PhotoScannerService();
      final history = UploadHistoryService();

      final syncService = BackgroundSyncService(settings, auth, api, scanner, history);
      await syncService.initialize();
      await syncService.performSync();

      return true;
    } catch (e) {
      debugPrint('Background sync task error: $e');
      return false;
    }
  });
}
