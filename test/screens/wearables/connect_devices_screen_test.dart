import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/screens/wearables/connect_devices_screen.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/services/wearable_sync_service.dart';

void main() {
  testWidgets(
      'Fitbit is parked (built and tested, not scheduled) — its card is '
      'hidden from the connect-devices grid, while every other provider '
      'still renders', (tester) async {
    final repo = WearableRepository(firestore: FakeFirebaseFirestore());
    final vm = WearableViewModel(
      uid: 'test-uid',
      repo: repo,
      sync: WearableSyncService(repo: repo),
    );

    await tester.pumpWidget(
      MaterialApp(home: ConnectDevicesScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fitbit'), findsNothing);

    // Every non-Fitbit provider still renders — confirms this is a
    // targeted omission, not a broken/empty grid.
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.text('Garmin'), findsOneWidget);
    expect(find.text('Oura'), findsOneWidget);
    expect(find.text('Samsung Health'), findsOneWidget);
    expect(find.text('Google Fit'), findsOneWidget);
  });
}
