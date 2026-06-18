import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const _storage = FlutterSecureStorage();
  static const _apiBaseUrlKey = 'api_base_url';
  static const _googleWebClientIdKey = 'google_web_client_id';

  static const defaultApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const defaultGoogleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  Future<String?> get apiBaseUrl async {
    final stored = await _storage.read(key: _apiBaseUrlKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    if (defaultApiBaseUrl.trim().isNotEmpty) return defaultApiBaseUrl.trim();
    return null;
  }

  Future<void> setApiBaseUrl(String value) async {
    await _storage.write(key: _apiBaseUrlKey, value: value.trim().replaceAll(RegExp(r'/+$'), ''));
  }

  Future<String?> get googleWebClientId async {
    final stored = await _storage.read(key: _googleWebClientIdKey);
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    if (defaultGoogleWebClientId.trim().isNotEmpty) return defaultGoogleWebClientId.trim();
    return null;
  }

  Future<void> setGoogleWebClientId(String value) async {
    await _storage.write(key: _googleWebClientIdKey, value: value.trim());
  }
}
