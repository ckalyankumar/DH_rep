// Citation identifier resolver — standing safeguard
//
// WHAT THIS IS
//   Checks that every ClinicalEvidence identifier in the app points at a real
//   registered work. It does NOT check that the paper's content matches our
//   title, authors, or keyFinding. That comparison requires a clinician.
//
// HOW TO RUN (from the repo root; needs network)
//   dart run tool/verify_citation_identifiers.dart
//
// WHAT A FAILURE MEANS
//   Exit 1: one or more identifiers do not resolve (placeholder DOI such as
//   'XXX', empty DOI with no PMID, a DOI Crossref does not know, or a PMID
//   Europe PMC / PubMed does not know). The script prints each failing entry
//   with condition, trigger/treatment location, title, and the identifier.
//   Exit 2: the script could not reach Crossref or Europe PMC (network /
//   rate-limit), so identifiers were not fully checked.
//
// WHY THIS IS NOT PART OF `flutter test`
//   Regular unit tests should run offline. This check must call Crossref and
//   Europe PMC, so it is a separate, manually-run (or CI-only) job. Do not
//   add it to the default `flutter test` suite. After clinical review lands
//   real identifiers, wire this into CI as its own job.
//
// SCOPE
//   Walks every ClinicalDisorder in DisorderRegistry, plus a file scan so a
//   new *_clinical_data.dart or an extra ClinicalEvidence( constructor cannot
//   slip in unchecked. Placeholder DOIs (empty, 'XXX', PMC-as-DOI, anything
//   that is not a 10.* DOI) fail. Empty DOI is allowed only when a resolving
//   PMID is present (some older journals have no DOI).
//
// DO NOT "FIX" CLINICAL DATA WITH THIS SCRIPT
//   A failing run against current data is expected until a dermatologist
//   signs off on identifier and keyFinding changes. See
//   docs/CITATION_AUDIT.md and docs/CLINICIAN_REVIEW_PACKET.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dhealth/data/disorder_registry.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:http/http.dart' as http;

const _knownClinicalDataFiles = {
  'psoriasis_clinical_data.dart',
  'eczema_clinical_data.dart',
};

const _placeholderDois = {'xxx', 'tbd', 'todo', 'n/a', 'none'};

final _doiPattern = RegExp(r'^10\.\d{4,9}/\S+$', caseSensitive: false);

void main() async {
  final root = _findRepoRoot();
  Directory.current = root;

  final extraFiles = _unregisteredClinicalDataFiles(root);
  final strayConstructors = _strayClinicalEvidenceConstructors(root);

  final sites = <_CitationSite>[];
  for (final disorder in _allDisorders()) {
    sites.addAll(_sitesFor(disorder));
  }

  if (sites.isEmpty) {
    stderr.writeln(
      'ERROR: no ClinicalEvidence entries found. The walker is broken.',
    );
    exit(2);
  }

  stdout.writeln(
    'Checking ${sites.length} ClinicalEvidence identifier(s) '
    '(Crossref DOI + Europe PMC PMID). Content matching is out of scope.',
  );

  final failures = <String>[];
  var networkError = false;

  for (final site in sites) {
    final result = await _checkIdentifiers(site);
    if (result.networkError) {
      networkError = true;
      stderr.writeln(result.message);
      break;
    }
    if (!result.ok) {
      failures.add(result.message);
    }
  }

  if (extraFiles.isNotEmpty) {
    failures.add(
      'FAIL  unregistered clinical-data file(s) — add them to this script '
      'and DisorderRegistry, then re-run:\n'
      '      ${extraFiles.map((f) => f.path).join('\n      ')}',
    );
  }
  if (strayConstructors.isNotEmpty) {
    failures.add(
      'FAIL  ClinicalEvidence( constructor(s) outside known clinical-data '
      'files — the identifier check will miss these until they are wired in:\n'
      '      ${strayConstructors.join('\n      ')}',
    );
  }

  if (networkError) {
    stderr.writeln(
      '\nAborted: registry APIs were unreachable. Identifiers were not fully '
      'verified. Re-run when network access to api.crossref.org and '
      'www.ebi.ac.uk is available.',
    );
    exit(2);
  }

  if (failures.isNotEmpty) {
    stderr.writeln(
      '\n${failures.length} identifier check(s) failed:\n',
    );
    for (final f in failures) {
      stderr.writeln('$f\n');
    }
    stderr.writeln(
      'A failure means the identifier does not resolve to a real registered '
      'work. It does not mean the patient-facing claim is true or false — '
      'that needs clinical review.',
    );
    exit(1);
  }

  stdout.writeln('All ${sites.length} identifier(s) resolved.');
}

