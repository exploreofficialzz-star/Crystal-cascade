import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'services/adblock_service.dart';
import 'services/admob_service.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/install_source_service.dart';
import 'services/network_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'widgets/adblock_overlay.dart';
import 'widgets/network_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Core services ──────────────────────────────────────────────────────────
  await StorageService().init();
  await AdMobService().init();
  await AudioService().init();

  // ── Notifications (non-blocking) ───────────────────────────────────────────
  NotificationService().init();

  // ── Network awareness ──────────────────────────────────────────────────────
  await NetworkService().init();

  // ── Install source (Play Store vs sideloaded) — needed before IAP ─────────
  await InstallSourceService().warmUp();

  // ── In-App Purchases (non-blocking) ───────────────────────────────────────
  IAPService().init();

  // ── Ad-block detection ────────────────────────────────────────────────────
  AdBlockService().init();

  // ── UI preferences ────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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

// ── Stateful so we can observe app lifecycle globally ─────────────────────────
// This is the ONLY place BGM pause/resume is handled — no per-screen conflicts.
class CrystalCascadeApp extends StatefulWidget {
  const CrystalCascadeApp({super.key});
  @override
  State<CrystalCascadeApp> createState() => _CrystalCascadeAppState();
}

class _CrystalCascadeAppState extends State<CrystalCascadeApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fires for EVERY screen — home, game, game over, shop, etc.
  /// Eliminates the gap where BGM kept playing on GameOverScreen exit.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:   // Android 14+ / iOS 13+
        AudioService().pauseBGM();
      case AppLifecycleState.resumed:
        AudioService().resumeBGM();
      case AppLifecycleState.inactive:
        // inactive fires on dialogs/notifications — don't pause here
        break;
    }
  }

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
            surface: Color(0xFF1a1a2e),
          ),
          textTheme: const TextTheme(
            displayLarge:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            displayMedium:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            displaySmall:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            headlineMedium:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            titleLarge:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
          ),
        ),
        builder: (context, child) => NetworkOverlay(
          child: AdBlockOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
