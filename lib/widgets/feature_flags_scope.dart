import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:dhealth/config/feature_flags.dart';
import 'package:dhealth/services/feature_flag_service.dart';

/// Provides the latest [FeatureFlags] to the patient shell.
///
/// [FeatureFlagsScope.of] falls back to [FeatureFlags.defaults] when no host
/// is in the tree, so screens pumped in tests without AuthGate still compile
/// and render.
class FeatureFlagsScope extends InheritedWidget {
  final FeatureFlags flags;

  const FeatureFlagsScope({
    super.key,
    required this.flags,
    required super.child,
  });

  static FeatureFlags of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FeatureFlagsScope>();
    return scope?.flags ?? FeatureFlags.defaults;
  }

  @override
  bool updateShouldNotify(FeatureFlagsScope oldWidget) =>
      flags != oldWidget.flags;
}

/// Owns a [FeatureFlagService] snapshot listener and rebuilds
/// [FeatureFlagsScope] when remote flags change.
///
/// Wired around [MainScreen] from AuthGate (signed-in patient, onboarding
/// complete). Not used on LoginScreen, OnboardingScreen, or DoctorPortalScreen.
class FeatureFlagsHost extends StatefulWidget {
  const FeatureFlagsHost({
    super.key,
    required this.child,
    this.firestore,
    this.service,
  });

  final Widget child;
  final FirebaseFirestore? firestore;

  /// Test seam. When set, this widget does not dispose [service].
  final FeatureFlagService? service;

  @override
  State<FeatureFlagsHost> createState() => _FeatureFlagsHostState();
}

class _FeatureFlagsHostState extends State<FeatureFlagsHost> {
  late final FeatureFlagService _service;
  late final bool _ownsService;
  StreamSubscription<FeatureFlags>? _subscription;
  late FeatureFlags _flags;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service = widget.service ?? FeatureFlagService(firestore: widget.firestore);
    _flags = _service.current;
    _subscription = _service.flags.listen((flags) {
      if (!mounted || flags == _flags) return;
      setState(() => _flags = flags);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureFlagsScope(
      flags: _flags,
      child: widget.child,
    );
  }
}
