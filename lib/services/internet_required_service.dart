import 'dart:async';

import 'package:http/http.dart' as http;

class InternetRequiredService {
  static const List<String> _healthCheckUrls = <String>[
    'https://clients3.google.com/generate_204',
    'https://www.google.com/generate_204',
  ];

  bool _isReachableStatus(int statusCode) {
    return (statusCode >= 200 && statusCode < 400) || statusCode == 204;
  }

  Future<bool> hasInternetAccess() async {
    for (final url in _healthCheckUrls) {
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      try {
        final response = await http.get(
          uri,
          headers: const {
            'Cache-Control': 'no-cache',
            'Range': 'bytes=0-0',
          },
        ).timeout(const Duration(seconds: 5));
        if (_isReachableStatus(response.statusCode)) {
          return true;
        }
      } on TimeoutException {
        // Try the next endpoint.
      } catch (_) {
        // Try the next endpoint.
      }
    }
    return false;
  }
}
