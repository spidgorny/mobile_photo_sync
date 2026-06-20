import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static const _apiBaseUrlKey = 'api_base_url';
  static const _googleWebClientIdKey = 'google_web_client_id';
  static const _googleAndroidClientIdKey = 'google_android_client_id';

  static const defaultApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const defaultGoogleWebClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID_WEB');
  static const defaultGoogleAndroidClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID_ANDROID');

  Future<String?> get apiBaseUrl async {
    final stored = await _storage.read(key: _apiBaseUrlKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    if (defaultApiBaseUrl.trim().isNotEmpty) return defaultApiBaseUrl.trim();
    return null;
  }

  Future<void> setApiBaseUrl(String value) async {
    await _storage.write(
        key: _apiBaseUrlKey,
        value: value.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  Future<String?> get googleWebClientId async {
    final stored = await _storage.read(key: _googleWebClientIdKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    if (defaultGoogleWebClientId.trim().isNotEmpty) {
      return defaultGoogleWebClientId.trim();
    }
    return null;
  }

  Future<void> setGoogleWebClientId(String value) async {
    await _storage.write(key: _googleWebClientIdKey, value: value.trim());
  }

  Future<String?> get googleAndroidClientId async {
    final stored = await _storage.read(key: _googleAndroidClientIdKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    if (defaultGoogleAndroidClientId.trim().isNotEmpty) {
      return defaultGoogleAndroidClientId.trim();
    }
    return null;
  }

  Future<void> setGoogleAndroidClientId(String value) async {
    await _storage.write(key: _googleAndroidClientIdKey, value: value.trim());
  }

  // Only return stored values, no environment defaults (for production mode)
  Future<String?> get apiBaseUrlStored async {
    final stored = await _storage.read(key: _apiBaseUrlKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    return null;
  }

  Future<String?> get googleWebClientIdStored async {
    final stored = await _storage.read(key: _googleWebClientIdKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    return null;
  }

  Future<String?> get googleAndroidClientIdStored async {
    final stored = await _storage.read(key: _googleAndroidClientIdKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    return null;
  }
}
