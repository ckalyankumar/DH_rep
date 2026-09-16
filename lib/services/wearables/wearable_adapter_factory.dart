import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';
import 'package:dhealth/services/wearables/apple_health_adapter.dart';
import 'package:dhealth/services/wearables/garmin_adapter.dart';
import 'package:dhealth/services/wearables/oura_adapter.dart';
import 'package:dhealth/services/wearables/health_connect_adapter.dart';
import 'package:dhealth/services/wearables/disabled_wearable_adapter.dart';

class WearableAdapterFactory {
  static WearableAdapter get(WearableProvider provider) {
    switch (provider) {
      case WearableProvider.fitbit:
        // Real implementation (Google Health API) lives in
        // fitbit_adapter.dart — built and tested, but intentionally not
        // routed here. See that file's header comment: parked pending
        // Google's CASA security audit cost/benefit, not a bug.
        return DisabledWearableAdapter(WearableProvider.fitbit);
      case WearableProvider.appleHealth:
        return AppleHealthAdapter();
      case WearableProvider.garmin:
        return GarminAdapter();
      case WearableProvider.oura:
        return OuraAdapter();
      case WearableProvider.samsungHealth:
      case WearableProvider.googleFit:
        // Both UI slots share one Health Connect-backed adapter.
        return HealthConnectAdapter(provider: provider);
    }
  }
}
