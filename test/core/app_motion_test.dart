import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_components.dart';
import 'package:hrm_app/core/widgets/app_navigation.dart';

void main() {
  Widget app(Widget child, {bool disabled = true, bool dark = false}) =>
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disabled),
          child: child!,
        ),
        home: Scaffold(body: child),
      );

  for (final disabled in [false, true]) {
    testWidgets('Motion policy and FAB obey disableAnimations=$disabled', (
      tester,
    ) async {
      var expanded = false;
      late StateSetter update;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              expect(
                AppMotion.durationOf(context, AppMotion.control),
                disabled ? Duration.zero : AppMotion.control,
              );
              expect(
                AppMotion.sheetStyleOf(context).duration,
                disabled ? Duration.zero : AppMotion.emphasized,
              );
              expect(
                AppMotion.dialogStyleOf(context).duration,
                disabled ? Duration.zero : AppMotion.fast,
              );
              return AppQuickActionFab(expanded: expanded, onPressed: () {});
            },
          ),
          disabled: disabled,
        ),
      );
      update(() => expanded = true);
      await tester.pump();
      final rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.turns, 0.125);
      expect(rotation.duration, disabled ? Duration.zero : AppMotion.control);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Reduced-motion loading is static and announced, dark=$dark', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          app(
            const Column(
              children: [
                AppLoadingIndicator(semanticLabel: 'Memuat fixture'),
                AppLoadingIndicator(
                  linear: true,
                  semanticLabel: 'Memulihkan fixture',
                ),
              ],
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.hourglass_top_rounded), findsNWidgets(2));
        expect(find.bySemanticsLabel('Memuat fixture'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Reduced-motion sheet and dialog open and close, dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    sheetAnimationStyle: AppMotion.sheetStyleOf(context),
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup fixture sheet'),
                    ),
                  ),
                  child: const Text('Buka fixture sheet'),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    animationStyle: AppMotion.dialogStyleOf(context),
                    builder: (context) =>
                        const AlertDialog(title: Text('Fixture dialog')),
                  ),
                  child: const Text('Buka fixture dialog'),
                ),
              ],
            ),
          ),
          dark: dark,
        ),
      );
      await tester.tap(find.text('Buka fixture sheet'));
      await tester.pumpAndSettle();
      final sheet = ModalRoute.of(
        tester.element(find.text('Tutup fixture sheet')),
      )!;
      expect(sheet.transitionDuration, Duration.zero);
      expect(sheet.reverseTransitionDuration, Duration.zero);
      await tester.tap(find.text('Tutup fixture sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Tutup fixture sheet'), findsNothing);
      await tester.tap(find.text('Buka fixture dialog'));
      await tester.pumpAndSettle();
      final dialog = ModalRoute.of(
        tester.element(find.text('Fixture dialog')),
      )!;
      expect(dialog.transitionDuration, Duration.zero);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Fixture dialog'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Page transitions preserve platform delegate unless disabled', (
    tester,
  ) async {
    for (final disabled in [false, true]) {
      final delegate = _Transitions();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) =>
                AppPageTransitionsBuilder(delegate: delegate).buildTransitions(
                  MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                  context,
                  const AlwaysStoppedAnimation(0.5),
                  const AlwaysStoppedAnimation(0.0),
                  const Text('Fixture page'),
                ),
          ),
          disabled: disabled,
        ),
      );
      expect(delegate.calls, disabled ? 0 : 1);
      expect(find.text('Fixture page'), findsOneWidget);
    }
  });
}

class _Transitions extends PageTransitionsBuilder {
  int calls = 0;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    calls++;
    return child;
  }
}
