import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_file_hash/flutter_file_hash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0f766e)),
        useMaterial3: true,
      ),
      home: const HashDemoPage(),
    );
  }
}

class HashDemoPage extends StatefulWidget {
  const HashDemoPage({super.key});

  @override
  State<HashDemoPage> createState() => _HashDemoPageState();
}

class _HashDemoPageState extends State<HashDemoPage> {
  final TextEditingController _inputController = TextEditingController(
    text: 'abc',
  );
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _seedController = TextEditingController(
    text: xxh3SeedFromLabel('media-cache-v1').toString(),
  );

  HashAlgorithm _algorithm = HashAlgorithm.sha256;
  String _digest = '';
  String _status = 'Ready';
  bool _fileHashRunning = false;
  HashCancellationController? _fileHashCancellation;

  @override
  void dispose() {
    _fileHashCancellation?.cancel();
    _inputController.dispose();
    _keyController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('flutter_file_hash')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<HashAlgorithm>(
            initialValue: _algorithm,
            decoration: const InputDecoration(labelText: 'Algorithm'),
            items: [
              for (final algorithm in HashAlgorithm.values)
                DropdownMenuItem(
                  value: algorithm,
                  child: Text(algorithm.label),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _algorithm = value;
                _digest = '';
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'String input',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_algorithm.supportsKey || _algorithm.requiresKey)
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: _algorithm == HashAlgorithm.blake3
                    ? 'BLAKE3 key, 32 UTF-8 bytes'
                    : 'HMAC key',
                border: const OutlineInputBorder(),
              ),
            ),
          if (_algorithm.supportsSeed) ...[
            if (_algorithm.supportsKey || _algorithm.requiresKey)
              const SizedBox(height: 12),
            TextField(
              controller: _seedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'XXH3 seed',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _hashString,
                icon: const Icon(Icons.tag),
                label: const Text('Hash string'),
              ),
              FilledButton.tonalIcon(
                onPressed: _fileHashRunning ? null : _hashSampleFile,
                icon: const Icon(Icons.insert_drive_file),
                label: const Text('Hash sample file'),
              ),
              if (_fileHashRunning)
                OutlinedButton.icon(
                  onPressed: _cancelFileHash,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_status, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _digest.isEmpty ? 'Digest will appear here' : _digest,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  HashOptions? _hashOptions() {
    final key = _keyController.text;
    final seedText = _seedController.text.trim();

    if (_algorithm.supportsSeed && seedText.isNotEmpty) {
      return HashOptions(seed: int.parse(seedText));
    }

    if ((_algorithm.supportsKey || _algorithm.requiresKey) && key.isNotEmpty) {
      return HashOptions(key: key);
    }

    return null;
  }

  void _hashString() {
    try {
      final digest = stringHash(
        _inputController.text,
        algorithm: _algorithm,
        hashOptions: _hashOptions(),
      );
      setState(() {
        _digest = digest;
        _status = 'String hash complete';
      });
    } catch (error) {
      setState(() {
        _status = error.toString();
      });
    }
  }

  Future<void> _hashSampleFile() async {
    final controller = HashCancellationController();
    _fileHashCancellation = controller;
    setState(() {
      _fileHashRunning = true;
      _digest = '';
      _status = 'Hashing sample file...';
    });

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'flutter_file_hash_demo_',
      );
      final file = File.fromUri(tempDir.uri.resolve('sample.bin'));
      final sink = file.openWrite();
      for (var i = 0; i < 2048; i += 1) {
        sink.add(_inputController.text.codeUnits);
        sink.add([10]);
      }
      await sink.close();

      final digest = await fileHash(
        file.path,
        algorithm: _algorithm,
        hashOptions: _hashOptions(),
        cancellationToken: controller.token,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _digest = digest;
        _status = 'Sample file hash complete';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.toString();
      });
    } finally {
      await tempDir?.delete(recursive: true);
      if (mounted) {
        setState(() {
          _fileHashRunning = false;
        });
      }
      if (identical(_fileHashCancellation, controller)) {
        _fileHashCancellation = null;
      }
    }
  }

  void _cancelFileHash() {
    _fileHashCancellation?.cancel('Cancelled from example');
  }
}
