import 'package:flutter_test/flutter_test.dart';
import 'package:flowers/app/theme/app_theme.dart';

void main() {
  test('theme builds', () {
    final theme = buildAppTheme();
    expect(theme.useMaterial3, isTrue);
  });
}
