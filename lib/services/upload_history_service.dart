import 'package:shared_preferences/shared_preferences.dart';

class UploadHistoryService {
  static const _uploadedKeys = 'uploaded_keys';

  Future<Set<String>> _keys() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_uploadedKeys) ?? const []).toSet();
  }

  Future<bool> isUploaded(String key) async => (await _keys()).contains(key);

  Future<void> markUploaded(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _keys();
    keys.add(key);
    await prefs.setStringList(_uploadedKeys, keys.toList()..sort());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uploadedKeys);
  }
}
