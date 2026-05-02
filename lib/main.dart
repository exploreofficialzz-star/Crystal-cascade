import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'providers/game_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'services/admob_service.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await StorageService().init();
  await AdMobService().init();
  await AudioService().init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1a1a2e),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CrystalCascadeApp());
}

class CrystalCascadeApp extends StatelessWidget {
  const CrystalCascadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Crystal Cascade',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1a1a2e),
          colorScheme: const ColorScheme.dark(
            primary: Colors.purpleAccent,
            secondary: Colors.blueAccent,
            surface: Color(0xFF16213e),
            background: Color(0xFF1a1a2e),
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            displaySmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
