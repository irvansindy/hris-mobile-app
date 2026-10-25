import 'package:flutter_test/flutter_test.dart';

import '../../tool/select_ios_simulator.dart';

const _firstId = '11111111-1111-1111-1111-111111111111';
const _secondId = '22222222-2222-2222-2222-222222222222';

Map<String, Object?> _phone({
  String id = _firstId,
  String name = 'iPhone Fixture',
  bool available = true,
  String state = 'Shutdown',
}) => {'udid': id, 'name': name, 'isAvailable': available, 'state': state};

Map<String, dynamic> _inventory(Map<String, Object?> runtimes) => {
  'devices': runtimes,
};

void main() {
  test('selects the latest supported iOS runtime numerically', () {
    final selected = selectIosSimulator(
      _inventory({
        'com.apple.CoreSimulator.SimRuntime.iOS-18-9': [_phone()],
        'com.apple.CoreSimulator.SimRuntime.iOS-18-10': [_phone(id: _secondId)],
        'com.apple.CoreSimulator.SimRuntime.iOS-9-3': [_phone()],
      }),
    );
    expect(selected.udid, _secondId);
    expect(selected.runtime, 'com.apple.CoreSimulator.SimRuntime.iOS-18-10');
    expect(selected.state, 'Shutdown');
  });

  test(
    'accepts deployment floor 15.5 and preserves an already booted state',
    () {
      final selected = selectIosSimulator(
        _inventory({
          'com.apple.CoreSimulator.SimRuntime.iOS-15-5': [
            _phone(state: 'Booted'),
          ],
        }),
      );
      expect(selected.udid, _firstId);
      expect(selected.name, 'iPhone Fixture');
      expect(selected.state, 'Booted');
    },
  );

  test('ignores unavailable phones and other platforms', () {
    final selected = selectIosSimulator(
      _inventory({
        'com.apple.CoreSimulator.SimRuntime.iOS-27-0': [
          _phone(available: false),
        ],
        'com.apple.CoreSimulator.SimRuntime.tvOS-28-0': [_phone()],
        'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [_phone(id: _secondId)],
      }),
    );
    expect(selected.udid, _secondId);
  });

  for (final inventory in <String, Map<String, dynamic>>{
    'missing devices': {},
    'malformed devices': {'devices': []},
    'no available devices': _inventory({}),
    'runtime below deployment floor': _inventory({
      'com.apple.CoreSimulator.SimRuntime.iOS-15-4': [_phone()],
    }),
    'iPad-only inventory': _inventory({
      'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [
        _phone(name: 'iPad Fixture'),
      ],
    }),
    'malformed device list': _inventory({
      'com.apple.CoreSimulator.SimRuntime.iOS-26-0': 'invalid',
    }),
    'unsafe UUID': _inventory({
      'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [
        _phone(id: 'id; echo unsafe'),
      ],
    }),
    'unknown lifecycle state': _inventory({
      'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [
        _phone(state: 'Creating'),
      ],
    }),
  }.entries) {
    test('fails closed for ${inventory.key}', () {
      expect(() => selectIosSimulator(inventory.value), throwsFormatException);
    });
  }
}
