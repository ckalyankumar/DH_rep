import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhealth/config/feature_flags.dart';
import 'package:dhealth/services/feature_flag_service.dart';
import 'package:dhealth/widgets/feature_flags_scope.dart';

class _FlagsProbe extends StatelessWidget {
  const _FlagsProbe();

  @override
  Widget build(BuildContext context) {
    final flags = FeatureFlagsScope.of(context);
    return Text('recs:${flags.showRecommendations}|risk:${flags.showRiskScore}');
  }
}

void main() {
  testWidgets('of() without a host falls back to code defaults', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _FlagsProbe())),
    );

    expect(find.text('recs:false|risk:true'), findsOneWidget);
  });

  testWidgets('host with a missing Firestore doc keeps defaults', (tester) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      MaterialApp(
        home: FeatureFlagsHost(
          firestore: db,
          child: const Scaffold(body: _FlagsProbe()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('recs:false|risk:true'), findsOneWidget);
    expect(find.byType(FeatureFlagsScope), findsOneWidget);
  });

  testWidgets('host rebuilds descendants when remote flags change',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db
        .collection(FeatureFlags.firestoreCollection)
        .doc(FeatureFlags.firestoreDocumentId)
        .set({
      FeatureFlags.showRecommendationsKey: true,
      FeatureFlags.showRiskScoreKey: false,
    });
    final service = FeatureFlagService(firestore: db);
    addTearDown(service.dispose);
    await service.flags.first.timeout(const Duration(seconds: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: FeatureFlagsHost(
          service: service,
          child: const Scaffold(body: _FlagsProbe()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('recs:true|risk:false'), findsOneWidget);

    final updated = service.flags.first.timeout(const Duration(seconds: 2));
    await db
        .collection(FeatureFlags.firestoreCollection)
        .doc(FeatureFlags.firestoreDocumentId)
        .update({FeatureFlags.showRecommendationsKey: false});
    await updated;
    await tester.pump();

    expect(find.text('recs:false|risk:false'), findsOneWidget);
  });
}
