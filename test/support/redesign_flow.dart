import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';
import 'package:hrm_app/features/attendance/attendance_dependencies.dart';
import 'package:hrm_app/features/notifications/notification_providers.dart';
import 'package:hrm_app/main.dart';
import 'redesign_flow_fixture.dart';

void registerRedesignFlowTests() {
  for (final reject in [false, true]) {
    testWidgets('Fixture app flow, attendance rejected=$reject, logout A to B', (
      tester,
    ) async {
      final previousHitTestPolicy =
          WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      final container = await createRedesignFlowFixture(
        rejectAttendance: reject,
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const HrmsApp(),
          ),
        );
        await tester.pumpAndSettle();
        await _login(tester, 'fixture-a@example.test');
        expect(find.text('Fixture Employee A'), findsOneWidget);
        expect(find.text('Slip gaji'), findsNothing);
        await _tap(tester, find.byTooltip('Buka chat'));
        expect(find.text('Chat belum tersedia'), findsOneWidget);
        await _tap(tester, find.text('Tutup'));
        await _tap(tester, find.byTooltip('Buka notifikasi'));
        expect(find.byType(AppFloatingNavigation), findsNothing);
        await _tap(tester, find.text('Fixture informasi'));
        expect(container.read(notificationUnreadCountProvider).requireValue, 0);
        await _tap(tester, find.text('Tutup'));
        await _tap(tester, find.byTooltip('Kembali'));
        await _tap(tester, _navLabel('Kalender'));
        await _tap(tester, find.byTooltip('Bulan berikutnya'));
        await _tap(tester, find.byTooltip('Bulan sebelumnya'));
        await _tap(tester, find.byTooltip('Buka absensi'));
        final attendance =
            container.read(attendanceRepositoryProvider) as FixtureAttendance;
        await _tap(tester, find.text('Catat masuk'));
        await _tap(tester, find.text('Batal'));
        expect(attendance.submissions, 0);
        await _tap(tester, find.text('Catat masuk'));
        await _tap(tester, find.text('Kirim'));
        expect(attendance.submissions, 1);
        await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
        await tester.pumpAndSettle();
        if (reject) {
          expect(find.text('Fixture penolakan server'), findsOneWidget);
          expect(find.text('Sedang bekerja'), findsNothing);
        } else {
          expect(find.text('Sedang bekerja'), findsOneWidget);
          expect(find.text('Waktu masuk tercatat di server.'), findsOneWidget);
        }
        await _tap(tester, _navLabel('Beranda'));
        await _tap(tester, find.byType(AppQuickActionFab));
        await _tap(tester, find.text('Ajukan cuti'));
        expect(find.byType(AppFloatingNavigation), findsNothing);
        await _tap(tester, find.byType(DropdownButtonFormField<String>));
        await _tap(tester, find.text('Fixture cuti tahunan').last);
        await _tap(tester, find.text('Pilih rentang tanggal'));
        final pickerContext = tester.element(
          find.byType(DateRangePickerDialog),
        );
        final localizations = MaterialLocalizations.of(pickerContext);
        await _tap(
          tester,
          find.byTooltip(localizations.inputDateModeButtonLabel),
        );
        final today = DateTime.now();
        final now = today.weekday > DateTime.friday
            ? today.add(Duration(days: 8 - today.weekday))
            : today;
        final date =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
        final dateFields = find.descendant(
          of: find.byType(DateRangePickerDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dateFields.at(0), date);
        await tester.enterText(dateFields.at(1), date);
        await _tap(tester, find.text(localizations.okButtonLabel));
        expect(find.byType(DateRangePickerDialog), findsNothing);
        await tester.enterText(
          find.byType(TextFormField).last,
          'Fixture alasan pengajuan',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Tinjau dan kirim'));
        await _tap(tester, find.text('Kirim'));
        await _tap(tester, find.text('Pengajuan'));
        expect(find.text('Fixture cuti tahunan'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await _tap(tester, _navLabel('Profil'));
        await _tap(tester, find.text('Keluar'));
        expect(find.text('Fixture Employee A'), findsNothing);
        await _login(tester, 'fixture-b@example.test');
        expect(find.text('Fixture Employee B'), findsOneWidget);
        expect(find.text('Fixture Employee A'), findsNothing);
        expect(container.read(notificationUnreadCountProvider).requireValue, 1);
        expect(
          (container.read(attendanceRepositoryProvider) as FixtureAttendance)
              .submissions,
          0,
        );
        expect(find.text('Fixture cuti tahunan'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        WidgetController.hitTestWarningShouldBeFatal = previousHitTestPolicy;
      }
    });
  }
}

Finder _navLabel(String label) => find.descendant(
  of: find.byType(AppFloatingNavigation),
  matching: find.text(label),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const ValueKey('login-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    'FixturePassword1!',
  );
  await _tap(tester, find.byKey(const ValueKey('login-submit')));
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}
