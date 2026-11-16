import 'dart:html' as html;

/// Plain localStorage tokens for Flutter web (avoids secure_storage crypto nulls).
class TokenStorage {
  TokenStorage();

  static const _accessKey = 'flowers_access_token';
  static const _refreshKey = 'flowers_refresh_token';

  Future<String?> readAccess() async => html.window.localStorage[_accessKey];

  Future<String?> readRefresh() async => html.window.localStorage[_refreshKey];

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    html.window.localStorage[_accessKey] = accessToken;
    html.window.localStorage[_refreshKey] = refreshToken;
  }

  Future<void> clear() async {
    html.window.localStorage.remove(_accessKey);
    html.window.localStorage.remove(_refreshKey);
  }
}
