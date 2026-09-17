# Production build

## Recommended for mobile-only development
Use the included GitHub Actions workflow. It downloads the pinned Godot SDK plugins during the build, so you do not need to manually copy native plugin binaries into the repository.

1. Put the project in GitHub.
2. In GitHub: Settings → Secrets and variables → Actions.
3. Add your release keystore as a secret/file according to your chosen CI secret strategy, plus `KEYSTORE_PATH`, `KEY_ALIAS`, and `KEYSTORE_PASSWORD`.
4. Run **Actions → Android Production**.
5. Choose `apk` for direct device testing or `aab` for Google Play.
6. Download the artifact from the workflow run.

## Local Godot 4.6
1. Install Godot 4.6.
2. Open this project.
3. Install the Gradle Android Build Template.
4. Install/enable AdMob v6.0 and Google Play Billing 3.3.0.
5. Project → Export → Android.
6. Gradle Build must remain enabled.
7. Select Release signing.
8. Export APK or AAB.

Godot's official Android export documentation states that AAB export uses the Gradle build path and requires a non-debug release keystore. Google Play currently requires new apps and updates to target API 36 or higher from August 31, 2026.

## Important
Never commit a release keystore or passwords. Never test by clicking live production ads; use test ads until the release candidate is ready.
