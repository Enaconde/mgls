import 'dart:convert';

enum BackendMode { demo, supabase, unavailable }

class BackendConfig {
  const BackendConfig({required this.url, required this.anonKey});
  const BackendConfig.environment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String url;
  final String anonKey;

  BackendMode get mode {
    if (url.isEmpty && anonKey.isEmpty) return BackendMode.demo;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)))) {
      return BackendMode.unavailable;
    }
    if (anonKey.startsWith('sb_publishable_') && anonKey.length > 20) {
      return BackendMode.supabase;
    }
    // Guard against accidentally shipping a service-role JWT. This only
    // validates configuration shape; the server verifies the JWT signature.
    try {
      final parts = anonKey.split('.');
      if (parts.length != 3) return BackendMode.unavailable;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is Map && payload['role'] == 'anon') {
        return BackendMode.supabase;
      }
    } catch (_) {
      /* Fail closed without logging a key. */
    }
    return BackendMode.unavailable;
  }
}
