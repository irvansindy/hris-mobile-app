import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';

final profileControllerProvider = NotifierProvider<ProfileController, Employee>(
  ProfileController.new,
);

final profileLoadStateProvider = StateProvider<AsyncValue<void>>((ref) {
  ref.watch(featureSessionProvider);
  return const AsyncData(null);
});
