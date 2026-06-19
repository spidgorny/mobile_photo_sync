import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'screens/login_screen.dart';
import 'services/background_sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher);
  runApp(const PhotoSyncApp());
}

class PhotoSyncApp extends StatelessWidget {
  const PhotoSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Sync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
