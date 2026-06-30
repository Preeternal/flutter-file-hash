import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _assetName = 'src/zig_files_hash_bindings.dart';
const _libraryName = 'zig_files_hash_c_api';
const _prebuiltRootPath = 'third_party/zig-files-hash-prebuilt';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final builder = _PrebuiltZigFilesHashBuilder(input: input, output: output);
    await builder.run();
  });
}

final class _PrebuiltZigFilesHashBuilder {
  const _PrebuiltZigFilesHashBuilder({
    required this.input,
    required this.output,
  });

  final BuildInput input;
  final BuildOutputBuilder output;

  Future<void> run() async {
    final prebuilt = await _prebuiltDynamicLibrary(input.config.code);
    final prebuiltFile = File.fromUri(prebuilt);

    if (!prebuiltFile.existsSync()) {
      throw BuildError(
        message:
            'Missing flutter_file_hash native prebuilt: ${prebuilt.toFilePath()}\n'
            'Published packages must include ready native artifacts. '
            'Maintainers should run scripts/build-zig-*.sh before publishing; '
            'package users should not need a local Zig toolchain.',
      );
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: _assetName,
        linkMode: DynamicLoadingBundled(),
        file: prebuilt,
      ),
    );
    output.dependencies.add(prebuilt);
  }

  Future<Uri> _prebuiltDynamicLibrary(CodeConfig code) async {
    final root = input.packageRoot.resolve('$_prebuiltRootPath/');

    if (code.targetOS == OS.android) {
      return root.resolve(
        'android/${_androidAbi(code.targetArchitecture)}/'
        '${OS.android.dylibFileName(_libraryName)}',
      );
    }

    if (code.targetOS == OS.iOS) {
      final variant = code.iOS.targetSdk == IOSSdk.iPhoneSimulator
          ? 'ios-simulator-universal'
          : 'ios-arm64';
      return root.resolve('ios/$variant/${OS.iOS.dylibFileName(_libraryName)}');
    }

    if (code.targetOS == OS.macOS) {
      final universal = root.resolve(
        'macos/universal/${OS.macOS.dylibFileName(_libraryName)}',
      );
      return _thinMacOSDylib(universal, code.targetArchitecture);
    }

    if (code.targetOS == OS.linux) {
      return root.resolve(
        'linux/${_simpleArch(code.targetArchitecture)}/'
        '${OS.linux.dylibFileName(_libraryName)}',
      );
    }

    if (code.targetOS == OS.windows) {
      return root.resolve(
        'windows/${_simpleArch(code.targetArchitecture)}/'
        '${OS.windows.dylibFileName(_libraryName)}',
      );
    }

    throw BuildError(message: 'Unsupported target OS: ${code.targetOS}');
  }

  Future<Uri> _thinMacOSDylib(Uri universal, Architecture architecture) async {
    output.dependencies.add(universal);

    final archName = _macOSLipoArch(architecture);
    final outputUri = input.outputDirectory.resolve(
      'zig-files-hash/$archName/${OS.macOS.dylibFileName(_libraryName)}',
    );
    final outputFile = File.fromUri(outputUri);
    await outputFile.parent.create(recursive: true);

    final result = await Process.run('lipo', [
      universal.toFilePath(),
      '-thin',
      archName,
      '-output',
      outputFile.path,
    ]);

    if (result.exitCode != 0) {
      throw BuildError(
        message:
            'Failed to thin macOS flutter_file_hash prebuilt for $archName.\n'
            '${result.stderr}',
      );
    }

    return outputUri;
  }
}

String _androidAbi(Architecture arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64-v8a',
    Architecture.arm => 'armeabi-v7a',
    Architecture.ia32 => 'x86',
    Architecture.x64 => 'x86_64',
    _ => throw BuildError(message: 'Unsupported Android architecture: $arch'),
  };
}

String _simpleArch(Architecture arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x64',
    _ => throw BuildError(message: 'Unsupported architecture: $arch'),
  };
}

String _macOSLipoArch(Architecture arch) {
  return switch (arch) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x86_64',
    _ => throw BuildError(message: 'Unsupported macOS architecture: $arch'),
  };
}
