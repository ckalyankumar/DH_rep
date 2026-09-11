// Clinical evidence review enforcement — standing safeguard
//
// WHAT THIS IS
//   Every live ClinicalEvidence row in the app must have a matching *approved*
//   clinicalEvidenceReviews document in Firestore, and must not have an open
//   emergency disable. This is the structural gate so a citation / keyFinding /
//   GRADE rating cannot reach the live app without named human review.
//
//   Companion to tool/verify_citation_identifiers.dart (which only checks that
//   DOIs/PMIDs resolve). This script does not replace that check.
//
// HOW TO RUN (from the repo root)
//   dart run tool/verify_clinical_evidence_reviews.dart
//
//   Firestore target, in order:
//     1. FIRESTORE_EMULATOR_HOST  — emulator, no auth
//     2. Production project (default dhealth-fb17e) with a Google OAuth token:
//          FIRESTORE_ACCESS_TOKEN           explicit Bearer token
//          gcloud auth application-default print-access-token
//          gcloud auth print-access-token
//
//   Optional:
//     FIREBASE_PROJECT_ID   (default dhealth-fb17e)
//
// WHAT A FAILURE MEANS
//   Exit 1: one or more live entries are out of compliance. Each block names
//   the entry and the reason:
//     never-reviewed        — no approved review for this entryRef
//     content-mismatch      — an approved review exists, but title/authors/doi/
//                             pmid/keyFinding/gradeLevel do not match live data
//     disabled-unresolved   — an open emergency disable covers this entry;
//                             it must not ship until a human restores or
//                             revokes it. This is flagged separately from a
//                             missing review; it is still a non-zero exit
//                             because the claim is still in the dart files.
//   Exit 2: could not read Firestore (auth, network, unexpected API error),
//   so compliance was not verified.
//
// WHY THIS IS NOT PART OF `flutter test`
//   Regular unit tests should run offline. Matching logic is covered by
//   test/clinical_review/clinical_evidence_compliance_test.dart using
//   FakeFirebaseFirestore. This script talks to a real Firestore (or the
//   emulator) and is a separate, manually-run (or CI-only) job.
//
// DO NOT "FIX" CLINICAL DATA WITH THIS SCRIPT
//   A failing run against current psoriasis/eczema data is expected until a
//   dermatologist signs off. See docs/CITATION_AUDIT.md,
//   docs/CLINICIAN_REVIEW_PACKET.md, and docs/CLINICAL_EVIDENCE_REVIEW.md.

import 'dart:convert';
import 'dart:io';

import 'package:dhealth/clinical_review/clinical_evidence_catalog.dart';
import 'package:dhealth/clinical_review/clinical_evidence_catalog_io.dart';
import 'package:dhealth/clinical_review/clinical_evidence_compliance.dart';
import 'package:dhealth/clinical_review/clinical_review_schema.dart';
import 'package:http/http.dart' as http;

const _defaultProjectId = 'dhealth-fb17e';

