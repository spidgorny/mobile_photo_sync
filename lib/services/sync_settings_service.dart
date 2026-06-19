import 'package:shared_preferences/shared_preferences.dart';

class SyncSettings {
  const SyncSettings({
    required this.enabled,
    required this.folder,
    required this.startDate,
    required this.endDate,
  });

  final bool enabled;
  final String folder;
  final DateTime startDate;
  final DateTime endDate;

  SyncSettings copyWith({
    bool? enabled,
    String? folder,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return SyncSettings(
      enabled: enabled ?? this.enabled,
      folder: folder ?? this.folder,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class SyncSettingsService {
  static const _enabledKey = 'sync_enabled';
  static const _folderKey = 'sync_folder';
  static const _startDateKey = 'sync_start_date';
  static const _endDateKey = 'sync_end_date';

  Future<SyncSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final folder = prefs.getString(_folderKey) ?? '';
    final startDateMs = prefs.getInt(_startDateKey);
    final endDateMs = prefs.getInt(_endDateKey);

    return SyncSettings(
      enabled: enabled,
      folder: folder,
      startDate: startDateMs != null ? DateTime.fromMillisecondsSinceEpoch(startDateMs) : DateTime.now().subtract(const Duration(days: 7)),
      endDate: endDateMs != null ? DateTime.fromMillisecondsSinceEpoch(endDateMs) : DateTime.now(),
    );
  }

  Future<void> saveSettings(SyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setString(_folderKey, settings.folder);
    await prefs.setInt(_startDateKey, settings.startDate.millisecondsSinceEpoch);
    await prefs.setInt(_endDateKey, settings.endDate.millisecondsSinceEpoch);
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_folderKey);
    await prefs.remove(_startDateKey);
    await prefs.remove(_endDateKey);
  }
}
