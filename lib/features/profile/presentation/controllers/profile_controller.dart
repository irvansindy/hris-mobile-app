import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/profile/profile_providers.dart';

class ProfileController extends Notifier<Employee> {
  late FeatureSession _session;
  int _generation = 0;
  @override
  Employee build() {
    _session = ref.watch(featureSessionProvider);
    _generation++;
    ref.onDispose(() => _generation++);
    final session = _session;
    final initial = ref.watch(profileRepositoryProvider).currentEmployee;
    Future<void>.microtask(() async {
      if (session.isCurrent) await refresh();
    });
    return initial;
  }

  Future<void> refresh() async {
    final session = _session;
    if (!session.isCurrent) return;
    final generation = ++_generation;
    final loadState = ref.read(profileLoadStateProvider.notifier);
    loadState.state = const AsyncLoading();
    try {
      final result = await ref.read(profileRepositoryProvider).refresh();
      if (!session.isCurrent || generation != _generation) return;
      state = result;
      loadState.state = const AsyncData(null);
    } catch (error, stack) {
      if (session.isCurrent && generation == _generation) {
        loadState.state = AsyncError(error, stack);
      }
    }
  }
}
