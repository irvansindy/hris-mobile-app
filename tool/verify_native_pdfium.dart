import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _hashes = {
  'arm64-v8a':
      'ef8c440d29e2a0820a65554487d23020bd88756ee2d6aad8f8fb59bab3b2eb14',
  'armeabi-v7a':
      '3d67be8a7f8a4f77e5a91530fbab69e0b27a8f4f4db5d4a0df512fbfaf40bd27',
  'x86_64': 'dd8c2880d41baf4c6406d5d2bf0c1beffe42b45e756ff08a9c612ad35d5a5c64',
};
const _cacheNames = {
  'arm64-v8a': 'android-arm64',
  'armeabi-v7a': 'android-arm',
  'x86_64': 'android-x64',
};

Future<void> main(List<String> args) async {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart --packages=.dart_tool/package_config.json tool/verify_native_pdfium.dart [AAB]',
    );
    exitCode = 64;
    return;
  }
  try {
    await verifyNativePdfium(
      aab: File(
        args.isEmpty
            ? 'build/app/outputs/bundle/release/app-release.aab'
            : args.single,
      ),
      cache: Directory(
        '.dart_tool/hooks_runner/shared/pdfium_dart/build/chromium_7811',
      ),
      lockfile: File('pubspec.lock'),
      expectedHashes: _hashes,
    );
    stdout.writeln('PDFium integrity verified: 3 ABIs, cache and AAB.');
  } catch (error) {
    stderr.writeln('PDFium integrity failed: $error');
    exitCode = 1;
  }
}

Future<void> verifyNativePdfium({
  required File aab,
  required Directory cache,
  required File lockfile,
  required Map<String, String> expectedHashes,
}) async {
  final lock = loadYaml(await lockfile.readAsString());
  final packages = lock is Map ? lock['packages'] : null;
  if (packages is! Map) {
    throw const FormatException('Missing locked packages.');
  }
  for (final name in ['pdfium_dart', 'pdfium_flutter']) {
    final package = packages[name];
    if (package is! Map || package['version'] != '0.3.1') {
      throw FormatException(
        'Unreviewed $name version; update the audited baseline.',
      );
    }
  }
  if (await FileSystemEntity.type(cache.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const FormatException('Missing or linked PDFium cache.');
  }
  final expectedCache = {
    for (final abi in expectedHashes.keys)
      '${_cacheNames[abi]}/libpdfium.so': expectedHashes[abi]!,
  };
  final found = <String>{};
  for (final platform in await cache.list(followLinks: false).toList()) {
    final name = platform.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (!name.startsWith('android-')) continue;
    if (platform is! Directory) {
      throw const FormatException('Invalid or linked Android cache directory.');
    }
    await for (final entry in platform.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is Link) {
        throw const FormatException('Linked Android cache entry.');
      }
      if (!entry.path.toLowerCase().endsWith('/libpdfium.so')) continue;
      final relative = entry.path.substring(cache.path.length + 1);
      if (entry is! File || !expectedCache.containsKey(relative)) {
        throw FormatException('Unexpected PDFium cache entry: $relative');
      }
      found.add(relative);
      final result = await Process.run('shasum', ['-a', '256', entry.path]);
      _checkHash(result, expectedCache[relative]!, relative);
    }
  }
  if (found.length != expectedCache.length) {
    throw const FormatException('Missing Android PDFium cache ABI.');
  }

  final listing = await Process.run('unzip', ['-Z', '-1', aab.path]);
  if (listing.exitCode != 0) {
    throw const FormatException('Cannot inspect AAB ZIP entries.');
  }
  final entries = const LineSplitter()
      .convert(listing.stdout as String)
      .where((path) => path.split('/').last.toLowerCase() == 'libpdfium.so')
      .toList();
  final expectedEntries = {
    for (final abi in expectedHashes.keys)
      'base/lib/$abi/libpdfium.so': expectedHashes[abi]!,
  };
  if (entries.length != expectedEntries.length ||
      entries.toSet().length != entries.length ||
      entries.any((entry) => !expectedEntries.containsKey(entry))) {
    throw const FormatException(
      'Missing, duplicate or unexpected AAB PDFium ABI.',
    );
  }
  for (final entry in entries) {
    final extracted = await Process.run('unzip', [
      '-p',
      aab.path,
      entry,
    ], stdoutEncoding: null);
    if (extracted.exitCode != 0) {
      throw FormatException('Cannot read AAB entry: $entry');
    }
    final process = await Process.start('shasum', ['-a', '256']);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    process.stdin.add(extracted.stdout as List<int>);
    await process.stdin.close();
    _checkHash(
      ProcessResult(0, await process.exitCode, await output, await errors),
      expectedEntries[entry]!,
      entry,
    );
  }
}

void _checkHash(ProcessResult result, String expected, String label) {
  final actual = (result.stdout as String).trim().split(RegExp(r'\s+')).first;
  if (result.exitCode != 0 || actual != expected) {
    throw FormatException('Checksum mismatch or hash command failure: $label');
  }
}
