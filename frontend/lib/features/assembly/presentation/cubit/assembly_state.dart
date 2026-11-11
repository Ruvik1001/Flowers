import 'package:equatable/equatable.dart';
import 'package:flowers/features/assembly/domain/entities/assembly.dart';

class AssemblyState extends Equatable {
  const AssemblyState({
    this.loading = false,
    this.assemblies = const [],
    this.error,
  });

  final bool loading;
  final List<Assembly> assemblies;
  final String? error;

  AssemblyState copyWith({
    bool? loading,
    List<Assembly>? assemblies,
    String? error,
    bool clearError = false,
  }) {
    return AssemblyState(
      loading: loading ?? this.loading,
      assemblies: assemblies ?? this.assemblies,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, assemblies, error];
}
