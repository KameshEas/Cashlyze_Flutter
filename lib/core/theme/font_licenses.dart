import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Registers the bundled typeface's licence (SIL OFL 1.1) so it appears with
/// the other open-source licences (`showLicensePage`). Call once at startup.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Geist'], text);
  });
}
