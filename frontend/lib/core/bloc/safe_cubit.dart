export 'package:flutter_bloc/flutter_bloc.dart' show Cubit, BlocBase;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Prevents "Cannot emit new states after calling close" on async completions.
abstract class SafeCubit<State> extends Cubit<State> {
  SafeCubit(super.initialState);

  @override
  void emit(State state) {
    if (!isClosed) {
      super.emit(state);
    }
  }
}
