import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_app/core/security/session_lifecycle.dart';
import 'package:hrm_app/core/network/dio_client.dart';
import 'package:hrm_app/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:hrm_app/features/calendar/data/datasources/calendar_local_datasource.dart';
import 'package:hrm_app/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';

final calendarLocalDataSourceProvider = Provider<CalendarLocalDataSource>((
  ref,
) {
  ref.watch(featureSessionProvider);
  return UnavailableCalendarLocalDataSource();
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final context = ref.watch(featureSessionProvider).context;
  return CalendarRepositoryImpl(
    ref.watch(calendarLocalDataSourceProvider),
    remote: context?.employeeId == null || context?.activeCompanyId == null
        ? null
        : DioCalendarRemoteDataSource(
            ref.watch(featureDioProvider),
            employeeId: context!.employeeId!,
          ),
  );
});
