# Contributing

## Setup

Use Flutter stable, Zig, and the platform SDKs for the targets you want to
build. The CI Zig version is defined in
`.github/actions/setup-zig/action.yml`.

If you do not use FVM locally, replace `fvm flutter` and `fvm dart` with
`flutter` and `dart`.

Initialize the Zig submodule:

```bash
git submodule update --init --recursive
```

Install package dependencies:

```bash
fvm flutter pub get
```

Install example app dependencies:

```bash
cd example
fvm flutter pub get
```

## Contributor Notes

The package uses the streaming C ABI from `zig-files-hash`.

```text
Dart API
  -> Dart FFI for filesystem paths and strings
  -> Android MethodChannel only for URI openers
    -> Kotlin InputStream
    -> JNI bridge
  -> zig-files-hash C ABI
    -> zfh_hasher_init_inplace
    -> zfh_hasher_update
    -> zfh_hasher_final
```

One-shot C ABI helpers are intentionally not used. File hashing and string
hashing should go through the streaming hasher path.

Android is the only platform with a platform opener today. It is needed for
`content://` inputs because `dart:io File` cannot open them. The Android path
streams from `ContentResolver.openInputStream` into the same Zig hasher and must
not copy URI data into a temporary file as part of normal hashing.

Provider-backed iOS/macOS URLs are not handled by a platform opener yet. Current
Apple platform support is for normal filesystem paths through Dart FFI.

Temporary planning notes should live under `docs/tmp-*` or `docs/**/tmp-*`.
Those paths are ignored by git.

## Fast Checks

Run these before opening a PR:

```bash
fvm dart format --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
```

## Running During Development

Application builds load ready native artifacts through `hook/build.dart`.
Published pub.dev packages must include those artifacts, so package users do not
need Zig in `PATH`.

Maintainers can generate the artifacts locally or in CI with the
`scripts/build-zig-*.sh` commands. A source checkout only needs Zig when the
prebuilt artifacts have not been generated yet.

Android has one additional requirement: the URI bridge is a JNI library built by
Gradle/CMake, and it links static Zig archives from
`third_party/zig-files-hash-prebuilt/android`. Generate those archives before
building the Android example.

Use Flutter's device list as the source of truth for target ids:

```bash
cd example
fvm flutter devices
```

Use `flutter run` for interactive testing on simulators, emulators, phones, and
desktop targets. Use `flutter build` for packaging smoke checks.

### Android

Android emulator or USB device:

```bash
scripts/build-zig-android.sh
cd example
fvm flutter devices
fvm flutter run -d <android-device-id>
```

To launch an installed emulator first:

```bash
cd example
fvm flutter emulators
fvm flutter emulators --launch <emulator-id>
fvm flutter run -d <android-device-id>
```

Android release run on a connected emulator or device:

```bash
scripts/build-zig-android.sh
cd example
fvm flutter run --release -d <android-device-id>
```

Android packaging smoke:

```bash
scripts/build-zig-android.sh
cd example
fvm flutter build apk --debug
fvm flutter build apk --release
fvm flutter build appbundle --release
```

Runtime check for Android should include a real `content://` URI once the
example app exposes picker UI.

### iOS

iOS simulator:

```bash
cd example
open -a Simulator
fvm flutter devices
fvm flutter run -d <ios-simulator-id>
```

iOS physical device:

```bash
cd example
fvm flutter devices
fvm flutter run -d <ios-device-id>
```

Physical iOS devices require normal Apple development signing. Configure signing
locally in Xcode if needed, but do not commit personal `DEVELOPMENT_TEAM`,
provisioning profile, or signing identity changes from the example project.

iOS packaging smoke without signing:

```bash
cd example
fvm flutter build ios --debug --no-codesign
fvm flutter build ios --release --no-codesign
```

iOS simulator is for debug/profile style runtime checks. Release installation is
a signed device or archive concern, not a simulator check.

### macOS

macOS run:

```bash
fvm flutter config --enable-macos-desktop
cd example
fvm flutter run -d macos
```

macOS packaging smoke:

```bash
fvm flutter config --enable-macos-desktop
cd example
fvm flutter build macos --debug
fvm flutter build macos --release
```

### Linux

