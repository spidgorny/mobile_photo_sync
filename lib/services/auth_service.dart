import 'package:dio/dio.dart';
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
    final baseUrl = await _settings.apiBaseUrl;
    if (baseUrl == null) {
      throw StateError('Set the website API URL first.');
    }

    final webClientId = await _settings.googleWebClientId;
    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: webClientId,
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw StateError('Google sign-in was cancelled.');
    }
    final auth = await account.authentication;

    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {
        'email': account.email,
        'provider': 'google',
        if (auth.idToken != null) 'idToken': auth.idToken,
      },
    );

    final data = response.data ?? {};
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw StateError('Login response did not include tokens.');
    }

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _emailKey, value: account.email);
    return AuthState(email: account.email, isLoggedIn: true);
  }

  Future<void> refresh() async {
    final baseUrl = await _settings.apiBaseUrl;
    final currentRefreshToken = await refreshToken;
    if (baseUrl == null || currentRefreshToken == null) {
      throw StateError('No refresh token is available.');
    }

    final dio = Dio(BaseOptions(baseUrl: baseUrl));
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/refresh',
      data: {'refreshToken': currentRefreshToken},
    );
    final data = response.data ?? {};
    final newAccessToken = data['accessToken'] as String?;
    final newRefreshToken = data['refreshToken'] as String?;
    if (newAccessToken == null || newRefreshToken == null) {
      throw StateError('Refresh response did not include tokens.');
    }
    await _storage.write(key: _accessTokenKey, value: newAccessToken);
    await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailKey);
  }
}
