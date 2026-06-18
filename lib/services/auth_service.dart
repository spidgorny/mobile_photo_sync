import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'settings_service.dart';

class AuthState {
  const AuthState({required this.email, required this.isLoggedIn});
  final String? email;
  final bool isLoggedIn;
}

class AuthService {
  AuthService(this._settings);

  final SettingsService _settings;
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _emailKey = 'email';

  Future<AuthState> getState() async {
    final token = await _storage.read(key: _accessTokenKey);
    final email = await _storage.read(key: _emailKey);
    return AuthState(email: email, isLoggedIn: token != null && email != null);
  }

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<AuthState> signInWithGoogle() async {
    try {
      final baseUrl = await _settings.apiBaseUrl;
      if (baseUrl == null) {
        debugPrint('Auth Error: API base URL not set');
        throw StateError('Set the website API URL first.');
      }

      final webClientId = await _settings.googleWebClientId;
      debugPrint('Google Sign-In: Starting with webClientId: ${webClientId ?? "null"}');
      
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: webClientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('Auth Error: Google sign-in was cancelled by user');
        throw StateError('Google sign-in was cancelled.');
      }
      
      debugPrint('Google Sign-In: Got account: ${account.email}');
      final auth = await account.authentication;
      debugPrint('Google Sign-In: Got auth tokens, idToken: ${auth.idToken != null ? "present" : "null"}');

      final dio = Dio(BaseOptions(baseUrl: baseUrl));
      debugPrint('API Login: Calling $baseUrl/api/auth/login for ${account.email}');
      
      final response = await dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'email': account.email,
          'provider': 'google',
          if (auth.idToken != null) 'idToken': auth.idToken,
        },
      );

      debugPrint('API Login: Response status: ${response.statusCode}');
      final data = response.data ?? {};
      debugPrint('API Login: Response data: $data');
      
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null || refreshToken == null) {
        debugPrint('Auth Error: Login response missing tokens. accessToken: $accessToken, refreshToken: $refreshToken');
        throw StateError('Login response did not include tokens.');
      }

      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _storage.write(key: _emailKey, value: account.email);
      debugPrint('Auth Success: Logged in as ${account.email}');
      return AuthState(email: account.email, isLoggedIn: true);
    } catch (e, stackTrace) {
      debugPrint('Auth Error: $e');
      debugPrint('Auth Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      final baseUrl = await _settings.apiBaseUrl;
      final currentRefreshToken = await refreshToken;
      if (baseUrl == null || currentRefreshToken == null) {
        debugPrint('Auth Error: Cannot refresh - baseUrl: $baseUrl, refreshToken: ${currentRefreshToken != null ? "present" : "null"}');
        throw StateError('No refresh token is available.');
      }

      debugPrint('Auth Refresh: Calling $baseUrl/api/auth/refresh');
      final dio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': currentRefreshToken},
      );
      
      debugPrint('Auth Refresh: Response status: ${response.statusCode}');
      final data = response.data ?? {};
      final newAccessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;
      if (newAccessToken == null || newRefreshToken == null) {
        debugPrint('Auth Error: Refresh response missing tokens');
        throw StateError('Refresh response did not include tokens.');
      }
      
      await _storage.write(key: _accessTokenKey, value: newAccessToken);
      await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
      debugPrint('Auth Refresh: Success');
    } catch (e, stackTrace) {
      debugPrint('Auth Refresh Error: $e');
      debugPrint('Auth Refresh Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('Auth SignOut: Signing out');
      await GoogleSignIn().signOut();
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _emailKey);
      debugPrint('Auth SignOut: Success');
    } catch (e, stackTrace) {
      debugPrint('Auth SignOut Error: $e');
      debugPrint('Auth SignOut Stack trace: $stackTrace');
      rethrow;
    }
  }
}
