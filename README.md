# Crystal Cascade

**Crystal Cascade** is a premium hybrid casual puzzle game built with Flutter. Sort beautiful realistic crystal gems by color to clear the board and complete levels. Inspired by top-grossing games like Color Block Jam, but with enhanced 3D-style realistic visuals.

## Game Features

- **100 Progressive Levels** - From easy 3-tube puzzles to challenging 8-tube brain teasers
- **Realistic Crystal Gems** - 7 stunning gem types (Ruby, Sapphire, Emerald, Citrine, Amethyst, Topaz, Diamond)
- **3-Star Rating System** - Earn stars based on moves remaining
- **Lives System** - Strategic gameplay with life regeneration
- **Coins & Shop** - Earn coins to buy hints and extra moves
- **Combo System** - Chain matches for bonus points

## Monetization (AdMob Integrated)

- **Banner Ads** - Professional placement on home and game screens
- **Interstitial Ads** - Shown between levels (not intrusive)
- **Rewarded Video Ads** - Optional ads for free coins, extra moves, and lives
- **In-App Purchases** - Remove ads, coin packs, mega packs
- **Daily Rewards** - Free daily coin bonuses

## Tech Stack

- **Flutter 3.22+** - Cross-platform mobile framework
- **Dart** - Programming language
- **google_mobile_ads** - AdMob integration
- **audioplayers** - Sound effects and music
- **provider** - State management
- **shared_preferences** - Local data persistence
- **confetti** - Celebration effects
- **shimmer** - Loading/premium UI effects

## Project Structure

```
crystal_cascade/
├── android/           # Android build configuration
├── ios/               # iOS build configuration
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models (Gem, Level)
│   ├── providers/             # State management (GameProvider, SettingsProvider)
│   ├── screens/               # UI screens
│   │   ├── splash_screen.dart      # "by chAs" splash
│   │   ├── home_screen.dart        # Main menu
│   │   ├── game_screen.dart        # Gameplay
│   │   ├── level_select_screen.dart
│   │   ├── game_over_screen.dart
│   │   ├── settings_screen.dart
│   │   └── shop_screen.dart
│   ├── services/              # Business logic
│   │   ├── admob_service.dart
│   │   ├── audio_service.dart
│   │   └── storage_service.dart
│   ├── utils/                 # Constants, level generation
│   └── widgets/               # Reusable UI components
│       ├── gem_widget.dart
│       ├── tube_widget.dart
│       ├── particle_effect.dart
│       └── ad_banner_widget.dart
├── assets/
│   ├── images/          # Game assets (gems, backgrounds, logo)
│   └── sounds/          # Audio assets
└── .github/workflows/   # CI/CD automation
```

## Getting Started

### Prerequisites

- Flutter SDK 3.22.0 or higher
- Android Studio / Xcode
- JDK 17 (for Android builds)
- CocoaPods (for iOS builds)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/crystal_cascade.git
   cd crystal_cascade
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure AdMob IDs**
   - Replace test AdMob IDs in `lib/utils/constants.dart` with your production IDs
   - Update Android `AndroidManifest.xml` with your App ID
   - Update iOS `Info.plist` with your App ID

4. **Run the app**
   ```bash
   flutter run
   ```

### Building for Production

**Android:**
```bash
flutter build apk --release
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## CI/CD (GitHub Actions)

The project includes automated CI/CD workflows:

- **`.github/workflows/android.yml`** - Builds APK and AAB on every push
- **`.github/workflows/ios.yml`** - Builds IPA on macOS runner

Both workflows:
- Run on push to `main`, `master`, or `develop`
- Execute flutter analyze and tests
- Upload build artifacts
- Create GitHub releases automatically

## AdMob Configuration

### Before Release - IMPORTANT:

1. Create an AdMob account at https://apps.admob.com
2. Create an app and get your **App ID**
3. Create ad units and get your **Ad Unit IDs**
4. Replace the test IDs in these files:
   - `lib/utils/constants.dart` (banner, interstitial, rewarded IDs)
   - `android/app/src/main/AndroidManifest.xml` (Android App ID)
   - `ios/Runner/Info.plist` (iOS App ID)

### AdMob Test IDs (for development):
- App ID: `ca-app-pub-3940256099942544~3347511713`
- Banner: `ca-app-pub-3940256099942544/6300978111`
- Interstitial: `ca-app-pub-3940256099942544/1033173712`
- Rewarded: `ca-app-pub-3940256099942544/5224354917`

## Package Name

- **Android:** `com.chastechgroup.crystalcascade`
- **iOS Bundle ID:** `com.chastechgroup.crystalcascade`

## Splash Screen

The splash screen displays the game logo with the developer tag **"by chAs"**.

## License

This project is proprietary. All rights reserved by chAs Tech Group.

## Developer

**chAs Tech Group**
- Developer Tag: `by chAs`
- Package: `com.chastechgroup.crystalcascade`
