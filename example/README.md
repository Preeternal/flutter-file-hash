# flutter_file_hash_example

Example app for [`flutter_file_hash`](https://pub.dev/packages/flutter_file_hash).

The app demonstrates the public API and the native file paths that matter for
real Flutter applications:

- selecting a file and hashing it with `fileHash`;
- Android `content://` input through the Android picker bridge;
- hashing strings with `stringHash`;
- SHA, MD5, HMAC, BLAKE3, keyed BLAKE3, and seeded XXH3-64;
- cooperative cancellation for long-running hashes;
- benchmark runs with copyable results.

Run from the repository checkout:

```bash
cd example
flutter run
```

Maintainer setup and platform-specific smoke commands are documented in the
package [CONTRIBUTING.md](../CONTRIBUTING.md).
