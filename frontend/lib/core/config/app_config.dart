class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Android emulator → host machine. Override:
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
  final String apiBaseUrl;

  static AppConfig fromEnvironment() {
    const raw = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080',
    );
    return AppConfig(apiBaseUrl: raw.replaceAll(RegExp(r'/$'), ''));
  }

  String get apiV1 => '$apiBaseUrl/api/v1';
}
