import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import 'package:my_flutter_app/firebase_options.dart';
import 'package:my_flutter_app/core/constants/app_routes.dart';
import 'package:my_flutter_app/core/theme/app_theme.dart';
import 'package:my_flutter_app/core/services/network_manager.dart';
import 'package:my_flutter_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_flutter_app/features/auth/presentation/pages/login_page.dart';
import 'package:my_flutter_app/features/auth/presentation/pages/splash_page.dart';
import 'package:my_flutter_app/features/lobby/presentation/pages/lobby_page.dart';
import 'package:my_flutter_app/features/remote/presentation/providers/control_provider.dart';
import 'package:my_flutter_app/features/remote/presentation/pages/remote_page.dart';
import 'package:my_flutter_app/features/profile/presentation/providers/profile_provider.dart';

import 'package:my_flutter_app/core/services/audio_manager.dart';
import 'package:my_flutter_app/features/lobby/presentation/pages/matchmaking_room_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Firebase RTDB URL for native dual-network sending
  const firebaseDbUrl = 'https://rc-firebase-e7c09-default-rtdb.firebaseio.com';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => AudioManager()),
        ChangeNotifierProvider(
          create: (_) => NetworkManager(firebaseDatabaseUrl: firebaseDbUrl),
        ),
        // ControlProvider depends on NetworkManager for dual-network sending
        ChangeNotifierProxyProvider<NetworkManager, ControlProvider>(
          create: (_) => ControlProvider(),
          update: (_, networkManager, controlProvider) {
            controlProvider!.attachNetworkManager(networkManager);
            return controlProvider;
          },
        ),
      ],
      child: const CrashbotApp(),
    ),
  );
}

/// Root application widget for Crashbot Indonesia.
class CrashbotApp extends StatelessWidget {
  const CrashbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crashbot Indonesia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashPage(),
      routes: {
        AppRoutes.login: (_) => const LoginPage(),
        AppRoutes.lobby: (_) => const LobbyPage(),
        AppRoutes.matchmaking: (_) => const MatchmakingRoomPage(),
        AppRoutes.remote: (_) => const RemotePage(),
      },
    );
  }
}

/// Switches between Login and Lobby based on authentication state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isAuthenticated) {
      return const LobbyPage();
    }
    return const LoginPage();
  }
}
