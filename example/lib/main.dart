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
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_file_hash')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'WIP: Zig streaming hasher',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'The example is waiting for the native Zig asset build hook. '
              'Current Dart API already models the stream-only C ABI path.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final algorithm in HashAlgorithm.values)
                  Chip(label: Text(algorithm.label)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
