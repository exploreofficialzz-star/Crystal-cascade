# Push Crystal Cascade Production to GitHub

This repository is now a Godot 4.6 Android production project. The original Flutter project is preserved under `reference/flutter_original/` as the migration/source reference.

## 1. Replace the repository contents

For a repository that will run this Godot build, the files in this package should be at the **repository root** (so `project.godot` is at the root).

Do not commit any `.jks`/`.keystore` file or passwords.

## 2. Keep these GitHub Actions secrets

- `KEYSTORE_BASE64` — base64 contents of the release `.jks`
- `KEYSTORE_PASSWORD` — keystore password
- `KEY_ALIAS` — release key alias
- `KEY_PASSWORD` — release key password

The workflow decodes the keystore only during the build and deletes it afterward.

## 3. Build

Push to `main`/`master`, or use **Actions → Android CI/CD Build → Run workflow**.

The workflow produces both:

- `crystal-cascade-apk` — signed APK for direct device testing
- `crystal-cascade-aab` — signed AAB for Google Play Console

A push to `main`/`master` also creates a GitHub Release containing both files.
