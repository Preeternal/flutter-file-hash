# Contributing

## Setup

Initialize submodules:

```bash
git submodule update --init --recursive
```

Install dependencies:

```bash
fvm flutter pub get
```

## Fast Checks

```bash
fvm flutter analyze
fvm flutter test
```

## Platform Smoke Builds

From macOS:

```bash
scripts/build-zig-android.sh
cd example && fvm flutter build apk --debug
```

```bash
cd example && fvm flutter build ios --debug --no-codesign
```

```bash
cd example && fvm flutter build macos --debug
```

Linux and Windows Flutter app builds should run on their own host OS. The CI
workflow has dedicated jobs for them.

## Prebuilt Matrix

```bash
scripts/build-zig-android.sh
scripts/build-zig-ios.sh
scripts/build-zig-macos.sh
scripts/build-zig-linux.sh
scripts/build-zig-windows.sh
scripts/check-prebuilts.sh
```

The generated artifacts live under `third_party/zig-files-hash-prebuilt/` and
are ignored in git.

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
