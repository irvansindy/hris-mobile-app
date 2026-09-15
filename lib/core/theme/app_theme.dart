import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const primary = Color(0xFF315B8C);
  static const primaryDark = Color(0xFF26496F);
  static const primaryLight = Color(0xFF8FB4DC);
  static const primaryTint = Color(0xFFE7EEF6);

  static const success = Color(0xFF15803D);
  static const successBackground = Color(0xFFDCFCE7);
  static const warning = Color(0xFFB45309);
  static const warningBackground = Color(0xFFFEF3C7);
  static const danger = Color(0xFFB91C1C);
  static const dangerBackground = Color(0xFFFEE2E2);
  static const destructive = Color(0xFFEF4444);
  static const info = Color(0xFF5D87B4);
  static const purple = Color(0xFF8FABC8);

  static const lightBg = Color(0xFFF3F4F6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF0F172A);
  static const lightTextSub = Color(0xFF667085);
  static const lightMutedTextOnSurface = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE8EAEE);
  static const lightControlBorder = Color(0xFF8993A4);
  static const lightMuted = Color(0xFFF3F4F6);
  static const lightTrack = Color(0xFFEEF1F6);

  static const darkBg = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF161F31);
  static const darkCard = Color(0xFF161F31);
  static const darkText = Color(0xFFEEF2F8);
  static const darkTextSub = Color(0xFF9AA8BD);
  static const darkBorder = Color(0xFF26334A);
  static const darkControlBorder = Color(0xFF5C6B82);
  static const darkMuted = Color(0xFF1E2A3F);
  static const darkTint = Color(0xFF22364E);
  static const darkSuccess = Color(0xFF4ADE80);
  static const darkSuccessBackground = Color(0xFF16351F);
  static const darkWarning = Color(0xFFFBBF24);
  static const darkWarningBackground = Color(0xFF3A2E12);
  static const darkDanger = Color(0xFFF87171);
  static const darkDangerBackground = Color(0xFF3A1C1C);

  static const chartSecondary = Color(0xFF5D87B4);
  static const chartTertiary = Color(0xFF8FABC8);
  static const chartQuaternary = Color(0xFFB3C6DA);
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double section = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double screenHorizontal = 20;
  static const double scrollBottom = 130;
}

abstract final class AppRadius {
  static const double icon = 12;
  static const double input = 18;
  static const double smallCard = 20;
  static const double card = 22;
  static const double largeCard = 26;
  static const double sheet = 30;
  static const double navigation = 30;
  static const double pill = 999;
}

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const primary = <BoxShadow>[
    BoxShadow(
      color: Color(0x73315B8C),
      offset: Offset(0, 12),
      blurRadius: 20,
      spreadRadius: -14,
    ),
  ];

  static const navigation = <BoxShadow>[
    BoxShadow(
      color: Color(0x730F172A),
      offset: Offset(0, 18),
      blurRadius: 40,
      spreadRadius: -18,
    ),
  ];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const control = Duration(milliseconds: 220);
  static const standard = Duration(milliseconds: 300);
  static const emphasized = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 450);

  static const enterCurve = Cubic(0.22, 0.9, 0.3, 1);
  static const successCurve = Cubic(0.22, 1.5, 0.36, 1);

  static bool disabledOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration durationOf(BuildContext context, Duration duration) =>
      disabledOf(context) ? Duration.zero : duration;

  static AnimationStyle sheetStyleOf(BuildContext context) =>
      disabledOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: emphasized, reverseDuration: fast);

  static AnimationStyle dialogStyleOf(BuildContext context) =>
      disabledOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: fast, reverseDuration: fast);
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder({required this.delegate});

  final PageTransitionsBuilder delegate;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final transition = delegate.delegatedTransition;
    if (transition == null) return null;
    return (context, animation, secondaryAnimation, allowSnapshotting, child) =>
        AppMotion.disabledOf(context)
        ? child
        : transition(
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AppMotion.disabledOf(context)
      ? child
      : delegate.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}

