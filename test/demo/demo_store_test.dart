import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hrm_app/demo/demo_store.dart';

void main() {
  late SharedPreferences preferences;
  late DemoStore store;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'hrms.session': 'live-session'});
    preferences = await SharedPreferences.getInstance();
    now = DateTime(2026, 9, 23, 7, 50);
    store = DemoStore(preferences, now: () => now);
    await store.load();
  });

  test(
    'check in/out persists one record across restart and rejects duplicates',
    () async {
      await store.checkIn();
      final id = store.today!['id'];
      expect(store.today!['status'], 'Hadir');
      await expectLater(store.checkIn(), throwsStateError);
      now = DateTime(2026, 9, 23, 17);
      await store.checkOut();
      await expectLater(store.checkOut(), throwsStateError);
      final restored = DemoStore(preferences, now: () => now);
      await restored.load();
      expect(restored.today!['id'], id);
      expect(restored.today!['out'], now.toIso8601String());
      expect(restored.attendance.length, 3);
      now = DateTime(2026, 9, 24, 9);
      expect(restored.today, isNull);
      await restored.checkIn();
      expect(restored.today!['status'], 'Telat');
    },
  );

  test(
    'checkout without check-in fails; concurrent check-in creates only one',
    () async {
      await expectLater(store.checkOut(), throwsStateError);
      final first = store.checkIn(simulateLate: true);
      await expectLater(store.checkIn(), throwsStateError);
      await first;
      expect(store.today!['status'], 'Telat');
      expect(store.attendance.length, 3);
    },
  );

  test(
    'leave reserves balance; approval deducts once; permission does not deduct',
    () async {
      expect(store.balance, 10);
      await store.submit(
        'Cuti',
        DateTime(2026, 9, 24),
        DateTime(2026, 9, 25),
        'Liburan demo',
      );
      final id = store.requests.first['id'] as String;
      expect(store.reserved, 2);
      expect(store.balance, 10);
      await store.decide(id, approve: true);
      expect(store.balance, 8);
      expect(store.reserved, 0);
      await expectLater(store.decide(id, approve: true), throwsStateError);
      now = now.add(const Duration(seconds: 1));
      await store.submit(
        'Izin',
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 28),
        'Keperluan demo',
      );
      await store.decide(store.requests.first['id'] as String, approve: true);
      expect(store.balance, 8);
      final restored = DemoStore(preferences, now: () => now);
      await restored.load();
      expect(restored.balance, 8);
    },
  );

  test(
    'validates range, overlap and insufficient balance; cancel releases reservation',
    () async {
      await expectLater(
        store.submit(
          'Cuti',
          DateTime(2026, 9, 26),
          DateTime(2026, 9, 27),
          'Weekend',
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.submit(
          'Cuti',
          DateTime(2026, 9, 28),
          DateTime(2026, 9, 25),
          'Reversed',
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.submit(
          'Cuti',
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
          'Too long',
        ),
        throwsStateError,
      );
      await store.submit(
        'Cuti',
        DateTime(2026, 9, 24),
        DateTime(2026, 9, 25),
        'Demo',
      );
      await expectLater(
        store.submit(
          'Izin',
          DateTime(2026, 9, 25),
          DateTime(2026, 9, 25),
          'Overlap',
        ),
        throwsStateError,
      );
      await store.decide(store.requests.first['id'] as String, approve: false);
      expect(store.reserved, 0);
      expect(store.balance, 10);
    },
  );

  test('reset only changes demo namespace', () async {
    await store.checkIn();
    await store.reset();
    expect(store.today, isNull);
    expect(store.attendance.length, 2);
    expect(preferences.getString('hrms.session'), 'live-session');
  });
}