void main() async {
  final root = _findRepoRoot();
  Directory.current = root;

  final extraFiles =
      ClinicalEvidenceCatalogIo.unregisteredClinicalDataFiles(root);
  final strayConstructors =
      ClinicalEvidenceCatalogIo.strayClinicalEvidenceConstructors(root);
  final liveSites = ClinicalEvidenceCatalog.allLiveSites();

  if (liveSites.isEmpty) {
    stderr.writeln(
      'ERROR: no ClinicalEvidence entries found. The walker is broken.',
    );
    exit(2);
  }

  stdout.writeln(
    'Checking ${liveSites.length} live ClinicalEvidence entry(ies) against '
    'Firestore ${ClinicalReviewSchema.reviewsCollection} + '
    '${ClinicalReviewSchema.emergencyActionsCollection}.',
  );

  final List<ClinicalEvidenceReviewDoc> reviews;
  final List<EmergencyActionDoc> actions;
  try {
    final fetched = await _fetchFirestoreDocs();
    reviews = fetched.reviews;
    actions = fetched.actions;
  } on _FirestoreAccessException catch (e) {
    stderr.writeln('\nAborted: could not read Firestore.\n${e.message}');
    exit(2);
  }

  stdout.writeln(
    'Firestore: ${reviews.length} review(s), ${actions.length} emergency '
    'action(s). Target: ${_describeTarget()}',
  );

  final report = ClinicalEvidenceComplianceChecker.check(
    liveSites: liveSites,
    reviews: reviews,
    emergencyActions: actions,
  );

  final structural = <String>[];
  if (extraFiles.isNotEmpty) {
    structural.add(
      'FAIL  unregistered clinical-data file(s) — add them to '
      'ClinicalEvidenceCatalog and DisorderRegistry, then re-run:\n'
      '      ${extraFiles.map((f) => f.path).join('\n      ')}',
    );
  }
  if (strayConstructors.isNotEmpty) {
    structural.add(
      'FAIL  ClinicalEvidence( constructor(s) outside known clinical-data '
      'files — this check will miss these until they are wired in:\n'
      '      ${strayConstructors.join('\n      ')}',
    );
  }

  if (report.failures.isNotEmpty || structural.isNotEmpty) {
    final n = report.failures.length + structural.length;
    stderr.writeln('\n$n compliance check(s) failed:\n');
    for (final f in report.failures) {
      stderr.writeln('${f.toReportBlock()}\n');
    }
    for (final s in structural) {
      stderr.writeln('$s\n');
    }
    stderr.writeln(
      'A failure means this live entry must not ship: it was never approved, '
      'its live fields do not match what was approved, or it is under an open '
      'emergency disable. Identifier resolution is a separate check '
      '(tool/verify_citation_identifiers.dart).',
    );
    stderr.writeln(
      'Counts: ${report.liveEntryCount} live, '
      '${report.approvedReviewCount} approved review(s), '
      '${report.openDisableCount} open disable(s), '
      '${report.failures.length} entry failure(s).',
    );
    exit(1);
  }

  stdout.writeln(
    'All ${report.liveEntryCount} live entry(ies) have a matching approved '
    'review and no open emergency disable.',
  );
}

class _FetchedDocs {
  final List<ClinicalEvidenceReviewDoc> reviews;
  final List<EmergencyActionDoc> actions;
  _FetchedDocs({required this.reviews, required this.actions});
}

class _FirestoreAccessException implements Exception {
  final String message;
  _FirestoreAccessException(this.message);
}

String _projectId() =>
    Platform.environment['FIREBASE_PROJECT_ID'] ?? _defaultProjectId;

String? _emulatorHost() {
  final raw = Platform.environment['FIRESTORE_EMULATOR_HOST'];
  if (raw == null || raw.trim().isEmpty) return null;
  return raw.trim();
}

String _describeTarget() {
  final emulator = _emulatorHost();
  if (emulator != null) return 'emulator $emulator / project ${_projectId()}';
  return 'production ${_projectId()}';
}

Future<_FetchedDocs> _fetchFirestoreDocs() async {
  final client = http.Client();
  try {
    final token = await _accessToken();
    final reviews = await _listCollection(
      client: client,
      collection: ClinicalReviewSchema.reviewsCollection,
      token: token,
    );
    final actions = await _listCollection(
      client: client,
      collection: ClinicalReviewSchema.emergencyActionsCollection,
      token: token,
    );
    return _FetchedDocs(
      reviews: [
        for (final doc in reviews)
          ClinicalEvidenceReviewDoc.fromMap(doc.id, doc.fields),
      ],
      actions: [
        for (final doc in actions)
          EmergencyActionDoc.fromMap(doc.id, doc.fields),
      ],
    );
  } finally {
    client.close();
  }
}

class _RestDoc {
  final String id;
  final Map<String, dynamic> fields;
  _RestDoc({required this.id, required this.fields});
}

Future<List<_RestDoc>> _listCollection({
  required http.Client client,
  required String collection,
  required String? token,
}) async {
  final docs = <_RestDoc>[];
  String? pageToken;
  do {
    final uri = _collectionUri(collection, pageToken);
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    // Firestore emulator accepts this dummy token when rules would otherwise
    // deny unauthenticated access.
    if (token == null && _emulatorHost() != null) {
      headers['Authorization'] = 'Bearer owner';
    }

    final response = await client.get(uri, headers: headers).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw _FirestoreAccessException(
        'Firestore returned HTTP ${response.statusCode} listing "$collection". '
        'Sign in with a Google account that can read this project, then set '
        'FIRESTORE_ACCESS_TOKEN or install gcloud and run '
        '`gcloud auth application-default login`, or point '
        'FIRESTORE_EMULATOR_HOST at a local emulator.\n'
        'Body: ${_clip(response.body)}',
      );
    }
    if (response.statusCode >= 500) {
      throw _FirestoreAccessException(
        'Firestore returned HTTP ${response.statusCode} listing "$collection". '
        'Retry when the service is reachable.\nBody: ${_clip(response.body)}',
      );
    }
    if (response.statusCode != 200) {
      throw _FirestoreAccessException(
        'Firestore returned HTTP ${response.statusCode} listing "$collection".\n'
        'Body: ${_clip(response.body)}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw _FirestoreAccessException(
        'Firestore list for "$collection" was not a JSON object.',
      );
    }
    final documents = decoded['documents'];
    if (documents is List) {
      for (final raw in documents) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString() ?? '';
        final id = name.split('/').isEmpty ? name : name.split('/').last;
        final fields = _decodeFields(raw['fields']);
        docs.add(_RestDoc(id: id, fields: fields));
      }
    }
    final next = decoded['nextPageToken'];
    pageToken = (next is String && next.isNotEmpty) ? next : null;
  } while (pageToken != null);
  return docs;
}