abstract final class AppTypography {
  static const fontFamily = 'PlusJakartaSans';

  static TextTheme textTheme(Color ink, Color muted) => TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.1,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 26,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      height: 1.22,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.6,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 20,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      height: 1.25,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.4,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      color: muted,
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      color: ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
    labelMedium: TextStyle(
      fontFamily: fontFamily,
      color: muted,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      height: 1.3,
    ),
    labelSmall: TextStyle(
      fontFamily: fontFamily,
      color: muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w400,
      height: 1.3,
    ),
  );
}

abstract final class AppTheme {
  static ThemeData get light => _theme(
    brightness: Brightness.light,
    colors: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.chartSecondary,
      onSecondary: Colors.white,
      tertiary: AppColors.chartTertiary,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerBackground,
      onErrorContainer: AppColors.danger,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: AppColors.lightSurface,
      surfaceContainer: AppColors.lightMuted,
      surfaceContainerHigh: AppColors.lightTrack,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorder,
    ),
    background: AppColors.lightBg,
    surface: AppColors.lightSurface,
    ink: AppColors.lightText,
    muted: AppColors.lightTextSub,
    border: AppColors.lightBorder,
    controlBorder: AppColors.lightControlBorder,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  );

  static ThemeData get dark => _theme(
    brightness: Brightness.dark,
    colors: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.darkBg,
      primaryContainer: AppColors.darkTint,
      onPrimaryContainer: AppColors.darkText,
      secondary: AppColors.chartSecondary,
      onSecondary: AppColors.darkBg,
      tertiary: AppColors.chartTertiary,
      error: AppColors.darkDanger,
      onError: AppColors.darkBg,
      errorContainer: AppColors.darkDangerBackground,
      onErrorContainer: AppColors.darkDanger,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      surfaceContainerLowest: AppColors.darkBg,
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainer: AppColors.darkMuted,
      surfaceContainerHigh: AppColors.darkTint,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
    ),
    background: AppColors.darkBg,
    surface: AppColors.darkSurface,
    ink: AppColors.darkText,
    muted: AppColors.darkTextSub,
    border: AppColors.darkBorder,
    controlBorder: AppColors.darkControlBorder,
    systemOverlayStyle: SystemUiOverlayStyle.light,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required ColorScheme colors,
    required Color background,
    required Color surface,
    required Color ink,
    required Color muted,
    required Color border,
    required Color controlBorder,
    required SystemUiOverlayStyle systemOverlayStyle,
  }) {
    final textTheme = AppTypography.textTheme(ink, muted);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: controlBorder),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(
            delegate: PredictiveBackPageTransitionsBuilder(),
          ),
          TargetPlatform.iOS: AppPageTransitionsBuilder(
            delegate: CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.macOS: AppPageTransitionsBuilder(
            delegate: CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.windows: AppPageTransitionsBuilder(
            delegate: ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.linux: AppPageTransitionsBuilder(
            delegate: ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.fuchsia: AppPageTransitionsBuilder(
            delegate: ZoomPageTransitionsBuilder(),
          ),
        },
      ),
      focusColor: colors.primary.withValues(alpha: 0.18),
      splashColor: colors.primary.withValues(alpha: 0.08),
      highlightColor: colors.primary.withValues(alpha: 0.05),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineLarge,
        systemOverlayStyle: systemOverlayStyle.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: background,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.lightText.withValues(alpha: 0.06),
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainer,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: border.withValues(alpha: 0.65)),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 52),
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceContainerHigh,
          disabledForegroundColor: muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.smallCard),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: colors.primary,
          side: BorderSide(color: controlBorder),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: colors.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.icon),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.icon),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primaryContainer,
        disabledColor: colors.surfaceContainer.withValues(alpha: 0.55),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colors.onPrimaryContainer,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? colors.primary : muted,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? colors.primary : muted);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: muted,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: background),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHigh,
        circularTrackColor: colors.surfaceContainerHigh,
      ),
      dividerColor: border,
    );
  }
}
