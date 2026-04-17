import 'dart:async';

import 'package:http/http.dart' as http;

class InternetRequiredService {
  static const List<String> _healthCheckUrls = <String>[
    'https://clients3.google.com/generate_204',
    'https://www.gstatic.com/generate_204',
    'https://www.google.com/generate_204',
    'https://www.msftconnecttest.com/connecttest.txt',
    'https://captive.apple.com/hotspot-detect.html',
  ];

  bool _isReachableStatus(int statusCode) {
    return (statusCode >= 200 && statusCode < 400) || statusCode == 204;
  }

  Future<bool> _probe(Uri uri) async {
    try {
      final headResponse = await http
          .head(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (_isReachableStatus(headResponse.statusCode)) {
        return true;
      }
    } on TimeoutException {
      // Fall through to GET for servers that ignore HEAD.
    } catch (_) {
      // Fall through to GET for servers that ignore HEAD.
    }

    try {
      final getResponse = await http
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
              'Range': 'bytes=0-0',
            },
          )
          .timeout(const Duration(seconds: 5));

      return _isReachableStatus(getResponse.statusCode);
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasInternetAccess() async {
    for (final url in _healthCheckUrls) {
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      if (await _probe(uri)) {
        return true;
      }
    }
    return false;
  }
}
