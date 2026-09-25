import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final demoModeProvider = Provider<bool>((ref) => false);
final demoToolsBuilderProvider = Provider<WidgetBuilder?>((ref) => null);
final demoRequestsBuilderProvider = Provider<WidgetBuilder?>((ref) => null);
final demoHomeSectionsBuilderProvider = Provider<WidgetBuilder?>((ref) => null);
final demoAttendanceSummaryBuilderProvider = Provider<WidgetBuilder?>(
  (ref) => null,
);
