import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/wearables/wearable_adapter.dart';
import 'package:dhealth/services/wearables/fitbit_adapter.dart';
import 'package:dhealth/services/wearables/apple_health_adapter.dart';
import 'package:dhealth/services/wearables/garmin_adapter.dart';
import 'package:dhealth/services/wearables/oura_adapter.dart';
import 'package:dhealth/services/wearables/samsung_adapter.dart';
import 'package:dhealth/services/wearables/google_fit_adapter.dart';

class WearableAdapterFactory {
  static WearableAdapter get(WearableProvider provider) {
    switch (provider) {
      case WearableProvider.fitbit:
        return FitbitAdapter();
      case WearableProvider.appleHealth:
        return AppleHealthAdapter();
      case WearableProvider.garmin:
        return GarminAdapter();
      case WearableProvider.oura:
        return OuraAdapter();
      case WearableProvider.samsungHealth:
        return SamsungAdapter();
      case WearableProvider.googleFit:
        return GoogleFitAdapter();
    }
  }
}
