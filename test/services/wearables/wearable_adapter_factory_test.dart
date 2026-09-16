import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/wearables/disabled_wearable_adapter.dart';
import 'package:dhealth/services/wearables/fitbit_adapter.dart';
import 'package:dhealth/services/wearables/health_connect_adapter.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';
import 'package:dhealth/services/wearables/wearable_adapter_factory.dart';

void main() {
  group('WearableAdapterFactory', () {
    test(
        'fitbit is parked: routes to DisabledWearableAdapter, not FitbitAdapter',
        () {
      final adapter = WearableAdapterFactory.get(WearableProvider.fitbit);

      expect(adapter, isA<DisabledWearableAdapter>());
      expect(adapter, isNot(isA<FitbitAdapter>()));
      expect(adapter.provider, WearableProvider.fitbit);
    });

    test(
        'the parked fitbit adapter fails fast without attempting a real OAuth call',
        () {
      final adapter = WearableAdapterFactory.get(WearableProvider.fitbit);

      expect(
        () => adapter.authenticate(),
        throwsA(isA<WearableAuthException>()),
      );
    });

    test('every other provider still routes to its own concrete adapter', () {
      expect(
        WearableAdapterFactory.get(WearableProvider.appleHealth).provider,
        WearableProvider.appleHealth,
      );
      expect(
        WearableAdapterFactory.get(WearableProvider.garmin).provider,
        WearableProvider.garmin,
      );
      expect(
        WearableAdapterFactory.get(WearableProvider.oura).provider,
        WearableProvider.oura,
      );
      final samsung =
          WearableAdapterFactory.get(WearableProvider.samsungHealth);
      expect(samsung, isA<HealthConnectAdapter>());
      expect(samsung.provider, WearableProvider.samsungHealth);
      final googleFit = WearableAdapterFactory.get(WearableProvider.googleFit);
      expect(googleFit, isA<HealthConnectAdapter>());
      expect(googleFit.provider, WearableProvider.googleFit);
    });
  });
}