Uri _collectionUri(String collection, String? pageToken) {
  final emulator = _emulatorHost();
  final project = _projectId();
  final path =
      '/v1/projects/$project/databases/(default)/documents/$collection';
  final query = <String, String>{'pageSize': '300'};
  if (pageToken != null) query['pageToken'] = pageToken;

  if (emulator != null) {
    final host = emulator.contains('://')
        ? emulator
        : 'http://$emulator';
    return Uri.parse('$host$path').replace(queryParameters: query);
  }
  return Uri.https('firestore.googleapis.com', path, query);
}

/// Returns a Bearer token for production, or null for the emulator.
Future<String?> _accessToken() async {
  if (_emulatorHost() != null) return null;

  final explicit = Platform.environment['FIRESTORE_ACCESS_TOKEN'];
  if (explicit != null && explicit.trim().isNotEmpty) {
    return explicit.trim();
  }

  final fromGcloud = await _gcloudAccessToken();
  if (fromGcloud != null) return fromGcloud;

  throw _FirestoreAccessException(
    'No Firestore credentials. This script needs to list '
    '${ClinicalReviewSchema.reviewsCollection} in project ${_projectId()}.\n'
    'Provide one of:\n'
    '  - FIRESTORE_EMULATOR_HOST=localhost:8080 (empty emulator = all live '
    'entries fail never-reviewed, which is expected today)\n'
    '  - FIRESTORE_ACCESS_TOKEN=<oauth access token>\n'
    '  - gcloud (`gcloud auth application-default login`)',
  );
}

Future<String?> _gcloudAccessToken() async {
  for (final args in [
    ['auth', 'application-default', 'print-access-token'],
    ['auth', 'print-access-token'],
  ]) {
    try {
      final result = await Process.run('gcloud', args, runInShell: true);
      if (result.exitCode == 0) {
        final token = result.stdout.toString().trim();
        if (token.isNotEmpty && !token.contains(' ')) return token;
      }
    } on ProcessException {
      // gcloud not installed
    }
  }
  return null;
}

Map<String, dynamic> _decodeFields(Object? fields) {
  if (fields is! Map) return <String, dynamic>{};
  final out = <String, dynamic>{};
  fields.forEach((key, value) {
    out[key.toString()] = _decodeValue(value);
  });
  return out;
}

Object? _decodeValue(Object? value) {
  if (value is! Map) return value;
  if (value.containsKey('stringValue')) return value['stringValue'];
  if (value.containsKey('integerValue')) {
    return int.tryParse(value['integerValue'].toString()) ??
        value['integerValue'];
  }
  if (value.containsKey('doubleValue')) return value['doubleValue'];
  if (value.containsKey('booleanValue')) return value['booleanValue'];
  if (value.containsKey('nullValue')) return null;
  if (value.containsKey('timestampValue')) {
    final raw = value['timestampValue'];
    if (raw is String) return DateTime.tryParse(raw) ?? raw;
    return raw;
  }
  if (value.containsKey('mapValue')) {
    final inner = value['mapValue'];
    if (inner is Map) return _decodeFields(inner['fields']);
    return <String, dynamic>{};
  }
  if (value.containsKey('arrayValue')) {
    final inner = value['arrayValue'];
    final values = inner is Map ? inner['values'] : null;
    if (values is List) return values.map(_decodeValue).toList();
    return <Object?>[];
  }
  return value;
}

String _clip(String body) {
  final trimmed = body.trim();
  if (trimmed.length <= 400) return trimmed;
  return '${trimmed.substring(0, 400)}…';
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
        'Could not find pubspec.yaml starting from ${Directory.current.path}',
      );
      exit(2);
    }
    dir = parent;
  }
}
