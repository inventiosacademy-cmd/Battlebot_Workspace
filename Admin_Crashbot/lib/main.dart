import 'package:flutter/material.dart';

import 'package:rc_camera_server/core/theme/app_theme.dart';
import 'package:rc_camera_server/features/broadcaster/presentation/pages/broadcaster_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:rc_camera_server/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AdminCrashbotApp());
}

/// Root application widget for Admin Crashbot.
class AdminCrashbotApp extends StatelessWidget {
  const AdminCrashbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Crashbot',
      theme: AppTheme.darkTheme,
      home: const BroadcasterPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
