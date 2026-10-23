import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/profile/domain/entities/employee_support.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';

final profileControllerProvider = NotifierProvider<ProfileController, Employee>(
  ProfileController.new,
);

final profileLoadStateProvider = StateProvider<AsyncValue<void>>((ref) {
  ref.watch(featureSessionProvider);
  return const AsyncData(null);
});

final profileFaceIdBuilderProvider = Provider<WidgetBuilder?>((ref) => null);

final employeeSupportProvider = FutureProvider.autoDispose
    .family<EmployeeSupportSnapshot, FeatureSession>((ref, session) async {
      final value = await ref.watch(employeeSupportRepositoryProvider).load();
      if (!session.isCurrent) {
        throw StateError('Sesi telah berubah. Muat ulang profil.');
      }
      return value;
    });
