import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  if (info.version.isEmpty) {
    throw const FormatException('Versi aplikasi tidak tersedia.');
  }
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
});
