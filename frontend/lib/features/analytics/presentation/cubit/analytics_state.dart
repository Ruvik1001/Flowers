import 'package:equatable/equatable.dart';

class AnalyticsState extends Equatable {
  const AnalyticsState({
    this.loading = false,
    this.reportName = 'revenue-by-day',
    this.report,
    this.error,
  });

  final bool loading;
  final String reportName;
  final Map<String, dynamic>? report;
  final String? error;

  AnalyticsState copyWith({
    bool? loading,
    String? reportName,
    Map<String, dynamic>? report,
    String? error,
    bool clearError = false,
    bool clearReport = false,
  }) {
    return AnalyticsState(
      loading: loading ?? this.loading,
      reportName: reportName ?? this.reportName,
      report: clearReport ? null : (report ?? this.report),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, reportName, report, error];
}
