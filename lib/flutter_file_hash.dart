/// Native streaming file and string hashing for Flutter.
///
/// The package exposes a small Dart API over the shared Zig hashing core used
/// by `flutter_file_hash`.
library;

export 'src/flutter_file_hash_base.dart'
    show fileHash, stringHash, xxh3SeedFromLabel;
export 'src/hash_algorithm.dart' show HashAlgorithm;
export 'src/hash_cancellation.dart'
    show
        FlutterFileHashCancelledException,
        HashCancellationController,
        HashCancellationToken;
export 'src/hash_exception.dart' show FlutterFileHashException;
export 'src/hash_options.dart' show HashInputEncoding, HashOptions, KeyEncoding;
