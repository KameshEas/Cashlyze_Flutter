import 'package:cashlyze/core/api/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiEndpoints.wsUser builds wss URL without explicit port', () {
    final url = ApiEndpoints.wsUser('user123', 'tokenABC');
    final uri = Uri.parse(url);

    expect(uri.scheme, equals('wss'));
    expect(uri.host, equals('api.aspired2d.cloud'));
    expect(uri.path, contains('/ws/user/user123'));
    // When no port is present in the URI string, Uri.port returns 0.
    expect(uri.hasPort, isFalse);
    expect(uri.port, equals(0));
  });
}
