import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_native_pdfium.dart';

void main() {
  const abcHash =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
  const expected = {
    'arm64-v8a': abcHash,
    'armeabi-v7a': abcHash,
    'x86_64': abcHash,
  };
  const cacheNames = {
    'arm64-v8a': 'android-arm64',
    'armeabi-v7a': 'android-arm',
    'x86_64': 'android-x64',
  };
  late Directory root;
  late Directory cache;
  late File lockfile;
  late File aab;

  Future<void> write(String path, String value) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(value);
  }

  Future<void> pack(List<String> abis) async {
    if (await aab.exists()) await aab.delete();
    final result = await Process.run('zip', [
      '-q',
      aab.path,
      for (final abi in abis) 'base/lib/$abi/libpdfium.so',
    ], workingDirectory: '${root.path}/zip');
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  Future<void> verify() => verifyNativePdfium(
    aab: aab,
    cache: cache,
    lockfile: lockfile,
    expectedHashes: expected,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('hris-native-guard-test-');
    cache = Directory('${root.path}/cache');
    lockfile = File('${root.path}/pubspec.lock');
    aab = File('${root.path}/fixture.aab');
    await lockfile.writeAsString('''
packages:
  pdfium_dart:
    version: "0.3.1"
  pdfium_flutter:
    version: "0.3.1"
''');
    for (final abi in expected.keys) {
      await write('${cache.path}/${cacheNames[abi]}/libpdfium.so', 'abc');
      await write('${root.path}/zip/base/lib/$abi/libpdfium.so', 'abc');
    }
    await pack(expected.keys.toList());
  });
  tearDown(() => root.delete(recursive: true));

  test('accepts the complete cache and AAB with pinned bytes', () async {
    await expectLater(verify(), completes);
  });

  test('rejects a changed cache binary even when AAB is correct', () async {
    await write('${cache.path}/android-arm64/libpdfium.so', 'changed');
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test(
    'rejects a changed packaged binary even when cache is correct',
    () async {
      await write(
        '${root.path}/zip/base/lib/arm64-v8a/libpdfium.so',
        'changed',
      );
      await pack(expected.keys.toList());
      await expectLater(verify(), throwsA(isA<FormatException>()));
    },
  );

  test('rejects an absent cache ABI', () async {
    await File('${cache.path}/android-arm/libpdfium.so').delete();
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects an absent packaged ABI', () async {
    await pack(['arm64-v8a', 'x86_64']);
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects an unreviewed Android cache ABI', () async {
    await write('${cache.path}/android-x86/libpdfium.so', 'abc');
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects an unreviewed packaged ABI', () async {
    await write('${root.path}/zip/base/lib/x86/libpdfium.so', 'abc');
    await pack([...expected.keys, 'x86']);
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects an extra PDFium binary outside the base ABI paths', () async {
    await write('${root.path}/zip/libpdfium.so', 'abc');
    final result = await Process.run('zip', [
      '-q',
      aab.path,
      'libpdfium.so',
    ], workingDirectory: '${root.path}/zip');
    expect(result.exitCode, 0);
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test(
    'rejects duplicate ZIP entries instead of hashing concatenated bytes',
    () async {
      final bytes = await aab.readAsBytes();
      final data = ByteData.sublistView(bytes);
      final end = bytes.length - 22;
      expect(data.getUint32(end, Endian.little), 0x06054b50);
      final central = data.getUint32(end + 16, Endian.little);
      final length =
          46 +
          data.getUint16(central + 28, Endian.little) +
          data.getUint16(central + 30, Endian.little) +
          data.getUint16(central + 32, Endian.little);
      final duplicate = bytes.sublist(central, central + length);
      final trailer = Uint8List.fromList(bytes.sublist(end));
      final trailerData = ByteData.sublistView(trailer);
      for (final offset in [8, 10]) {
        trailerData.setUint16(
          offset,
          data.getUint16(end + offset, Endian.little) + 1,
          Endian.little,
        );
      }
      trailerData.setUint32(
        12,
        data.getUint32(end + 12, Endian.little) + length,
        Endian.little,
      );
      await aab.writeAsBytes([
        ...bytes.sublist(0, end),
        ...duplicate,
        ...trailer,
      ]);
      await expectLater(verify(), throwsA(isA<FormatException>()));
    },
  );

  test('rejects duplicate Android cache locations', () async {
    await write('${cache.path}/android-arm64/extra/libpdfium.so', 'abc');
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('does not treat another platform cache as an Android ABI', () async {
    await write('${cache.path}/linux-x64/libpdfium.so', 'different');
    await expectLater(verify(), completes);
  });

  test('rejects an unreviewed package version', () async {
    await lockfile.writeAsString(
      (await lockfile.readAsString()).replaceAll('0.3.1', '0.3.2'),
    );
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('checks the Flutter PDFium package version independently', () async {
    await lockfile.writeAsString(
      (await lockfile.readAsString()).replaceFirst(
        'pdfium_flutter:\n    version: "0.3.1"',
        'pdfium_flutter:\n    version: "0.3.2"',
      ),
    );
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects malformed lockfile input', () async {
    await lockfile.writeAsString('packages: []');
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects an invalid archive instead of reporting success', () async {
    await aab.writeAsString('not a ZIP archive');
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects a missing artifact instead of reporting success', () async {
    await aab.delete();
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });

  test('rejects symlinked Android cache binaries', () async {
    final path = '${cache.path}/android-arm64/libpdfium.so';
    await File(path).delete();
    await write('${root.path}/elsewhere.so', 'abc');
    await Link(path).create('${root.path}/elsewhere.so');
    await expectLater(verify(), throwsA(isA<FormatException>()));
  });
}
