import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_hash/flutter_file_hash.dart';

void main() {
  runApp(const HashExampleApp());
}

class HashExampleApp extends StatelessWidget {
  const HashExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2563eb);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        inputDecorationTheme: _inputTheme(Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff7dd3fc),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: _inputTheme(Brightness.dark),
        useMaterial3: true,
      ),
      home: const HashDemoPage(),
    );
  }
}

InputDecorationTheme _inputTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final borderColor = isDark
      ? const Color(0xff1f242e)
      : const Color(0xffe5e7eb);
  final fillColor = isDark ? const Color(0xff11151d) : const Color(0xfff5f7fb);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: borderColor),
  );

  return InputDecorationTheme(
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: isDark ? const Color(0xff7dd3fc) : const Color(0xff2563eb),
        width: 1.4,
      ),
    ),
    filled: true,
    fillColor: fillColor,
    isDense: true,
  );
}

const MethodChannel _androidFilePickerChannel = MethodChannel(
  'flutter_file_hash_example/file_picker',
);

class HashDemoPage extends StatefulWidget {
  const HashDemoPage({super.key});

  @override
  State<HashDemoPage> createState() => _HashDemoPageState();
}

class _HashDemoPageState extends State<HashDemoPage> {
  static const List<HashAlgorithm> _algorithms = [
    HashAlgorithm.md5,
    HashAlgorithm.sha1,
    HashAlgorithm.sha224,
    HashAlgorithm.sha256,
    HashAlgorithm.sha384,
    HashAlgorithm.sha512,
    HashAlgorithm.sha512_224,
    HashAlgorithm.sha512_256,
    HashAlgorithm.xxh3_64,
    HashAlgorithm.blake3,
    HashAlgorithm.hmacSha224,
    HashAlgorithm.hmacSha256,
    HashAlgorithm.hmacSha384,
    HashAlgorithm.hmacSha512,
    HashAlgorithm.hmacMd5,
    HashAlgorithm.hmacSha1,
  ];

  static const List<HashAlgorithm> _benchmarkAlgorithms = [
    HashAlgorithm.sha256,
    HashAlgorithm.md5,
    HashAlgorithm.sha1,
    HashAlgorithm.sha224,
    HashAlgorithm.sha384,
    HashAlgorithm.sha512,
    HashAlgorithm.sha512_224,
    HashAlgorithm.sha512_256,
    HashAlgorithm.hmacSha224,
    HashAlgorithm.hmacSha256,
    HashAlgorithm.hmacSha384,
    HashAlgorithm.hmacSha512,
    HashAlgorithm.hmacMd5,
    HashAlgorithm.hmacSha1,
    HashAlgorithm.blake3,
    HashAlgorithm.xxh3_64,
  ];

  static const String _benchmarkKey = 'react-native-file-hash-benchmark-key';

  final TextEditingController _textController = TextEditingController(
    text: 'hello world',
  );
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _seedLabelController = TextEditingController();
  final TextEditingController _seedValueController = TextEditingController();
  final TextEditingController _benchmarkSizeController = TextEditingController(
    text: '200',
  );
  final TextEditingController _benchmarkSamplesController =
      TextEditingController(text: '3');
  final TextEditingController _benchmarkWarmupsController =
      TextEditingController(text: '1');

  HashAlgorithm _selectedAlgorithm = HashAlgorithm.sha256;
  HashInputEncoding _textEncoding = HashInputEncoding.utf8;
  KeyEncoding _keyEncoding = KeyEncoding.utf8;
  _SeedInputMode _seedInputMode = _SeedInputMode.fromLabel;
  bool _useMmap = false;

  _PickedFile? _pickedFile;

  String _fileHash = '';
  String? _fileStatus;
  int? _fileElapsedMs;
  bool _fileRunning = false;
  HashCancellationController? _fileCancellation;

  String _textHash = '';
  String? _textStatus;
  int? _textElapsedMs;
  bool _textRunning = false;
  HashCancellationController? _textCancellation;

  String? _benchmarkStatus;
  bool _benchmarkRunning = false;
  List<_BenchmarkResult> _benchmarkResults = const [];
  HashCancellationController? _benchmarkCancellation;

