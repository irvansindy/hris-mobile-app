import 'dart:convert';
import 'dart:io';

typedef IosSimulator = ({
  String udid,
  String name,
  String runtime,
  String state,
});

Future<void> main() async {
  try {
    final inventory = jsonDecode(await stdin.transform(utf8.decoder).join());
    if (inventory is! Map<String, dynamic>) {
      throw const FormatException('Expected simctl JSON object.');
    }
    final selected = selectIosSimulator(inventory);
    stderr.writeln(
      'Selected ${selected.name}: ${selected.runtime} (${selected.state})',
    );
    stdout.writeln('${selected.udid} ${selected.state}');
  } catch (error) {
    stderr.writeln('iOS simulator selection failed: $error');
    exitCode = 1;
  }
}

IosSimulator selectIosSimulator(Map<String, dynamic> inventory) {
  final devices = inventory['devices'];
  if (devices is! Map) throw const FormatException('Missing simctl devices.');
  final runtimePattern = RegExp(
    r'^com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d{1,2})-(\d{1,2})(?:-(\d{1,2}))?$',
  );
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  IosSimulator? selected;
  var newest = 0;
  for (final entry in devices.entries) {
    if (entry.key is! String || entry.value is! List) continue;
    final runtime = entry.key as String;
    final match = runtimePattern.firstMatch(runtime);
    if (match == null) continue;
    final version =
        int.parse(match[1]!) * 1000000 +
        int.parse(match[2]!) * 1000 +
        int.parse(match[3] ?? '0');
    if (version < 15005000 || version <= newest) continue;
    for (final raw in entry.value as List) {
      if (raw is! Map || raw['isAvailable'] != true) continue;
      final name = raw['name'];
      final udid = raw['udid'];
      final state = raw['state'];
      if (name is! String ||
          !name.startsWith('iPhone') ||
          udid is! String ||
          !uuidPattern.hasMatch(udid) ||
          state is! String ||
          !const ['Booted', 'Shutdown'].contains(state)) {
        continue;
      }
      selected = (udid: udid, name: name, runtime: runtime, state: state);
      newest = version;
      break;
    }
  }
  return selected ??
      (throw const FormatException(
        'No available iPhone simulator with iOS >= 15.5.',
      ));
}
