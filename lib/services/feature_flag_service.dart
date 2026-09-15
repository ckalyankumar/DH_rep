import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:dhealth/config/feature_flags.dart';

/// Listens to `appConfig/clinicalInterpretationFlags` and exposes the latest
/// [FeatureFlags]. Starts at [FeatureFlags.defaults] and returns to those
/// defaults if the document is missing, deleted, or the snapshot stream errors
/// (offline with no cache, permission denied, etc.).
///
/// Does not write to Firestore. Client writes are denied in security rules.
class FeatureFlagService {
  FeatureFlagService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    _subscription = _docRef.snapshots().listen(
      _onSnapshot,
      onError: _onError,
      cancelOnError: false,
    );
  }

  final FirebaseFirestore _db;
  final _controller = StreamController<FeatureFlags>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  FeatureFlags _current = FeatureFlags.defaults;
  var _hasEmitted = false;

  DocumentReference<Map<String, dynamic>> get _docRef => _db
      .collection(FeatureFlags.firestoreCollection)
      .doc(FeatureFlags.firestoreDocumentId);

  /// Latest resolved flags. Safe to read before the first snapshot.
  FeatureFlags get current => _current;

  /// Emits on each distinct snapshot (and the first snapshot even if it
  /// matches [FeatureFlags.defaults]).
  Stream<FeatureFlags> get flags => _controller.stream;

  void _onSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) {
      _publish(FeatureFlags.defaults);
      return;
    }
    _publish(FeatureFlags.fromMap(snap.data()));
  }

  void _onError(Object error, StackTrace stackTrace) {
    debugPrint(
      'FeatureFlagService: snapshot failed, using code defaults: $error',
    );
    _publish(FeatureFlags.defaults);
  }

  void _publish(FeatureFlags next) {
    if (_hasEmitted && next == _current) return;
    _hasEmitted = true;
    _current = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