Install Flutter desktop build prerequisites for the host distribution first.
The CI Ubuntu job installs:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
```

Linux run:

```bash
fvm flutter config --enable-linux-desktop
cd example
fvm flutter run -d linux
```

Linux packaging smoke:

```bash
fvm flutter config --enable-linux-desktop
cd example
fvm flutter build linux --debug
fvm flutter build linux --release
```

### Windows

Run Windows builds on a Windows host with the Flutter Windows desktop toolchain
installed.

Windows run:

```powershell
flutter config --enable-windows-desktop
cd example
flutter run -d windows
```

Windows packaging smoke:

```powershell
flutter config --enable-windows-desktop
cd example
flutter build windows --debug
flutter build windows --release
```

## Native Prebuilt Matrix

Generated artifacts live under `third_party/zig-files-hash-prebuilt/`. They are
ignored in git, but release CI generates them before `dart pub publish`.
`.pubignore` intentionally keeps that directory publishable.

These scripts are for maintainer verification and release staging:

```bash
scripts/build-zig-android.sh
scripts/build-zig-ios.sh
scripts/build-zig-macos.sh
scripts/build-zig-linux.sh
scripts/build-zig-windows.sh
scripts/check-prebuilts.sh
```

Expected outputs:

| Platform | Artifact |
| --- | --- |
| Android | `android/<abi>/libzig_files_hash.a` for JNI and `android/<abi>/libzig_files_hash_c_api.so` for Dart FFI |
| iOS | `ios/ZigFilesHash.xcframework` plus `ios/ios-arm64/libzig_files_hash_c_api.dylib` and `ios/ios-simulator-universal/libzig_files_hash_c_api.dylib` |
| macOS | `macos/ZigFilesHash.xcframework` plus `macos/universal/libzig_files_hash_c_api.dylib` |
| Linux | `linux/<arch>/libzig_files_hash_c_api.so` |
| Windows | `windows/<arch>/zig_files_hash_c_api.dll` |

## Release Model

The intended release model is that app developers add the Flutter package and
build their app normally. They should not need to install Zig or run scripts
from this repository.

The release flow follows the same principle as `react-native-file-hash`: create
and publish a GitHub Release for a version tag, then GitHub Actions publishes
the package. Publishing is triggered by `release.published`, not by plain tag
push.

The first pub.dev release must be published manually by a package owner. After
that, configure pub.dev automated publishing / trusted publisher for this
repository and `.github/workflows/pub-publish.yml`.

Release CI:

- checks that `pubspec.yaml` version matches the GitHub Release tag;
- runs format, analyze, and tests;
- builds the full native prebuilt matrix;
- checks required artifacts with `scripts/check-prebuilts.sh`;
- validates pub.dev inputs with `scripts/check-pub-prebuilts.sh`;
- publishes with `dart pub publish --force`.

Before tagging a release:

- run the platform smoke builds for the release targets;
- verify Android `content://` streaming at runtime;
- verify the example app on at least one desktop or Apple platform.

## CI

The GitHub Actions workflow mirrors the expected platform checks:

- package format, analyze, and tests on Ubuntu;
- Android debug example build on Ubuntu;
- iOS debug example build on macOS without codesigning;
- macOS debug example build on macOS;
- Linux debug example build on Ubuntu;
- Windows debug example build on Windows;
- native prebuilt matrix verification on macOS.

Keep local commands and CI in sync when changing native packaging.

## Manual QA Checklist

Use the example app to verify user-visible behavior before release.

String hashing:

- start the example app;
- keep `SHA-256`;
- hash `abc`;
- expect:

```text
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
```

File hashing:

- press `Hash sample file`;
- verify that a digest appears and no exception is shown;
- press `Cancel` while hashing a larger sample or slower debug build;
- verify that cancellation reports a cancelled operation rather than a generic
  I/O failure.

Options:

- select an HMAC algorithm and hash with a key;
- select an HMAC algorithm without a key and verify that validation fails;
- select `BLAKE3` with a non-32-byte key and verify that validation fails;
- select `XXH3-64` and hash with the seeded value shown by the example.

Android URI runtime check:

- build and install the Android example;
- pick or pass a real `content://` URI from the Android document picker once the
  example has picker UI;
- verify that hashing streams from `ContentResolver` directly;
- verify that no temporary copy is created as part of the hash path.

iOS/macOS follow-up:

- current public API handles normal filesystem paths through Dart FFI;
- provider-backed URLs may later need a platform opener similar to Android if
  the app starts accepting security-scoped or iCloud-backed URLs directly.
