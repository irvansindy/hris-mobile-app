import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hrm_app/demo/demo_overrides.dart';
import 'package:hrm_app/demo/demo_store.dart';
import 'package:hrm_app/core/storage/preferences.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/features/self_service/presentation/screens/requests_screen.dart';

void main() {
  for (final topInset in [0.0, 24.0, 48.0]) {
    testWidgets('Pengajuan respects status bar inset $topInset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DemoStore(prefs);
      await store.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...demoOverrides(store),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                padding: EdgeInsets.only(top: topInset),
                viewPadding: EdgeInsets.only(top: topInset),
              ),
              child: const RequestsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(AppPageHeader)).dy, topInset + 16);
      for (final label in ['Semua', 'Cuti', 'Lembur', 'Reimburse']) {
        final pill = find.byKey(ValueKey('request-filter-$label'));
        expect(pill, findsOneWidget);
        expect(tester.getSize(pill).width, lessThan(115), reason: label);
        expect(tester.getSize(pill).height, lessThan(40));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Pengajuan capsules fit one row at the 390dp reference width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoStore(prefs);
    await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...demoOverrides(store),
        ],
        child: const MaterialApp(home: RequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final pills = [
      'Semua',
      'Cuti',
      'Lembur',
      'Reimburse',
    ].map((label) => find.byKey(ValueKey('request-filter-$label'))).toList();
    final top = tester.getTopLeft(pills.first).dy;
    expect(
      pills.every((pill) => tester.getTopLeft(pill).dy == top),
      isTrue,
      reason: pills
          .map(
            (pill) =>
                '${tester.getSize(pill).width}@${tester.getTopLeft(pill).dy}',
          )
          .join(', '),
    );
    expect(tester.getRect(pills.last).right, lessThanOrEqualTo(370));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pengajuan demo matches compact history and filters examples', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoStore(prefs);
    await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...demoOverrides(store),
        ],
        child: const MaterialApp(home: RequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Layanan Employee'), findsNothing);
    expect(find.text('Sebelumnya'), findsNothing);
    expect(find.textContaining('Cuti Tahunan'), findsOneWidget);
    expect(find.text('Lembur 3 jam'), findsOneWidget);
    expect(find.text('Reimbursement'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('request-filter-Lembur')));
    await tester.pumpAndSettle();
    expect(find.text('Lembur 3 jam'), findsOneWidget);
    expect(find.textContaining('Cuti Tahunan'), findsNothing);
    await tester.tap(find.text('Lembur 3 jam'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('belum tersimpan sebagai transaksi lokal'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pengajuan demo scrolls filters at 320dp with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = DemoStore(prefs);
    await store.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...demoOverrides(store),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: RequestsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('request-filter-Reimburse')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