  @override
  void dispose() {
    _fileCancellation?.cancel();
    _textCancellation?.cancel();
    _benchmarkCancellation?.cancel();
    _textController.dispose();
    _keyController.dispose();
    _seedLabelController.dispose();
    _seedValueController.dispose();
    _benchmarkSizeController.dispose();
    _benchmarkSamplesController.dispose();
    _benchmarkWarmupsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Header(palette: palette),
            const SizedBox(height: 12),
            _CardPanel(
              title: 'Benchmark',
              palette: palette,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useColumns = constraints.maxWidth >= 520;
                    final children = [
                      _BenchmarkField(
                        controller: _benchmarkSizeController,
                        label: 'Size MiB',
                      ),
                      _BenchmarkField(
                        controller: _benchmarkSamplesController,
                        label: 'Samples',
                      ),
                      _BenchmarkField(
                        controller: _benchmarkWarmupsController,
                        label: 'Warmups',
                      ),
                    ];

                    if (!useColumns) {
                      return Column(
                        children: [
                          for (final child in children) ...[
                            child,
                            if (child != children.last)
                              const SizedBox(height: 8),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        for (final child in children) ...[
                          Expanded(child: child),
                          if (child != children.last) const SizedBox(width: 8),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ActionRow(
                  primary: FilledButton.icon(
                    onPressed: _benchmarkRunning ? null : _runBenchmark,
                    icon: _benchmarkRunning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.speed),
                    label: const Text('Run benchmark'),
                  ),
                  secondary: _benchmarkRunning
                      ? OutlinedButton.icon(
                          onPressed: _cancelBenchmark,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                        )
                      : null,
                ),
                if (_benchmarkStatus != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _benchmarkStatus!,
                    style: TextStyle(color: palette.muted),
                  ),
                ],
                if (_benchmarkResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BenchmarkResultsBox(
                    palette: palette,
                    results: _benchmarkResults,
                    onCopy: _copyBenchmarkResults,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _CardPanel(
              title: '1. Algorithm',
              palette: palette,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final algorithm in _algorithms)
                      ChoiceChip(
                        label: Text(algorithm.label),
                        selected: _selectedAlgorithm == algorithm,
                        onSelected: (_) {
                          setState(() {
                            _selectedAlgorithm = algorithm;
                            _fileHash = '';
                            _textHash = '';
                            _fileElapsedMs = null;
                            _textElapsedMs = null;
                            _fileStatus = null;
                            _textStatus = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CardPanel(
              title: '2. Options',
              palette: palette,
              children: [
                if (_selectedAlgorithm.supportsSeed)
                  _SeedOptions(
                    mode: _seedInputMode,
                    labelController: _seedLabelController,
                    valueController: _seedValueController,
                    onModeChanged: (mode) {
                      setState(() {
                        _seedInputMode = mode;
                      });
                    },
                    seedPreview: _seedPreview(),
                  )
                else
                  _KeyOptions(
                    algorithm: _selectedAlgorithm,
                    controller: _keyController,
                    encoding: _keyEncoding,
                    onEncodingChanged: (encoding) {
                      setState(() {
                        _keyEncoding = encoding;
                      });
                    },
                  ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _useMmap,
                  onChanged: _fileRunning || _benchmarkRunning
                      ? null
                      : (value) {
                          setState(() {
                            _useMmap = value ?? false;
                            _fileHash = '';
                            _fileElapsedMs = null;
                            _fileStatus = null;
                            _benchmarkResults = const [];
                            _benchmarkStatus = null;
                          });
                        },
                  title: const Text('Use mmap for local files'),
                  subtitle: Text(
                    'Applies to Hash file and Benchmark. Use only stable local files; ignored for Android content:// URIs.',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CardPanel(
              title: '3. Pick a file',
              palette: palette,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose file'),
                  ),
                ),
                const SizedBox(height: 10),
                if (_pickedFile == null)
                  Text(
                    'No file selected',
                    style: TextStyle(color: palette.muted),
                  )
                else
                  _FileDetails(file: _pickedFile!, palette: palette),
              ],
            ),
            const SizedBox(height: 12),
            _CardPanel(
              title: '4. Hash file',
              palette: palette,
              children: [
                _ActionRow(
                  primary: FilledButton.icon(
                    onPressed: _pickedFile == null || _fileRunning
                        ? null
                        : _hashFile,
                    icon: _fileRunning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.insert_drive_file),
                    label: const Text('Hash file'),
                  ),
                  secondary: _fileRunning
                      ? OutlinedButton.icon(
                          onPressed: _cancelFileHash,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                if (_fileHash.isNotEmpty)
                  _DigestResult(
                    digest: _fileHash,
                    elapsedMs: _fileElapsedMs,
                    palette: palette,
                  )
                else
                  Text(
                    _fileStatus ?? 'Waiting for file hash',
                    style: TextStyle(color: palette.muted),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _CardPanel(
              title: '5. Hash string',
              palette: palette,
              children: [
                TextField(
                  controller: _textController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'hello world'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final encoding in HashInputEncoding.values)
                      ChoiceChip(
                        label: Text(encoding.label.toUpperCase()),
                        selected: _textEncoding == encoding,
                        onSelected: (_) {
                          setState(() {
                            _textEncoding = encoding;
                            _textHash = '';
                            _textElapsedMs = null;
                            _textStatus = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _ActionRow(
                  primary: FilledButton.icon(
                    onPressed: _textRunning ? null : _hashString,
                    icon: _textRunning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.tag),
                    label: const Text('Hash string'),
                  ),
                  secondary: _textRunning
                      ? OutlinedButton.icon(
                          onPressed: _cancelStringHash,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                if (_textHash.isNotEmpty)
                  _DigestResult(
                    digest: _textHash,
                    elapsedMs: _textElapsedMs,
                    palette: palette,
                  )
                else
                  Text(
                    _textStatus ?? 'Waiting for string hash',
                    style: TextStyle(color: palette.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _seedPreview() {
    try {
      final seed = _buildSeed();
      return seed == null ? '' : seed.toString();
    } on FormatException catch (error) {
      return error.message;
    }
  }

  HashOptions? _buildHashOptions([HashAlgorithm? algorithm]) {
    final target = algorithm ?? _selectedAlgorithm;

    if (target.supportsSeed) {
      final seed = _buildSeed();
      return seed == null ? null : HashOptions(seed: seed);
    }

    if (target.requiresKey) {
      return HashOptions(key: _keyController.text, keyEncoding: _keyEncoding);
    }

    if (target.supportsKey && _keyController.text.isNotEmpty) {
      return HashOptions(key: _keyController.text, keyEncoding: _keyEncoding);
    }

    return null;
  }

  HashOptions? _buildBenchmarkOptions(HashAlgorithm algorithm) {
    if (!algorithm.requiresKey) {
      return null;
    }

    return const HashOptions(key: _benchmarkKey, keyEncoding: KeyEncoding.utf8);
  }

  Object? _buildSeed() {
    final raw = switch (_seedInputMode) {
      _SeedInputMode.fromLabel => _seedLabelController.text.trim(),
      _SeedInputMode.decimal => _seedValueController.text.trim(),
      _SeedInputMode.hex => _seedValueController.text.trim(),
    };

    if (raw.isEmpty) {
      return null;
    }

    return switch (_seedInputMode) {
      _SeedInputMode.fromLabel => xxh3SeedFromLabel(raw),
      _SeedInputMode.decimal => raw,
      _SeedInputMode.hex => raw.toLowerCase().startsWith('0x') ? raw : '0x$raw',
    };
  }

  Future<_PickedFile?> _pickFileSelectorFile() async {
    final file = await openFile();
    if (file == null) {
      return null;
    }

    final size = await file.length();
    final name = file.name.isEmpty ? _basename(file.path) : file.name;

    return _PickedFile(
      name: name,
      hashPath: file.path,
      displayPath: file.path,
      size: size,
    );
  }

  Future<_PickedFile?> _pickAndroidFile() async {
    final result = await _androidFilePickerChannel
        .invokeMapMethod<String, Object?>('pickFile');
    if (result == null) {
      return null;
    }

    final uri = result['uri'] as String?;
    if (uri == null || uri.isEmpty) {
      _showMessage('Picker did not return a readable URI');
      return null;
    }

    final name = result['name'] as String?;
    final size = result['size'];

    return _PickedFile(
      name: name == null || name.isEmpty ? uri : name,
      hashPath: uri,
      displayPath: uri,
      size: size is int && size > 0 ? size : 0,
    );
  }

  Future<void> _pickFile() async {
    try {
      final pickedFile = Platform.isAndroid
          ? await _pickAndroidFile()
          : await _pickFileSelectorFile();

      if (!mounted || pickedFile == null) {
        return;
      }

      setState(() {
        _pickedFile = pickedFile;
        _fileHash = '';
        _fileElapsedMs = null;
        _fileStatus = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_errorText(error));
    }
  }

  Future<void> _hashFile() async {
    final pickedFile = _pickedFile;
    if (pickedFile == null) {
      return;
    }

    final controller = HashCancellationController();
    _fileCancellation = controller;

    setState(() {
      _fileRunning = true;
      _fileHash = '';
      _fileElapsedMs = null;
      _fileStatus = 'Hashing file...';
    });

    try {
      final started = DateTime.now();
      final digest = await fileHash(
        pickedFile.hashPath,
        algorithm: _selectedAlgorithm,
        hashOptions: _buildHashOptions(),
        useMmap: _useMmap,
        cancellationToken: controller.token,
      );
      final elapsed = DateTime.now().difference(started).inMilliseconds;

      if (!mounted) {
        return;
      }

      setState(() {
        _fileHash = digest;
        _fileElapsedMs = elapsed;
        _fileStatus = null;
      });
    } on FlutterFileHashCancelledException {
      if (mounted) {
        setState(() {
          _fileStatus = 'Cancelled';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _fileStatus = 'Failed';
        });
        _showMessage(_errorText(error));
      }
    } finally {
      if (identical(_fileCancellation, controller)) {
        _fileCancellation = null;
      }
      if (mounted) {
        setState(() {
          _fileRunning = false;
        });
      }
    }
  }

  Future<void> _hashString() async {
    final controller = HashCancellationController();
    _textCancellation = controller;

    setState(() {
      _textRunning = true;
      _textHash = '';
      _textElapsedMs = null;
      _textStatus = 'Hashing string...';
    });

    try {
      final started = DateTime.now();
      final digest = await Future<String>(() {
        return stringHash(
          _textController.text,
          algorithm: _selectedAlgorithm,
          encoding: _textEncoding,
          hashOptions: _buildHashOptions(),
          cancellationToken: controller.token,
        );
      });
      final elapsed = DateTime.now().difference(started).inMilliseconds;

      if (!mounted) {
        return;
      }

      setState(() {
        _textHash = digest;
        _textElapsedMs = elapsed;
        _textStatus = null;
      });
    } on FlutterFileHashCancelledException {
      if (mounted) {
        setState(() {
          _textStatus = 'Cancelled';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _textStatus = 'Failed';
        });
        _showMessage(_errorText(error));
      }
    } finally {
      if (identical(_textCancellation, controller)) {
        _textCancellation = null;
      }
      if (mounted) {
        setState(() {
          _textRunning = false;
        });
      }
    }
  }

  Future<void> _runBenchmark() async {
    final sizeMiB = _parseBoundedInt(
      _benchmarkSizeController.text,
      fallback: 200,
      min: 1,
      max: 4096,
    );
    final samples = _parseBoundedInt(
      _benchmarkSamplesController.text,
      fallback: 3,
      min: 1,
      max: 20,
    );
    final warmups = _parseBoundedInt(
      _benchmarkWarmupsController.text,
      fallback: 1,
      min: 0,
      max: 5,
    );
    final useMmap = _useMmap;
    final sizeBytes = sizeMiB * 1024 * 1024;
    final controller = HashCancellationController();
    final results = <_BenchmarkResult>[];
    Directory? tempDir;

    _benchmarkCancellation = controller;
    setState(() {
      _benchmarkRunning = true;
      _benchmarkResults = const [];
      _benchmarkStatus =
          'Preparing $sizeMiB MiB file (${useMmap ? 'mmap' : 'stream'} I/O)...';
    });

    try {
      tempDir = await Directory.systemTemp.createTemp(
        'flutter_file_hash_benchmark_',
      );
      final file = File.fromUri(tempDir.uri.resolve('benchmark.bin'));
      await _writeBenchmarkFile(file, sizeBytes, controller.token);

      for (final algorithm in _benchmarkAlgorithms) {
        controller.token.throwIfCancelled();
        if (!mounted) {
          return;
        }

        setState(() {
          _benchmarkStatus = 'Benchmarking ${algorithm.label}...';
        });

        try {
          final samplesMs = <int>[];
          String? digestPrefix;
          final totalRuns = samples + warmups;

          for (var run = 0; run < totalRuns; run += 1) {
            controller.token.throwIfCancelled();
            final started = DateTime.now();
            final digest = await fileHash(
              file.path,
              algorithm: algorithm,
              hashOptions: _buildBenchmarkOptions(algorithm),
              useMmap: useMmap,
              cancellationToken: controller.token,
            );
            final elapsed = DateTime.now().difference(started).inMilliseconds;
            digestPrefix = digest.substring(0, math.min(16, digest.length));

            if (run >= warmups) {
              samplesMs.add(elapsed);
            }
          }

          results.add(
            _BenchmarkResult(
              algorithm: algorithm,
              samplesMs: samplesMs,
              digestPrefix: digestPrefix,
            ),
          );
        } catch (error) {
          controller.token.throwIfCancelled();
          results.add(
            _BenchmarkResult(
              algorithm: algorithm,
              samplesMs: const [],
              error: _errorText(error),
            ),
          );
        }

        if (mounted) {
          setState(() {
            _benchmarkResults = List<_BenchmarkResult>.of(results);
          });
        }
      }

      final payload = {
        'version': 1,
        'platform': Platform.operatingSystem,
        'engine': 'zig',
        'sizeBytes': sizeBytes,
        'sizeMiB': sizeMiB,
        'samples': samples,
        'warmups': warmups,
        'useMmap': useMmap,
        'algorithms': [
          for (final algorithm in _benchmarkAlgorithms) algorithm.label,
        ],
        'results': [for (final result in results) result.toJson()],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      debugPrint('ZFH_BENCHMARK_RESULT ${convert.jsonEncode(payload)}');

      if (mounted) {
        setState(() {
          _benchmarkStatus =
              'Benchmark complete (${useMmap ? 'mmap' : 'stream'} I/O)';
        });
      }
    } on FlutterFileHashCancelledException {
      debugPrint('ZFH_BENCHMARK_CANCELLED');
      if (mounted) {
        setState(() {
          _benchmarkStatus = 'Benchmark cancelled';
        });
      }
    } catch (error) {
      debugPrint('ZFH_BENCHMARK_FAILED ${_errorText(error)}');
      if (mounted) {
        setState(() {
          _benchmarkStatus = 'Benchmark failed';
        });
        _showMessage(_errorText(error));
      }
    } finally {
      try {
        await tempDir?.delete(recursive: true);
      } on FileSystemException {
        // Temporary benchmark files can already be removed by the platform.
      }

      if (identical(_benchmarkCancellation, controller)) {
        _benchmarkCancellation = null;
      }
      if (mounted) {
        setState(() {
          _benchmarkRunning = false;
        });
      }
    }
  }

  Future<void> _writeBenchmarkFile(
    File file,
    int sizeBytes,
    HashCancellationToken cancellationToken,
  ) async {
    final chunk = Uint8List(1024 * 1024);
    for (var i = 0; i < chunk.length; i += 1) {
      chunk[i] = i & 0xff;
    }

    final sink = file.openWrite();
    var remaining = sizeBytes;

    try {
      while (remaining > 0) {
        cancellationToken.throwIfCancelled();
        final length = math.min(chunk.length, remaining);
        sink.add(Uint8List.sublistView(chunk, 0, length));
        remaining -= length;
        if (remaining % (16 * 1024 * 1024) == 0) {
          await sink.flush();
        }
      }
    } finally {
      await sink.close();
    }
  }

  void _cancelFileHash() {
    setState(() {
      _fileStatus = 'Cancelling...';
    });
    _fileCancellation?.cancel('Cancelled from example');
  }

  void _cancelStringHash() {
    setState(() {
      _textStatus = 'Cancelling...';
    });
    _textCancellation?.cancel('Cancelled from example');
  }

  void _cancelBenchmark() {
    setState(() {
      _benchmarkStatus = 'Cancelling benchmark...';
    });
    _benchmarkCancellation?.cancel('Cancelled from example');
  }

  Future<void> _copyBenchmarkResults() async {
    final text = _benchmarkResults.map((result) => result.summary).join('\n');
    if (text.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _showMessage('Benchmark results copied');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File Hash',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Native streaming hash (MD5 / SHA / XXH3 / BLAKE3)',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _CardPanel extends StatelessWidget {
  const _CardPanel({
    required this.title,
    required this.palette,
    required this.children,
  });

  final String title;
  final _Palette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.primary, this.secondary});

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360 || secondary == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (secondary != null) ...[const SizedBox(height: 8), secondary!],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primary),
            const SizedBox(width: 8),
            secondary!,
          ],
        );
      },
    );
  }
}

class _BenchmarkField extends StatelessWidget {
  const _BenchmarkField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      selectAllOnFocus: true,
    );
  }
}

class _BenchmarkResultsBox extends StatelessWidget {
  const _BenchmarkResultsBox({
    required this.palette,
    required this.results,
    required this.onCopy,
  });

  final _Palette palette;
  final List<_BenchmarkResult> results;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _ResultBox(
          palette: palette,
          child: Padding(
            padding: const EdgeInsets.only(right: 42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final result in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(
                      result.summary,
                      style: _monoStyle(context, palette),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Tooltip(
            message: 'Copy benchmark results',
            child: IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: palette.muted,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeedOptions extends StatelessWidget {
  const _SeedOptions({
    required this.mode,
    required this.labelController,
    required this.valueController,
    required this.onModeChanged,
    required this.seedPreview,
  });

  final _SeedInputMode mode;
  final TextEditingController labelController;
  final TextEditingController valueController;
  final ValueChanged<_SeedInputMode> onModeChanged;
  final String seedPreview;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _SeedInputMode.values)
              ChoiceChip(
                label: Text(value.title),
                selected: mode == value,
                onSelected: (_) => onModeChanged(value),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (mode == _SeedInputMode.fromLabel)
          TextField(
            controller: labelController,
            decoration: const InputDecoration(labelText: 'XXH3 seed label'),
          )
        else
          TextField(
            controller: valueController,
            decoration: InputDecoration(labelText: mode.inputLabel),
            keyboardType: TextInputType.text,
            selectAllOnFocus: true,
          ),
        if (seedPreview.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            'seed: $seedPreview',
            style: _monoStyle(context, palette),
          ),
        ],
      ],
    );
  }
}

class _KeyOptions extends StatelessWidget {
  const _KeyOptions({
    required this.algorithm,
    required this.controller,
    required this.encoding,
    required this.onEncodingChanged,
  });

  final HashAlgorithm algorithm;
  final TextEditingController controller;
  final KeyEncoding encoding;
  final ValueChanged<KeyEncoding> onEncodingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(hintText: _placeholder),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in KeyEncoding.values)
              ChoiceChip(
                label: Text(value.label.toUpperCase()),
                selected: encoding == value,
                onSelected: (_) => onEncodingChanged(value),
              ),
          ],
        ),
      ],
    );
  }

  String get _placeholder {
    if (algorithm.requiresKey) {
      return 'HMAC key';
    }
    if (algorithm == HashAlgorithm.blake3) {
      return 'BLAKE3 keyed mode, 32 bytes';
    }
    return 'Key is not used for this algorithm';
  }
}

class _FileDetails extends StatelessWidget {
  const _FileDetails({required this.file, required this.palette});

  final _PickedFile file;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          file.name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          '${_fileSizeLabel(file.size)} - ${file.displayPath}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class _DigestResult extends StatelessWidget {
  const _DigestResult({
    required this.digest,
    required this.elapsedMs,
    required this.palette,
  });

  final String digest;
  final int? elapsedMs;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return _ResultBox(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Result',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 6),
          SelectableText(digest, style: _monoStyle(context, palette)),
          if (elapsedMs != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatMs(elapsedMs),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.palette, required this.child});

  final _Palette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.resultBackground,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _Palette {
  const _Palette({
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
    required this.border,
    required this.resultBackground,
  });

  final Color background;
  final Color card;
  final Color text;
  final Color muted;
  final Color border;
  final Color resultBackground;

  static _Palette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _Palette(
        background: Color(0xff0f1115),
        card: Color(0xff171a20),
        text: Color(0xfff2f4f8),
        muted: Color(0xff8a93a3),
        border: Color(0xff1f242e),
        resultBackground: Color(0xff11151d),
      );
    }

    return const _Palette(
      background: Color(0xfff5f7fb),
      card: Color(0xffffffff),
      text: Color(0xff0f172a),
      muted: Color(0xff55607a),
      border: Color(0xffe5e7eb),
      resultBackground: Color(0xfff8fafc),
    );
  }
}

class _PickedFile {
  const _PickedFile({
    required this.name,
    required this.hashPath,
    required this.displayPath,
    required this.size,
  });

  final String name;
  final String hashPath;
  final String displayPath;
  final int size;
}

class _BenchmarkResult {
  const _BenchmarkResult({
    required this.algorithm,
    required this.samplesMs,
    this.digestPrefix,
    this.error,
  });

  final HashAlgorithm algorithm;
  final List<int> samplesMs;
  final String? digestPrefix;
  final String? error;

  double? get medianMs => _median(samplesMs);
  int? get minMs => samplesMs.isEmpty ? null : samplesMs.reduce(math.min);
  int? get maxMs => samplesMs.isEmpty ? null : samplesMs.reduce(math.max);

  String get summary {
    if (error != null) {
      return '${algorithm.label}: $error';
    }

    return '${algorithm.label}: ${_formatMs(medianMs)} '
        '(min ${_formatMs(minMs)}, max ${_formatMs(maxMs)}) '
        '${digestPrefix ?? ''}';
  }

  Map<String, Object?> toJson() {
    return {
      'algorithm': algorithm.label,
      'samplesMs': samplesMs,
      'medianMs': medianMs,
      'minMs': minMs,
      'maxMs': maxMs,
      'digestPrefix': digestPrefix,
      'error': error,
    };
  }
}

enum _SeedInputMode {
  fromLabel('LABEL', 'XXH3 seed label'),
  decimal('NUMBER', 'XXH3 seed'),
  hex('HEX', 'XXH3 seed');

  const _SeedInputMode(this.title, this.inputLabel);

  final String title;
  final String inputLabel;
}

TextStyle _monoStyle(BuildContext context, _Palette palette) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        color: palette.text,
        fontFamily: Platform.isIOS || Platform.isMacOS ? 'Menlo' : 'monospace',
        height: 1.45,
      ) ??
      TextStyle(color: palette.text, fontFamily: 'monospace');
}

String _formatBytes(int size) {
  if (size <= 0) {
    return '0 B';
  }

  const units = ['B', 'KB', 'MB', 'GB'];
  final index = math.min(
    (math.log(size) / math.log(1024)).floor(),
    units.length - 1,
  );
  final value = size / math.pow(1024, index);
  final precision = value >= 10 || index == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[index]}';
}

String _fileSizeLabel(int size) =>
    size > 0 ? _formatBytes(size) : 'unknown size';

String _basename(String path) {
  final separatorIndex = path.lastIndexOf(Platform.pathSeparator);
  if (separatorIndex < 0 || separatorIndex == path.length - 1) {
    return path;
  }
  return path.substring(separatorIndex + 1);
}

String _formatMs(num? value) {
  if (value == null) {
    return 'n/a';
  }

  final precision = value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ms';
}

int _parseBoundedInt(
  String value, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null) {
    return fallback;
  }

  return parsed.clamp(min, max);
}

double? _median(List<int> values) {
  if (values.isEmpty) {
    return null;
  }

  final sorted = List<int>.of(values)..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle].toDouble();
  }

  return (sorted[middle - 1] + sorted[middle]) / 2;
}

String _errorText(Object error) {
  if (error is FlutterFileHashException) {
    return error.message;
  }
  if (error is FormatException) {
    return error.message;
  }
  return error.toString();
}