List<ClinicalDisorder> _allDisorders() {
  // Keep in lockstep with DisorderRegistry.getDisorderByIndex keys.
  const keys = ['psoriasis', 'eczema'];
  return [for (final key in keys) DisorderRegistry.getDisorder(key)];
}

List<_CitationSite> _sitesFor(ClinicalDisorder disorder) {
  final condition = disorder.disorderName;
  final sites = <_CitationSite>[];
  for (final trigger in disorder.triggers) {
    for (final evidence in trigger.evidence) {
      sites.add(_CitationSite(
        condition: condition,
        location: 'Trigger: ${trigger.name}',
        evidence: evidence,
      ));
    }
  }
  for (final treatment in disorder.treatments) {
    for (final evidence in treatment.evidence) {
      sites.add(_CitationSite(
        condition: condition,
        location: 'Treatment: ${treatment.name}',
        evidence: evidence,
      ));
    }
  }
  for (final evidence in disorder.keyResearchPapers) {
    sites.add(_CitationSite(
      condition: condition,
      location: 'Key research paper',
      evidence: evidence,
    ));
  }
  return sites;
}

List<File> _unregisteredClinicalDataFiles(Directory root) {
  final dir = Directory('${root.path}/lib/data');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync()
      .whereType<File>()
      .where(
          (f) => f.path.replaceAll('\\', '/').endsWith('_clinical_data.dart'))
      .where((f) => !_knownClinicalDataFiles.contains(_basename(f.path)))
      .toList();
}

List<String> _strayClinicalEvidenceConstructors(Directory root) {
  final lib = Directory('${root.path}/lib');
  final ctor = RegExp(r'ClinicalEvidence\s*\(');
  final hits = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'.*/lib/'), 'lib/');
    if (rel.endsWith('clinical_evidence_models.dart')) continue;
    if (_knownClinicalDataFiles.any(rel.endsWith)) continue;
    final text = entity.readAsStringSync();
    if (ctor.hasMatch(text)) {
      hits.add(rel);
    }
  }
  return hits;
}

Future<_CheckResult> _checkIdentifiers(_CitationSite site) async {
  final doi = site.evidence.doi.trim();
  final pmid = site.evidence.pmid?.trim() ?? '';
  final header = 'FAIL  ${site.condition} / ${site.location}\n'
      '      title: ${site.evidence.title}';

  final doiPlaceholder = _isPlaceholderDoi(doi);
  final doiLooksReal = _doiPattern.hasMatch(doi);

  if (doiPlaceholder && pmid.isEmpty) {
    return _CheckResult.fail(
      '$header\n'
      '      doi: "${site.evidence.doi}" — empty, placeholder, or not a DOI. '
      'No PMID provided.',
    );
  }

  if (doi.isNotEmpty && !doiLooksReal) {
    return _CheckResult.fail(
      '$header\n'
      '      doi: "$doi" — not a Crossref DOI (expected 10.xxxx/...). '
      'PMC IDs, "XXX", and malformed strings fail this check.',
    );
  }

  if (doiLooksReal) {
    final doiResult = await _crossrefResolves(doi);
    if (doiResult.networkError) return doiResult;
    if (!doiResult.ok) {
      return _CheckResult.fail(
        '$header\n'
        '      doi: "$doi" — Crossref did not resolve this to a registered work.',
      );
    }
  }

  if (pmid.isNotEmpty) {
    if (!_isPlausiblePmid(pmid)) {
      return _CheckResult.fail(
        '$header\n'
        '      pmid: "$pmid" — not a numeric PubMed ID.',
      );
    }
    final pmidResult = await _pmidResolves(pmid);
    if (pmidResult.networkError) return pmidResult;
    if (!pmidResult.ok) {
      return _CheckResult.fail(
        '$header\n'
        '      pmid: "$pmid" — Europe PMC / PubMed did not resolve this to a '
        'real record.',
      );
    }
  }

  return _CheckResult.ok();
}

bool _isPlaceholderDoi(String doi) {
  if (doi.isEmpty) return true;
  if (_placeholderDois.contains(doi.toLowerCase())) return true;
  // Sentinel used in-file for "DOI not filled in" (e.g. 10.1111/bjd.xxxxx).
  if (RegExp(r'\.x{4,}$', caseSensitive: false).hasMatch(doi)) return true;
  return false;
}

bool _isPlausiblePmid(String pmid) => RegExp(r'^\d{1,8}$').hasMatch(pmid);

