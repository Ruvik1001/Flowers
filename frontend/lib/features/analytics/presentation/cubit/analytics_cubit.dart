import 'package:flowers/core/bloc/safe_cubit.dart';
import 'package:flowers/core/errors/app_failure.dart';
import 'package:flowers/features/analytics/data/analytics_repository.dart';
import 'package:flowers/features/analytics/presentation/cubit/analytics_state.dart';

class AnalyticsCubit extends SafeCubit<AnalyticsState> {
  AnalyticsCubit(this._repository) : super(const AnalyticsState());

  final AnalyticsRepository _repository;

  Future<void> load([String? name]) async {
    final reportName = name ?? state.reportName;
    emit(
      state.copyWith(
        loading: true,
        reportName: reportName,
        clearError: true,
      ),
    );
    try {
      final report = await _repository.getReport(reportName);
      emit(
        state.copyWith(
          loading: false,
          report: report,
          clearError: true,
        ),
      );
    } on AppFailure catch (e) {
      emit(state.copyWith(loading: false, error: e.message, clearReport: true));
    } catch (e) {
      emit(
        state.copyWith(loading: false, error: e.toString(), clearReport: true),
      );
    }
  }
}
