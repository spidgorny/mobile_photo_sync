import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'settings_service.dart';

class ApiService {
  ApiService(this._settings, this._auth);

  final SettingsService _settings;
  final AuthService _auth;

  Future<Dio> _dio() async {
    final baseUrl = await _settings.apiBaseUrl;
    if (baseUrl == null) throw StateError('Set the website API URL first.');
    final token = await _auth.accessToken;
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 2),
      sendTimeout: const Duration(minutes: 10),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));
    dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        try {
          await _auth.refresh();
          final retryToken = await _auth.accessToken;
          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer $retryToken';
          final clone = await dio.fetch(opts);
          return handler.resolve(clone);
        } catch (_) {
          // fall through to original error
        }
      }
      handler.next(error);
    }));
    return dio;
  }

  Future<void> checkHealth(String url) async {
    final dio = Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final response = await dio.get<Map<String, dynamic>>('/api/health');
    if (response.statusCode != 200) {
      throw StateError(
          'API health check failed with status: ${response.statusCode}');
    }
  }

  Future<List<String>> listFolders() async {
    final dio = await _dio();
    final response = await dio.get<Map<String, dynamic>>('/api/s3/folders');
    final raw = response.data?['folders'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  Future<void> createFolder(String name) async {
    final dio = await _dio();
    await dio.post('/api/s3/mkdir', data: {'name': name});
  }

  Future<String> presign(
      {required String key, required String contentType}) async {
    final dio = await _dio();
    final response = await dio.post<Map<String, dynamic>>(
      '/api/sync/presign',
      data: {'key': key, 'content_type': contentType},
    );
    final url = response.data?['presignedUrl'] as String?;
    if (url == null)
      throw StateError('Presign response did not include presignedUrl.');
    return url;
  }

  Future<void> uploadToPresignedUrl({
    required String url,
    required Stream<List<int>> stream,
    required int length,
    required String contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final dio = Dio();
    await dio.put<void>(
      url,
      data: stream,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': length,
        },
      ),
      onSendProgress: onProgress,
    );
  }
}
