# Crystal Cascade architecture

The Flutter project and Godot project are intentionally not two runtimes shipped together.

- `reference/flutter_original/` = the complete original Flutter source kept as the source-of-truth reference for gameplay/economy/services and as a rollback/reference archive.
- Godot = the production runtime and renderer for the new 3D game.
- `scripts/services/android_platform.gd` = the native Android bridge for AdMob and Google Play Billing.
- `config/production.gd` = production identifiers.
- `addons/AdmobPlugin/android_export.cfg` = AdMob release App ID configuration.
- `.github/workflows/android-production.yml` = reproducible APK/AAB build path.

This avoids shipping Flutter's old renderer beside the new Godot renderer, while retaining every important Flutter source asset/service as a migration reference.
