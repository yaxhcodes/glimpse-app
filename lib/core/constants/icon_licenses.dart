import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerIconLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Glimpse iconography — Piqo Design and Epic Icon Designs',
    ], await rootBundle.loadString('assets/licenses/iconography.txt'));
  });
}
