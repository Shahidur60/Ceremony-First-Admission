import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// --- GLOBAL APP STATE ---
class AppState extends ChangeNotifier {
  late Api api;
  UserProfile? me;

  AppState(String baseUrl) {
    api = Api(baseUrl);
  }

  void setMe(UserProfile u) {
    me = u;
    notifyListeners();
  }

  void logout() {
    me = null;
    notifyListeners();
  }
}

/// --- MAIN ENTRY POINT ---
void main() {
  // ⚙️ Emulator = 10.0.2.2 | Real Device = <Your-PC-IP>
  const serverBase = String.fromEnvironment(
    'SERVER_BASE',
    defaultValue: 'http://10.247.86.73:4000',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(serverBase),
      child: const CeremonyApp(),
    ),
  );
}

/// --- ROOT APP WIDGET ---
class CeremonyApp extends StatelessWidget {
  const CeremonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ceremony Chat',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
      // If user already logged in, go directly to Home
      initialRoute: app.me == null ? '/' : '/home',
    );
  }
}
