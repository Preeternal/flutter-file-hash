import 'dart:io';

import 'package:flutter_file_hash/flutter_file_hash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _sha256Abc =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hashes the reference vector on the target platform', (
    tester,
  ) async {
    expect(stringHash('abc', algorithm: HashAlgorithm.sha256), _sha256Abc);

    final tempDir = await Directory.systemTemp.createTemp(
      'flutter_file_hash_smoke_',
    );
    try {
      final file = File.fromUri(tempDir.uri.resolve('input.txt'));
      await file.writeAsString('abc');
      expect(
        await fileHash(file.path, algorithm: HashAlgorithm.sha256),
        _sha256Abc,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }

    // Keep a clear marker in CI logs in addition to the test assertion.
    // ignore: avoid_print
    print('FILE_HASH_FLUTTER_SMOKE_PASS');
  });
}
