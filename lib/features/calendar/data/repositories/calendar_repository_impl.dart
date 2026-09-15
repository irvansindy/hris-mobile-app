import 'package:hrm_app/features/calendar/data/datasources/calendar_local_datasource.dart';
import 'package:hrm_app/features/calendar/domain/entities/calendar_data.dart';
import 'package:hrm_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:hrm_app/features/calendar/data/datasources/calendar_remote_datasource.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  CalendarRepositoryImpl(this._local, {this.remote});
  final CalendarLocalDataSource _local;
  final DioCalendarRemoteDataSource? remote;

  @override
  CalendarData get current => _local.read();

  @override
  Future<CalendarData> loadMonth(int year, int month) async =>
      remote == null ? _local.read() : remote!.loadMonth(year, month);
}
