import 'package:flutter/services.dart';

/// Tells us whether this install came from the Google Play Store or was
/// sideloaded (direct APK, third-party store, ADB install, etc).
///
/// This matters for billing: Play Store policy requires Play Billing for
/// digital goods purchased through that channel, but a sideloaded install
/// was never subject to that channel's billing pipeline in the first place
/// — Play Billing calls in that case usually fail outright (no Play Store
/// account context on the device) or misbehave, so those installs need an
/// alternative processor. Detection uses the standard Android
/// installer-package-name check, resolved natively since it needs a
/// platform channel either way.
class InstallSourceService {
  static final InstallSourceService _instance = InstallSourceService._internal();
  factory InstallSourceService() => _instance;
  InstallSourceService._internal();

  static const _channel = MethodChannel('com.chastechgroup.crystalcascade/install_source');
  static const _playStorePackage = 'com.android.vending';

  bool? _isPlayStoreInstallCache;

  /// True if installed via Google Play. False for sideloaded/unknown/iOS.
  /// Result is cached after the first (real) lookup.
  Future<bool> get isPlayStoreInstall async {
    if (_isPlayStoreInstallCache != null) return _isPlayStoreInstallCache!;

    try {
      final installer = await _channel.invokeMethod<String>('getInstallerPackageName');
      _isPlayStoreInstallCache = installer == _playStorePackage;
    } on PlatformException {
      // iOS, or channel unavailable for some other reason — not a Play
      // Store install by definition, so the Paystack fallback path applies.
      _isPlayStoreInstallCache = false;
    } on MissingPluginException {
      _isPlayStoreInstallCache = false;
    }

    return _isPlayStoreInstallCache!;
  }

  /// Call once at app startup (e.g. alongside other service init in
  /// main.dart) so the first real purchase tap doesn't wait on a platform
  /// channel round-trip.
  Future<void> warmUp() async => isPlayStoreInstall;
}
