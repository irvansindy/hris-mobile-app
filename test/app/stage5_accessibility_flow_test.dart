import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/authentication/authentication_providers.dart';
import 'package:hrm_app/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:hrm_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';
import 'package:hrm_app/features/self_service/presentation/screens/request_form_screen.dart';
import '../support/redesign_flow_fixture.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Auth fields remain reachable above keyboard, dark=$dark', (
      tester,
    ) async {
      final container = await createRedesignFlowFixture();
      try {
        await container.read(authControllerProvider.future);
        for (final screen in [
          const LoginScreen(),
          ChangePasswordScreen(onSignOut: () {}),
        ]) {
          await _pump(tester, container, screen, dark: dark, keyboard: 250);
          for (final field in find.byType(TextFormField).evaluate().toList()) {
            final finder = find.byWidget(field.widget);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.enterText(finder, 'FixtureInput1!');
            await tester.pumpAndSettle();
            expect(tester.getRect(finder).bottom, lessThanOrEqualTo(318));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    });

    testWidgets('Cuti menu and Indonesian reduced-motion picker, dark=$dark', (
      tester,
    ) async {
      final container = await createRedesignFlowFixture();
      try {
        await container.read(authControllerProvider.future);
        await container
            .read(authControllerProvider.notifier)
            .login(
              email: 'fixture-a@example.test',
              password: 'FixturePassword1!',
            );
        await _pump(
          tester,
          container,
          const RequestFormScreen(kind: RequestKind.leave),
          dark: dark,
        );
        final dropdown = find.byType(DropdownButtonFormField<String>);
        await tester.scrollUntilVisible(
          dropdown,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Menu jenis cuti');
        await tester.tap(find.text('Fixture cuti tahunan').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Jenis cuti terpilih');
        expect(find.byTooltip('Fixture cuti tahunan'), findsOneWidget);
        final dates = find.text('Pilih rentang tanggal');
        await tester.scrollUntilVisible(
          dates,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(dates);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Dialog tanggal');
        final pickerContext = tester.element(
          find.byType(DateRangePickerDialog),
        );
        expect(Localizations.localeOf(pickerContext), const Locale('id', 'ID'));
        final route = ModalRoute.of(pickerContext)!;
        expect(route.transitionDuration, Duration.zero);
        expect(route.reverseTransitionDuration, Duration.zero);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(DateRangePickerDialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  required bool dark,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            padding: const EdgeInsets.only(top: 30, bottom: 20),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
