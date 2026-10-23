import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/main.dart';

import '../support/redesign_flow_fixture.dart';

void main() {
  for (final deviceLocale in [
    const Locale('id', 'ID'),
    const Locale('en', 'US'),
  ]) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'App locale and motion: $deviceLocale, reduced=$reducedMotion',
        (tester) async {
          tester.platformDispatcher.localesTestValue = [deviceLocale];
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reducedMotion);
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final container = await createRedesignFlowFixture();
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: const HrmsApp(),
              ),
            );
            await tester.pumpAndSettle();
            final context = tester.element(
              find.byKey(const ValueKey('login-email')),
            );
            expect(Localizations.localeOf(context), const Locale('id', 'ID'));
            expect(
              MaterialLocalizations.of(context).formatMonthYear(DateTime(2026)),
              'Januari 2026',
            );
            expect(MediaQuery.disableAnimationsOf(context), reducedMotion);
            expect(
              tester
                  .widget<MaterialApp>(find.byType(MaterialApp))
                  .themeAnimationDuration,
              reducedMotion ? Duration.zero : isNot(Duration.zero),
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            container.dispose();
          }
        },
      );
    }
  }
}
