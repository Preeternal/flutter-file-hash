import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';

const _assetName = 'src/zig_files_hash_bindings.dart';
const _libraryName = 'zig_files_hash_c_api';
const _zigCorePath = 'third_party/zig-files-hash';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final builder = _ZigFilesHashBuilder(
      input: input,
      output: output,
      logger: Logger('flutter_file_hash.build'),
    );
    await builder.run();
  });
}

final class _ZigFilesHashBuilder {
  const _ZigFilesHashBuilder({
    required this.input,
    required this.output,
    required this.logger,
  });

  final BuildInput input;
  final BuildOutputBuilder output;
  final Logger logger;

  Future<void> run() async {
    final code = input.config.code;
    final outDir = input.outputDirectory.resolve('zig-files-hash/');
    final outFile = outDir.resolve(code.targetOS.dylibFileName(_libraryName));

    await Directory.fromUri(outDir).create(recursive: true);
    await Directory.fromUri(_zigCacheDir).create(recursive: true);
    await Directory.fromUri(_zigGlobalCacheDir).create(recursive: true);

    if (code.targetOS == OS.macOS || code.targetOS == OS.iOS) {
      await _buildDarwinDynamicLibrary(outDir: outDir, outFile: outFile);
    } else {
      await _buildDirectDynamicLibrary(outFile: outFile);
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: outFile,
      ),
    );

    output.dependencies.addAll(await _zigDependencies);
  }

  Future<void> _buildDirectDynamicLibrary({required Uri outFile}) async {
    final target = _zigTargetTriple(input.config.code);
    await _run('zig', [
      'build-lib',
      _zigCAbiSource.toFilePath(),
      '-dynamic',
      '-OReleaseFast',
      '-target',
      target,
      '--name',
      _libraryName,
      '-femit-bin=${outFile.toFilePath()}',
      '--cache-dir',
      _zigCacheDir.toFilePath(),
      '--global-cache-dir',
      _zigGlobalCacheDir.toFilePath(),
    ], workingDirectory: _packageRoot.toFilePath());
  }

  Future<void> _buildDarwinDynamicLibrary({
    required Uri outDir,
    required Uri outFile,
  }) async {
    final staticArchive = outDir.resolve('lib${_libraryName}_static.a');
    final code = input.config.code;
    final sdkName = _darwinSdkName(code);
    final sdkPath = await _xcrunSdkPath(sdkName);
    final target = _zigTargetTriple(code);

    await _run('zig', [
      'build-lib',
      _zigCAbiSource.toFilePath(),
      '-static',
      '-OReleaseFast',
      '-target',
      target,
      '--name',
      '${_libraryName}_static',
      '-femit-bin=${staticArchive.toFilePath()}',
      '--cache-dir',
      _zigCacheDir.toFilePath(),
      '--global-cache-dir',
      _zigGlobalCacheDir.toFilePath(),
    ], workingDirectory: _packageRoot.toFilePath());

    await _run('xcrun', [
      '--sdk',
      sdkName,
      'clang',
      '-dynamiclib',
      '-arch',
      _darwinArchFlag(code.targetArchitecture),
      '-isysroot',
      sdkPath,
      _darwinMinVersionFlag(code),
      '-headerpad_max_install_names',
      '-Wl,-force_load,${staticArchive.toFilePath()}',
      '-install_name',
      '@rpath/${code.targetOS.dylibFileName(_libraryName)}',
      '-o',
      outFile.toFilePath(),
    ], workingDirectory: _packageRoot.toFilePath());
  }

  Future<String> _xcrunSdkPath(String sdkName) async {
    final result = await _run('xcrun', [
      '--sdk',
      sdkName,
      '--show-sdk-path',
    ], workingDirectory: _packageRoot.toFilePath());
    return (result.stdout as String).trim();
  }

  Future<ProcessResult> _run(
    String executable,
    List<String> args, {
    required String workingDirectory,
  }) async {
    logger.info([executable, ...args].join(' '));
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDirectory,
    );

    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      logger.info(stdout);
    }

    final stderr = (result.stderr as String).trim();
    if (stderr.isNotEmpty) {
      logger.warning(stderr);
    }

    if (result.exitCode != 0) {
      throw BuildError(
        message:
            '$executable ${args.join(' ')} failed with exit code ${result.exitCode}.'
            '${stderr.isEmpty ? '' : '\n$stderr'}',
      );
    }

    return result;
  }

  Uri get _packageRoot => input.packageRoot;

  Uri get _zigRoot => _packageRoot.resolve('$_zigCorePath/');

  Uri get _zigCAbiSource => _zigRoot.resolve('src/c_api.zig');

  Uri get _zigCacheDir => input.outputDirectory.resolve('zig-cache/');

  Uri get _zigGlobalCacheDir =>
      input.outputDirectory.resolve('zig-global-cache/');

  Future<List<Uri>> get _zigDependencies async {
    final root = Directory.fromUri(_zigRoot);
    final dependencies = <Uri>[];

    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final path = entity.uri.path;
      if (path.contains('/.git/') ||
          path.contains('/.zig-cache/') ||
          path.contains('/zig-out/')) {
        continue;
      }

      dependencies.add(entity.uri);
    }

    return dependencies;
  }
}

