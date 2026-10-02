import 'package:cashlyze/core/config/aspire_services_config.dart';
import 'package:cashlyze/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads api_base_url and app_name from the bundled asset', () async {
    await AspireServicesConfig.load();

    expect(AspireServicesConfig.appName, 'cashlyze');
    expect(AspireServicesConfig.apiBaseUrl, 'https://api.aspired2d.cloud');
    expect(EnvConfig.baseUrl, 'https://api.aspired2d.cloud/api/v1/cashlyze');
  });
}