http.Client? _client;

http.Client get _http {
  _client ??= http.Client();
  return _client!;
}

String get _userAgent {
  final contact = Platform.environment['CITATION_CHECK_CONTACT'];
  final mailto = (contact != null && contact.contains('@'))
      ? contact
      : 'citation-check@localhost';
  return 'DHealthCitationCheck/1.0 (mailto:$mailto)';
}

Future<_CheckResult> _crossrefResolves(String doi) async {
  final uri =
      Uri.parse('https://api.crossref.org/works/${Uri.encodeComponent(doi)}');
  try {
    final response = await _http.get(
      uri,
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (response.statusCode == 200) return _CheckResult.ok();
    if (response.statusCode == 404) return _CheckResult.fail('not found');
    if (response.statusCode == 429 || response.statusCode >= 500) {
      return _CheckResult.network(
        'Crossref returned HTTP ${response.statusCode} for DOI $doi',
      );
    }
    return _CheckResult.fail('not found');
  } on SocketException catch (e) {
    return _CheckResult.network('Could not reach Crossref: $e');
  } on HttpException catch (e) {
    return _CheckResult.network('Could not reach Crossref: $e');
  } on TimeoutException {
    return _CheckResult.network('Crossref request timed out for DOI $doi');
  }
}

Future<_CheckResult> _pmidResolves(String pmid) async {
  final europePmc = Uri.https(
    'www.ebi.ac.uk',
    '/europepmc/webservices/rest/search',
    {
      'query': 'EXT_ID:$pmid AND SRC:MED',
      'format': 'json',
      'pageSize': '1',
    },
  );
  try {
    final response = await _http.get(
      europePmc,
      headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (response.statusCode == 429 || response.statusCode >= 500) {
      return _CheckResult.network(
        'Europe PMC returned HTTP ${response.statusCode} for PMID $pmid',
      );
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final hitCount = body is Map ? body['hitCount'] : null;
      if (hitCount is int && hitCount > 0) return _CheckResult.ok();
      if (hitCount is num && hitCount > 0) return _CheckResult.ok();
    }
  } on SocketException catch (e) {
    return _CheckResult.network('Could not reach Europe PMC: $e');
  } on HttpException catch (e) {
    return _CheckResult.network('Could not reach Europe PMC: $e');
  } on TimeoutException {
    return _CheckResult.network('Europe PMC request timed out for PMID $pmid');
  } on FormatException catch (e) {
    return _CheckResult.network('Europe PMC returned non-JSON: $e');
  }

  // Fallback: NCBI E-utilities (same "does this ID exist?" question).
  final pubmed = Uri.https(
    'eutils.ncbi.nlm.nih.gov',
    '/entrez/eutils/esummary.fcgi',
    {'db': 'pubmed', 'id': pmid, 'retmode': 'json'},
  );
  try {
    final response = await _http.get(
      pubmed,
      headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (response.statusCode == 429 || response.statusCode >= 500) {
      return _CheckResult.network(
        'PubMed E-utilities returned HTTP ${response.statusCode} for PMID $pmid',
      );
    }
    if (response.statusCode != 200) return _CheckResult.fail('not found');
    final body = jsonDecode(response.body);
    final result = body is Map ? body['result'] : null;
    if (result is Map && result[pmid] is Map) {
      final record = result[pmid] as Map;
      final error = record['error'];
      if (error == null) return _CheckResult.ok();
    }
    return _CheckResult.fail('not found');
  } on SocketException catch (e) {
    return _CheckResult.network('Could not reach PubMed: $e');
  } on HttpException catch (e) {
    return _CheckResult.network('Could not reach PubMed: $e');
  } on TimeoutException {
    return _CheckResult.network('PubMed request timed out for PMID $pmid');
  } on FormatException catch (e) {
    return _CheckResult.network('PubMed returned non-JSON: $e');
  }
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
          'Could not find pubspec.yaml starting from ${Directory.current.path}');
      exit(2);
    }
    dir = parent;
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').last;
}

class _CitationSite {
  final String condition;
  final String location;
  final ClinicalEvidence evidence;

  _CitationSite({
    required this.condition,
    required this.location,
    required this.evidence,
  });
}

class _CheckResult {
  final bool ok;
  final bool networkError;
  final String message;

  _CheckResult.ok()
      : ok = true,
        networkError = false,
        message = '';

  _CheckResult.fail(this.message)
      : ok = false,
        networkError = false;

  _CheckResult.network(this.message)
      : ok = false,
        networkError = true;
}