String _zigTargetTriple(CodeConfig code) {
  final arch = code.targetArchitecture;

  if (code.targetOS == OS.android) {
    return switch (arch) {
      Architecture.arm64 => 'aarch64-linux-android',
      Architecture.arm => 'arm-linux-androideabi',
      Architecture.ia32 => 'x86-linux-android',
      Architecture.x64 => 'x86_64-linux-android',
      _ => throw BuildError(message: 'Unsupported Android architecture: $arch'),
    };
  }

  if (code.targetOS == OS.iOS) {
    final version = _majorMinor(code.iOS.targetVersion);
    final sdk = code.iOS.targetSdk;
    final archName = switch (arch) {
      Architecture.arm64 => 'aarch64',
      Architecture.x64 => 'x86_64',
      _ => throw BuildError(message: 'Unsupported iOS architecture: $arch'),
    };
    final simulatorSuffix = sdk == IOSSdk.iPhoneSimulator ? '-simulator' : '';
    return '$archName-ios.$version$simulatorSuffix';
  }

  if (code.targetOS == OS.macOS) {
    final minMajor = arch == Architecture.arm64
        ? _maxInt(code.macOS.targetVersion, 11)
        : code.macOS.targetVersion;
    final version = _majorMinor(minMajor);
    return switch (arch) {
      Architecture.arm64 => 'aarch64-macos.$version',
      Architecture.x64 => 'x86_64-macos.$version',
      _ => throw BuildError(message: 'Unsupported macOS architecture: $arch'),
    };
  }

  if (code.targetOS == OS.linux) {
    return switch (arch) {
      Architecture.arm64 => 'aarch64-linux-gnu',
      Architecture.arm => 'arm-linux-gnueabihf',
      Architecture.ia32 => 'x86-linux-gnu',
      Architecture.x64 => 'x86_64-linux-gnu',
      Architecture.riscv64 => 'riscv64-linux-gnu',
      _ => throw BuildError(message: 'Unsupported Linux architecture: $arch'),
    };
  }

  if (code.targetOS == OS.windows) {
    return switch (arch) {
      Architecture.arm64 => 'aarch64-windows-gnu',
      Architecture.ia32 => 'x86-windows-gnu',
      Architecture.x64 => 'x86_64-windows-gnu',
      _ => throw BuildError(message: 'Unsupported Windows architecture: $arch'),
    };
  }

  throw BuildError(message: 'Unsupported target OS: ${code.targetOS}');
}

String _darwinSdkName(CodeConfig code) {
  if (code.targetOS == OS.macOS) {
    return 'macosx';
  }

  if (code.targetOS == OS.iOS) {
    return switch (code.iOS.targetSdk) {
      IOSSdk.iPhoneOS => 'iphoneos',
      IOSSdk.iPhoneSimulator => 'iphonesimulator',
      _ => throw BuildError(
        message: 'Unsupported iOS SDK: ${code.iOS.targetSdk}',
      ),
    };
  }

  throw BuildError(message: 'Target OS is not Darwin: ${code.targetOS}');
}

String _darwinArchFlag(Architecture arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x86_64',
    _ => throw BuildError(message: 'Unsupported Darwin architecture: $arch'),
  };
}

String _darwinMinVersionFlag(CodeConfig code) {
  if (code.targetOS == OS.macOS) {
    final minMajor = code.targetArchitecture == Architecture.arm64
        ? _maxInt(code.macOS.targetVersion, 11)
        : code.macOS.targetVersion;
    return '-mmacosx-version-min=${_majorMinor(minMajor)}';
  }

  if (code.targetOS == OS.iOS) {
    final version = _majorMinor(code.iOS.targetVersion);
    return code.iOS.targetSdk == IOSSdk.iPhoneSimulator
        ? '-mios-simulator-version-min=$version'
        : '-miphoneos-version-min=$version';
  }

  throw BuildError(message: 'Target OS is not Darwin: ${code.targetOS}');
}

String _majorMinor(int major) => '$major.0';

int _maxInt(int a, int b) => a > b ? a : b;
