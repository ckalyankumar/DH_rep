// One-off: submit the CITATION_AUDIT.md findings into the clinical evidence
// review queue so a dermatologist can review them inside the portal
// (lib/clinical_review_portal/) instead of a standalone document.
//
// WHAT THIS DOES
//   For every one of the 29 live ClinicalEvidence entries in
//   lib/data/psoriasis_clinical_data.dart and lib/data/eczema_clinical_data.dart,
//   creates ONE 'pending' clinicalEvidenceReviews document:
//     - entryRef            -> identifies the live slot (matches
//                              ClinicalEvidenceCatalog.allLiveSites()).
//     - previousContent     -> the live (unverified) fields, unchanged.
//     - proposedContent     -> the audit's identifier correction (title,
//                              authors, year, journal, doi, pmid, url) where
//                              one was found. keyFinding / citationCount /
//                              evidenceType are left exactly as they are live
//                              — this script does NOT rewrite any clinical
//                              claim. Per CITATION_AUDIT.md instruction #5,
//                              that requires the dermatologist's sign-off,
//                              which is exactly what this review queue is for.
//     - reviewNotes         -> a condensed version of that entry's audit
//                              finding, including which entries the audit
//                              recommends REJECTING outright (no real source
//                              found) and which have more than one candidate
//                              real paper (the reviewer's call).
//
//   This does NOT touch lib/data/psoriasis_clinical_data.dart or
//   eczema_clinical_data.dart. Nothing ships to patients until a
//   clinicalReviewer/clinicalAdmin approves matching content in the portal
//   AND that approved content is copied into the dart files by hand (or a
//   future PR) — this script only files the pending requests.
//
// HOW TO RUN (from the repo root)
//   PORTAL_ADMIN_EMAIL=you@example.com PORTAL_ADMIN_PASSWORD=... \
//     dart run tool/submit_citation_audit_reviews.dart
//
//   The signed-in account can be ANY Firebase Auth user in this project —
//   firestore.rules lets any authenticated user create a 'pending' review
//   (see docs/CLINICAL_EVIDENCE_REVIEW.md, "Why any authenticated user may
//   submit"). It does NOT need to be clinicalReviewer/clinicalAdmin. If you
//   don't have an account yet, create one via Firebase Console ->
//   Authentication -> Add user (email + password), or run this once against
//   the account you're about to promote to clinicalAdmin.
//
//   Optional: FIREBASE_PROJECT_ID (default dhealth-fb17e), FIREBASE_API_KEY
//   (default: this project's public Web API key, same one already in
//   lib/firebase_options.dart — safe to share, it is not a secret).
//
// WHY A FIREBASE ID TOKEN, NOT THE IAM ACCESS TOKEN FROM THE OTHER SCRIPTS
//   tool/verify_clinical_evidence_reviews.dart authenticates with a Google
//   Cloud IAM/OAuth token, which BYPASSES firestore.rules (that's why it's
//   restricted to a read-only datastore.viewer service account). Creating a
//   review the way a real reviewer/submitter would means going through
//   firestore.rules, which only happens with a Firebase Auth ID token. So
//   this script signs in with the Identity Platform REST API and sends that
//   ID token as the bearer token instead.
//
// RUN ONCE
//   Re-running creates duplicate pending reviews for the same entryRef
//   (Firestore auto-generates document IDs; there's no upsert). If you need
//   to re-run after fixing something, delete the previous pending docs for
//   that entryRef in the Firebase console first, or just let the
//   dermatologist reject the stale one.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _defaultProjectId = 'dhealth-fb17e';
// Public Web API key from lib/firebase_options.dart (web config). This is a
// client identifier, not a secret — the same value ships inside the Flutter
// web build.
const _defaultApiKey = 'AIzaSyCeNkq4Liulj7hsDTq1Bpn6U-FxBKXopOA';

Map<String, dynamic> _content({
  required String title,
  required String authors,
  required String year,
  required String journal,
  required String doi,
  String? pmid,
  required String url,
  required String keyFinding,
  required int citationCount,
  required String evidenceType,
}) {
  return {
    'title': title,
    'authors': authors,
    'year': year,
    'journal': journal,
    'doi': doi,
    'pmid': pmid,
    'url': url,
    'keyFinding': keyFinding,
    'citationCount': citationCount,
    'evidenceType': evidenceType,
    'gradeLevel': null,
  };
}

class _Seed {
  final String condition;
  final String location;
  final int ordinal;
  final Map<String, dynamic> previousContent;
  final Map<String, dynamic> proposedContent;
  final String reviewNotes;

  const _Seed({
    required this.condition,
    required this.location,
    required this.ordinal,
    required this.previousContent,
    required this.proposedContent,
    required this.reviewNotes,
  });

  /// entryRef.title must be the LIVE title (identifies the slot), not the
  /// proposed corrected title.
  String get liveTitle => previousContent['title'] as String;
}

final List<_Seed> _seeds = [
  // ───────────────────────────── PSORIASIS ─────────────────────────────

  // P6a — Trigger: Psychological Stress, ordinal 0 (Liu et al.)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Psychological Stress',
    ordinal: 0,
    previousContent: _content(
      title: 'Triggers for the onset and recurrence of psoriasis: a comprehensive review',
      authors: 'Liu S, Li D, Yu Y',
      year: '2024',
      journal: 'NIH/PMC',
      doi: 'PMC10860266',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC10860266/',
      keyFinding: 'Stress reported as trigger in 57.8% at onset, 94.8% at recurrence (n=15,467 subjects)',
      citationCount: 28,
      evidenceType: 'meta_analysis',
    ),
    proposedContent: _content(
      title: 'Triggers for the onset and recurrence of psoriasis: a review and update',
      authors: 'Liu S, He M, Jiang J, et al.',
      year: '2024',
      journal: 'Cell Communication and Signaling',
      doi: '10.1186/s12964-023-01381-0',
      pmid: '38347543',
      url: 'https://doi.org/10.1186/s12964-023-01381-0',
      keyFinding: 'Stress reported as trigger in 57.8% at onset, 94.8% at recurrence (n=15,467 subjects)',
      citationCount: 28,
      evidenceType: 'meta_analysis',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P6): "PMC10860266" was used as the doi field (not a real DOI) — '
        'corrected identifier is Liu S, He M, Jiang J, et al., Cell Commun Signal 2024;22(1):108, '
        'DOI 10.1186/s12964-023-01381-0, PMID 38347543. \u{1F6A9} keyFinding is UNCHANGED but is '
        'FABRICATED: the real paper\'s only quantitative stress statement is "31-88% of cases '
        'reported stress as a trigger" — it does not contain the 57.8%/94.8%/n=15,467 figures shown '
        'here. Same fabricated stat also appears in "Trigger: Skin Trauma (Koebner Phenomenon)" and '
        '"Key research paper" ordinal 0 (same underlying paper, used 3x). Needs your decision: reject '
        'until keyFinding is rewritten to the real 31-88% range, or approve identifier only and open '
        'a follow-up review for the keyFinding text.',
  ),

  // P8 — Trigger: Psychological Stress, ordinal 1 (Frontiers)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Psychological Stress',
    ordinal: 1,
    previousContent: _content(
      title: 'Psychological Stress and Psoriasis Pathogenesis',
      authors: 'Multiple authors - Frontiers Medicine',
      year: '2025',
      journal: 'Frontiers in Medicine',
      doi: '10.3389/fmed.2025.1614863',
      url: 'https://www.frontiersin.org/journals/medicine/articles/10.3389/fmed.2025.1614863',
      keyFinding:
          'Systematic review of 68 studies confirms bidirectional stress-psoriasis relationship with HPA axis dysregulation',
      citationCount: 156,
      evidenceType: 'meta_analysis',
    ),
    proposedContent: _content(
      title: 'The role of psychological stress in the pathogenesis of psoriasis',
      authors: 'Lei D, Gong C, Wang B, et al.',
      year: '2025',
      journal: 'Frontiers in Medicine',
      doi: '10.3389/fmed.2025.1614863',
      pmid: '40861201',
      url: 'https://doi.org/10.3389/fmed.2025.1614863',
      keyFinding:
          'Systematic review of 68 studies confirms bidirectional stress-psoriasis relationship with HPA axis dysregulation',
      citationCount: 156,
      evidenceType: 'meta_analysis',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P8): DOI was already correct; title/authors were wrong and pmid was '
        'missing. ⚠️ keyFinding UNCHANGED but flagged: the real paper is a narrative review, not '
        'a "systematic review of 68 studies" — that count could not be confirmed. citationCount 156 is '
        'also implausible for a mid-2025 paper (left alone per your instruction).',
  ),

  // P9 — Trigger: Psychological Stress, ordinal 2 (Brain-Skin Connection)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Psychological Stress',
    ordinal: 2,
    previousContent: _content(
      title: 'Brain-Skin Connection: Stress, Inflammation and Skin Aging',
      authors: 'Choi H, Ahn J, Woo JS, et al.',
      year: '2014',
      journal: 'International Journal of Molecular Sciences',
      doi: '10.3390/ijms151218684',
      url: 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4273987/',
      keyFinding:
          '440+ citations. Detailed neuroimmune mechanisms: substance P, CGRP, neuropeptides in skin-brain axis',
      citationCount: 440,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'Brain-skin connection: stress, inflammation and skin aging',
      authors: 'Chen Y, Lyga J',
      year: '2014',
      journal: 'Inflammation & Allergy Drug Targets',
      doi: '10.2174/1871528113666140522104422',
      pmid: '24853682',
      url: 'https://doi.org/10.2174/1871528113666140522104422',
      keyFinding:
          '440+ citations. Detailed neuroimmune mechanisms: substance P, CGRP, neuropeptides in skin-brain axis',
      citationCount: 440,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P9): existing DOI resolves to nothing (Crossref 404) and the wrong '
        'journal/authors were listed. Corrected to the real paper (Chen Y, Lyga J, Inflamm Allergy '
        'Drug Targets 2014). keyFinding not separately flagged as fabricated — no change proposed.',
  ),

  // P7 — Trigger: Bacterial Infection (Streptococcal)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Bacterial Infection (Streptococcal)',
    ordinal: 0,
    previousContent: _content(
      title: 'Streptococcal Trigger of Psoriasis',
      authors: 'Baker et al.',
      year: '2019',
      journal: 'Clinical Dermatology Reviews',
      doi: '10.1016/j.det.2018.08.003',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      keyFinding:
          'Throat infections precede psoriasis onset in 29.4% of cases; guttate form follows strep by 2-3 weeks',
      citationCount: 78,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'Psoriasis - as an autoimmune disease caused by molecular mimicry',
      authors: 'Valdimarsson H, Thorleifsdottir RH, Sigurdardottir SL, et al.',
      year: '2009',
      journal: 'Trends in Immunology',
      doi: '10.1016/j.it.2009.07.008',
      pmid: '19781993',
      url: 'https://doi.org/10.1016/j.it.2009.07.008',
      keyFinding:
          'Throat infections precede psoriasis onset in 29.4% of cases; guttate form follows strep by 2-3 weeks',
      citationCount: 78,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P7): existing DOI resolves to an unrelated melanoma article and no '
        '"Baker et al. 2019" streptococcal-psoriasis paper could be found. Swapped to Valdimarsson et '
        'al. 2009, which supports the M-protein/keratin cross-reactivity mechanism text. ⚠️ '
        'keyFinding UNCHANGED but flagged: the "29.4%" figure is identical to this trigger\'s '
        'baselineIncidence field and looks back-filled rather than sourced from a paper; the 2-3 week '
        'guttate latency is well established. Please confirm or replace the 29.4% figure.',
  ),

  // P6b — Trigger: Skin Trauma (Koebner Phenomenon)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Skin Trauma (Koebner Phenomenon)',
    ordinal: 0,
    previousContent: _content(
      title: 'Triggers for the onset and recurrence of psoriasis',
      authors: 'Liu et al.',
      year: '2024',
      journal: 'NIH/PMC',
      doi: 'PMC10860266',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC10860266/',
      keyFinding: 'Skin trauma (12.8%), surgery (8.1%), tattoos (6.2%) reported; Koebner positive in ~25% of patients',
      citationCount: 28,
      evidenceType: 'meta_analysis',
    ),
    proposedContent: _content(
      title: 'Triggers for the onset and recurrence of psoriasis: a review and update',
      authors: 'Liu S, He M, Jiang J, et al.',
      year: '2024',
      journal: 'Cell Communication and Signaling',
      doi: '10.1186/s12964-023-01381-0',
      pmid: '38347543',
      url: 'https://doi.org/10.1186/s12964-023-01381-0',
      keyFinding: 'Skin trauma (12.8%), surgery (8.1%), tattoos (6.2%) reported; Koebner positive in ~25% of patients',
      citationCount: 28,
      evidenceType: 'meta_analysis',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P6): same Liu et al. paper as "Trigger: Psychological Stress" '
        'ordinal 0 and "Key research paper" ordinal 0 — same identifier correction. \u{1F6A9} '
        'keyFinding UNCHANGED but FABRICATED: none of "skin trauma 12.8%", "surgery 8.1%", "tattoos '
        '6.2%", or "Koebner positive ~25%" appear in the real paper. Needs your decision.',
  ),

  // P1 — Trigger: Cold Weather & Low Humidity, ordinal 0 (Kroah-Hartman)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Cold Weather & Low Humidity',
    ordinal: 0,
    previousContent: _content(
      title: 'Environmental Triggers of Psoriasis: Insights from a UK Patient Cohort',
      authors: 'Kroah-Hartman et al.',
      year: '2025',
      journal: 'British Journal of Dermatology',
      doi: '10.1111/bjd.xxxxx',
      url: 'https://academic.oup.com/bjd',
      keyFinding:
          '67.2% report winter worsening; temperature, humidity, and light all independently correlate with disease activity',
      citationCount: 45,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'Environmental triggers of psoriasis: insights from a UK patient-reported cohort (mySkin)',
      authors: 'Kroah-Hartman M, Lee JYW, Dooley N, et al.',
      year: '2025',
      journal: 'British Journal of Dermatology',
      doi: '10.1093/bjd/ljaf073',
      pmid: '39999378',
      url: 'https://doi.org/10.1093/bjd/ljaf073',
      keyFinding:
          '67.2% report winter worsening; temperature, humidity, and light all independently correlate with disease activity',
      citationCount: 45,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P1): doi field was malformed ("10.1111/bjd.xxxxx"). Corrected to the '
        'real DOI/PMID/title/authors. ⚠️ keyFinding UNCHANGED but flagged: could not confirm '
        'the 67.2% figure or the "independently correlate" claim from the publicly visible portion of '
        'this ~4-page research letter. Please check against the full text if you have access.',
  ),

  // P10 — Trigger: Cold Weather & Low Humidity, ordinal 1 (Ferrándiz — RECOMMEND REJECT)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Cold Weather & Low Humidity',
    ordinal: 1,
    previousContent: _content(
      title: 'Warm, Humid, and High Sun Exposure Climates are Associated with Lower Prevalence of Psoriasis',
      authors: 'Ferrándiz C, et al.',
      year: '2013',
      journal: 'PLoS ONE',
      doi: '10.1371/journal.pone.0062127',
      url: 'https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0062127',
      keyFinding: 'n=5,595 subjects: warmer regions have 2.8x lower psoriasis prevalence compared to cold regions',
      citationCount: 89,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'Warm, Humid, and High Sun Exposure Climates are Associated with Lower Prevalence of Psoriasis',
      authors: 'Ferrándiz C, et al.',
      year: '2013',
      journal: 'PLoS ONE',
      doi: '10.1371/journal.pone.0062127',
      url: 'https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0062127',
      keyFinding: 'n=5,595 subjects: warmer regions have 2.8x lower psoriasis prevalence compared to cold regions',
      citationCount: 89,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P10): \u{1F6A9} RECOMMEND REJECT — no real "Ferrándiz PLoS ONE 2013" '
        'paper on psoriasis-vs-climate with n=5,595 could be found; the DOI resolves to an unrelated '
        'saltwater-crocodile ecology paper. Title and "n=5,595" appear to be the eczema PEER-cohort '
        'paper (Sargen et al. 2014, PMID 23774527) reworded to be about psoriasis. proposedContent '
        'above is UNCHANGED from live (no real replacement submitted) — reject to remove this citation, '
        'or request changes if you want to swap in a real, weaker climate/latitude citation instead: '
        'Jacobson CC, Kumar S, Kimball AB, "Latitude and psoriasis prevalence," J Am Acad Dermatol '
        '2011;65(4):870-873, DOI 10.1016/j.jaad.2010.05.047.',
  ),

  // P11 — Trigger: Alcohol Consumption
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Alcohol Consumption',
    ordinal: 0,
    previousContent: _content(
      title: 'Alcohol Use Disorder and Psoriasis',
      authors: 'Environmental Risk Factors Review',
      year: '2016',
      journal: 'Oxidative Medicine and Cellular Longevity',
      doi: '10.1155/2016/4321017',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC4962284/',
      keyFinding:
          'Strong dose-response relationship; heavy drinkers (>3 drinks/day) have 2-3x higher risk and worse treatment outcomes',
      citationCount: 156,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'Dose-response analysis between alcohol consumption and psoriasis: A systematic review and meta-analysis',
      authors: 'Choi J, Han I, Min J, et al.',
      year: '2024',
      journal: 'Journal der Deutschen Dermatologischen Gesellschaft',
      doi: '10.1111/ddg.15380',
      pmid: '38679782',
      url: 'https://doi.org/10.1111/ddg.15380',
      keyFinding:
          'Strong dose-response relationship; heavy drinkers (>3 drinks/day) have 2-3x higher risk and worse treatment outcomes',
      citationCount: 156,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P11, not in original flag list): existing DOI is fabricated '
        '(Crossref 404); url field actually points to the unrelated Barrea obesity paper (see '
        '"Trigger: Obesity"). Swapped to Choi et al. 2024 meta-analysis. ⚠️ keyFinding '
        'UNCHANGED but flagged: the "2-3x higher risk" figure is larger than this meta-analysis '
        'supports (it found +4% risk per additional g/day, rising sharply above ~45 g/day), and '
        '"worse treatment outcomes" is not covered by it. Needs your decision.',
  ),

  // P2 — Trigger: Smoking
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Smoking',
    ordinal: 0,
    previousContent: _content(
      title: 'Smoking and Psoriasis Risk and Severity',
      authors: 'Multiple meta-analyses',
      year: '2016',
      journal: 'Environmental Risk Factors in Psoriasis',
      doi: 'XXX',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC4962284/',
      keyFinding:
          'Current smokers: 1.8x higher risk; former smokers: normalized risk after 10 years; smokers have 15-20 point higher PASI scores',
      citationCount: 203,
      evidenceType: 'meta_analysis',
    ),
    proposedContent: _content(
      title:
          'Psoriasis and Smoking: A Systematic Literature Review and Meta-Analysis With Qualitative Analysis of Effect of Smoking on Psoriasis Severity',
      authors: 'Richer V, Roubille C, Fleming P, et al.',
      year: '2016',
      journal: 'Journal of Cutaneous Medicine and Surgery',
      doi: '10.1177/1203475415616073',
      pmid: '26553732',
      url: 'https://doi.org/10.1177/1203475415616073',
      keyFinding:
          'Current smokers: 1.8x higher risk; former smokers: normalized risk after 10 years; smokers have 15-20 point higher PASI scores',
      citationCount: 203,
      evidenceType: 'meta_analysis',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P2): doi was a placeholder ("XXX"). Corrected to Richer et al. 2016 '
        '(pooled RR 1.88, matches the "1.8x" figure). ⚠️ keyFinding UNCHANGED but flagged: '
        '"former smokers normalize after 10 years" is not in this paper, and "15-20 point higher PASI" '
        'is not supported — the review only reports a qualitative severity association, no PASI point '
        'estimate. Needs your decision.',
  ),

  // P3 — Trigger: Obesity (BMI >30)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Obesity (BMI >30)',
    ordinal: 0,
    previousContent: _content(
      title: 'Nutrition and Obesity in Psoriasis',
      authors: 'Environmental Risk Factors Review',
      year: '2016',
      journal: 'Journal of Dermatological Treatment',
      doi: 'XXX',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC4962284/',
      keyFinding: 'Each 5kg weight gain increases risk by 9%; weight loss improves PASI by 20% for every 5kg',
      citationCount: 112,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'Environmental Risk Factors in Psoriasis: The Point of View of the Nutritionist',
      authors: 'Barrea L, Nappi F, Di Somma C, et al.',
      year: '2016',
      journal: 'International Journal of Environmental Research and Public Health',
      doi: '10.3390/ijerph13070743',
      pmid: '27455297',
      url: 'https://doi.org/10.3390/ijerph13070743',
      keyFinding: 'Each 5kg weight gain increases risk by 9%; weight loss improves PASI by 20% for every 5kg',
      citationCount: 112,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P3): doi was a placeholder; url already pointed to the real paper '
        '(Barrea et al. 2016) so this is a metadata-only fix. ⚠️ keyFinding UNCHANGED but '
        'soft-flagged: "9% per 5kg" is from a different study (Kumar et al., Nurses\' Health Study II), '
        'and "PASI improves 20% per 5kg" is not from Barrea. Soft flag — your call on whether to keep.',
  ),

  // P4 — Trigger: Medications (judgment call)
  _Seed(
    condition: 'psoriasis',
    location: 'Trigger: Medications (Beta-blockers, NSAIDs, Lithium)',
    ordinal: 0,
    previousContent: _content(
      title: 'Drug-Induced Psoriasis',
      authors: 'Clinical Reviews',
      year: '2020',
      journal: 'Dermatology Practical & Conceptual',
      doi: 'XXX',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      keyFinding:
          'Beta-blockers, NSAIDs, lithium, and ACE inhibitors are major iatrogenic culprits; propranolol most notorious',
      citationCount: 89,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'Drug-provoked psoriasis: is it drug induced or drug aggravated? Understanding pathophysiology and clinical relevance',
      authors: 'Kim GK, Del Rosso JQ',
      year: '2010',
      journal: 'Journal of Clinical and Aesthetic Dermatology',
      doi: '',
      pmid: '20725536',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC2921739/',
      keyFinding:
          'Beta-blockers, NSAIDs, lithium, and ACE inhibitors are major iatrogenic culprits; propranolol most notorious',
      citationCount: 89,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P4) — JUDGMENT CALL, two real options: (A, proposed above) Kim & Del '
        'Rosso 2010, PMID 20725536, no registered DOI (old JCAD article) — explicitly names '
        'beta-blockers/lithium/NSAIDs and discusses propranolol + ACE inhibitors, closely matching the '
        'current keyFinding. (B, not proposed) Balak & Hajdarbegovic, Psoriasis (Auckl) 2017, DOI '
        '10.2147/PTT.S126727, PMID 29387611 — has a registered DOI but does NOT cover NSAIDs or ACE '
        'inhibitors, so it would partially contradict the keyFinding as written. Your call: approve (A) '
        'as proposed, or request changes to swap to (B) and trim the keyFinding to match.',
  ),

  // P5 — Key research paper, ordinal 1 (Boehncke/Schön)
  _Seed(
    condition: 'psoriasis',
    location: 'Key research paper',
    ordinal: 1,
    previousContent: _content(
      title: 'Pathophysiology of psoriasis',
      authors: 'Boehncke WH, Schön MP',
      year: '2023',
      journal: 'Indian Journal of Dermatology',
      doi: 'XXX',
      url: 'https://ijdvl.com/content/',
      keyFinding: 'Detailed IL-23/IL-17 axis mechanics and T cell biology',
      citationCount: 289,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'Psoriasis',
      authors: 'Boehncke WH, Schön MP',
      year: '2015',
      journal: 'The Lancet',
      doi: '10.1016/S0140-6736(14)61909-7',
      pmid: '26025581',
      url: 'https://doi.org/10.1016/S0140-6736(14)61909-7',
      keyFinding: 'Detailed IL-23/IL-17 axis mechanics and T cell biology',
      citationCount: 289,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P5): year/journal/doi were all wrong (real paper is the 2015 Lancet '
        'seminar, not a 2023 Indian Journal of Dermatology piece). keyFinding is a fair description of '
        'the seminar — no change proposed.',
  ),

  // P6c — Key research paper, ordinal 0 (Liu et al., 3rd occurrence)
  _Seed(
    condition: 'psoriasis',
    location: 'Key research paper',
    ordinal: 0,
    previousContent: _content(
      title: 'Triggers for the onset and recurrence of psoriasis',
      authors: 'Liu S, Li D, Yu Y',
      year: '2024',
      journal: 'NIH/PMC',
      doi: 'PMC10860266',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC10860266/',
      keyFinding: 'Comprehensive trigger analysis across 15,467 subjects; stress 94.8% at recurrence',
      citationCount: 28,
      evidenceType: 'meta_analysis',
    ),
    proposedContent: _content(
      title: 'Triggers for the onset and recurrence of psoriasis: a review and update',
      authors: 'Liu S, He M, Jiang J, et al.',
      year: '2024',
      journal: 'Cell Communication and Signaling',
      doi: '10.1186/s12964-023-01381-0',
      pmid: '38347543',
      url: 'https://doi.org/10.1186/s12964-023-01381-0',
      keyFinding: 'Comprehensive trigger analysis across 15,467 subjects; stress 94.8% at recurrence',
      citationCount: 28,
      evidenceType: 'meta_analysis',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P6): third occurrence of the same Liu et al. paper (see "Trigger: '
        'Psychological Stress" ordinal 0 and "Trigger: Skin Trauma" for the other two). \u{1F6A9} '
        'keyFinding UNCHANGED but FABRICATED — same "15,467 subjects / 94.8%" issue as the other two '
        'occurrences. Please review all three together; they should get a consistent decision.',
  ),

  // P12 — Treatment: Phototherapy
  _Seed(
    condition: 'psoriasis',
    location: 'Treatment: Phototherapy (NB-UVB 311nm)',
    ordinal: 0,
    previousContent: _content(
      title: 'A clinical review of phototherapy for psoriasis',
      authors: 'Zhang P, et al.',
      year: '2017',
      journal: 'PMC',
      doi: 'PMC5756569',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC5756569/',
      keyFinding: '75% PASI-50 response; 2-3x/week for 12 weeks optimal; PASI-75 in ~50% at 24 weeks',
      citationCount: 134,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'A clinical review of phototherapy for psoriasis',
      authors: 'Zhang P, Wu MX',
      year: '2018',
      journal: 'Lasers in Medical Science',
      doi: '10.1007/s10103-017-2360-1',
      pmid: '29067616',
      url: 'https://doi.org/10.1007/s10103-017-2360-1',
      keyFinding: '75% PASI-50 response; 2-3x/week for 12 weeks optimal; PASI-75 in ~50% at 24 weeks',
      citationCount: 134,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md P12): "PMC5756569" was used as the doi field (not a real DOI); year '
        'was off by one. Corrected identifier/year/journal. keyFinding not independently verified '
        'line-by-line but consistent with a phototherapy review — no change proposed.',
  ),

  // ────────────────────────────── ECZEMA ──────────────────────────────

  // E10 — Trigger: Cold Weather & Temperature Drops, ordinal 0 (Flohr/Chan)
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Cold Weather & Temperature Drops',
    ordinal: 0,
    previousContent: _content(
      title: 'Do temperature changes correlate with eczema flares? An English cohort study',
      authors: 'Flohr C, et al.',
      year: '2023',
      journal: 'Clinical & Experimental Dermatology',
      doi: '10.1111/ced.15397',
      url: 'https://academic.oup.com/ced/article/48/9/1012/7148145',
      keyFinding:
          '74% of AD patients report temperature sensitivity; temperature drops ≥5°C are associated with significant flares',
      citationCount: 34,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'Do temperature changes cause eczema flares? An English cohort study',
      authors: 'Chan J, MacNeill SJ, Stuart B, et al.',
      year: '2023',
      journal: 'Clinical and Experimental Dermatology',
      doi: '10.1093/ced/llad147',
      pmid: '37130096',
      url: 'https://doi.org/10.1093/ced/llad147',
      keyFinding:
          '74% of AD patients report temperature sensitivity; temperature drops ≥5°C are associated with significant flares',
      citationCount: 34,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E10, not in original flag list): existing DOI resolves to an '
        'unrelated colchicine-for-urticaria case report; first author is Chan J, not Flohr C (Flohr is '
        'a co-author). Note: proposedContent.title restores the paper\'s real word "cause" — the live '
        'app\'s title had been edited to "correlate with" under a language policy; that softening '
        'belongs in prose, not in a quoted paper title. \u{1F6A9} keyFinding UNCHANGED but '
        'CONTRADICTS the cited paper: the study found cold weeks were NOT significantly associated '
        'with flares (OR 1.15, 95% CI 0.96-1.39, P=0.14), and hot weather significantly REDUCED flare '
        'odds (OR 0.85, P=0.05). This undermines the entire "Cold Weather & Temperature Drops" trigger '
        '(baselineIncidence 74.3). Needs your decision.',
  ),

  // E11a — Trigger: Cold Weather & Temperature Drops, ordinal 1 (Silverberg/Sargen PEER)
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Cold Weather & Temperature Drops',
    ordinal: 1,
    previousContent: _content(
      title: 'Climate and Eczema Control in Children (PEER cohort)',
      authors: 'Silverberg JI, et al.',
      year: '2013',
      journal: 'JAMA Dermatology',
      doi: '10.1001/jamadermatol.2013.9122',
      url: 'https://jamanetwork.com/journals/jamadermatology/article-abstract/1769179',
      keyFinding: 'n=5,595 children: cold climates associated with worse eczema control; winter exacerbation in 68%',
      citationCount: 156,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title:
          'Warm, humid, and high sun exposure climates are associated with poorly controlled eczema: PEER (Pediatric Eczema Elective Registry) cohort, 2004-2012',
      authors: 'Sargen MR, Hoffstad O, Margolis DJ',
      year: '2014',
      journal: 'Journal of Investigative Dermatology',
      doi: '10.1038/jid.2013.274',
      pmid: '23774527',
      url: 'https://doi.org/10.1038/jid.2013.274',
      keyFinding: 'n=5,595 children: cold climates associated with worse eczema control; winter exacerbation in 68%',
      citationCount: 156,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E11): existing DOI does not resolve (Crossref 404); the real PEER-'
        'cohort paper is by Margolis\' group, not Silverberg. \u{1F6A9} keyFinding UNCHANGED but '
        'CONTRADICTS the real paper: its headline finding is that WARM/HUMID/high-UV climates '
        'associate with poorly controlled eczema — i.e. partly the opposite direction of "cold '
        'climates associated with worse control." The "68%" figure is unverified. Alternative if you '
        'want a cold-climate-worsening citation instead: Silverberg JI, Hanifin J, Simpson EL, '
        '"Climatic factors are associated with childhood eczema prevalence in the United States," J '
        'Invest Dermatol 2013;133(7):1752-1759, DOI 10.1038/jid.2013.19 (about prevalence, not '
        '"control"). Needs your decision. Same underlying issue as "Key research paper" ordinal 1.',
  ),

  // E12/13a — Trigger: High Humidity + Sweating
  _Seed(
    condition: 'eczema',
    location: 'Trigger: High Humidity + Sweating',
    ordinal: 0,
    previousContent: _content(
      title: 'Atopic Dermatitis: Guidelines 2023 (AAD/ACAAI Consensus)',
      authors: 'Eichenfield LF, et al.',
      year: '2023',
      journal: 'American Academy of Dermatology',
      doi: '10.1016/j.jaad.2023.03.002',
      url: 'https://pubmed.ncbi.nlm.nih.gov/38108679/',
      keyFinding: 'Heat and humidity exacerbate symptoms in 58% of moderate-severe AD; sweat irritation identified as major trigger',
      citationCount: 89,
      evidenceType: 'guideline',
    ),
    proposedContent: _content(
      title:
          'Atopic dermatitis (eczema) guidelines: 2023 AAAAI/ACAAI Joint Task Force on Practice Parameters GRADE- and Institute of Medicine-based recommendations',
      authors: 'Chu DK, Schneider L, Asiniwasis RN, et al.',
      year: '2024',
      journal: 'Annals of Allergy, Asthma & Immunology',
      doi: '10.1016/j.anai.2023.11.009',
      pmid: '38108679',
      url: 'https://pubmed.ncbi.nlm.nih.gov/38108679/',
      keyFinding: 'Heat and humidity exacerbate symptoms in 58% of moderate-severe AD; sweat irritation identified as major trigger',
      citationCount: 89,
      evidenceType: 'guideline',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E12/E13) — JUDGMENT CALL: existing DOI resolves to a JAAD trivia '
        'column, not a real guideline; "Eichenfield LF" led the 2014 AAD guidelines, not the 2023 '
        'ones. The live url already points to PMID 38108679, which is the Chu et al. AAAAI/ACAAI '
        'guideline (proposed above) — kept for consistency with the existing url. Alternative if you '
        'prefer an AAD-specific guideline for this humidity/sweat claim: Sidbury R, Alikhan A, '
        'Bercovitch L, et al., J Am Acad Dermatol 2023;89(1):e1-e20, DOI 10.1016/j.jaad.2022.12.029, '
        'PMID 36641009. Same paper/decision needed on "Trigger: Harsh Soaps..." and "Key research '
        'paper" (3 total uses of this guideline citation).',
  ),

  // E1 — Trigger: Food Allergen Exposure, ordinal 0 (RECOMMEND REJECT)
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Food Allergen Exposure (Milk, Nuts, Eggs)',
    ordinal: 0,
    previousContent: _content(
      title: "One-third of Parents Report Improvements in Kids' AD with Elimination Diets",
      authors: 'Allergy & Immunology Review',
      year: '2024',
      journal: 'The Dermatology Digest',
      doi: 'XXX',
      url: 'https://thedermdigest.com/one-third-of-parents-report-improvements-in-kids-ad-symptoms-with-elimination-diets/',
      keyFinding: 'Food allergen avoidance benefits 33% of children with AD; milk (32%), nuts (16%), eggs (11%) most common triggers',
      citationCount: 45,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: "One-third of Parents Report Improvements in Kids' AD with Elimination Diets",
      authors: 'Allergy & Immunology Review',
      year: '2024',
      journal: 'The Dermatology Digest',
      doi: 'XXX',
      url: 'https://thedermdigest.com/one-third-of-parents-report-improvements-in-kids-ad-symptoms-with-elimination-diets/',
      keyFinding: 'Food allergen avoidance benefits 33% of children with AD; milk (32%), nuts (16%), eggs (11%) most common triggers',
      citationCount: 45,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E1): \u{1F6A9} RECOMMEND REJECT — this is a lay trade-press item '
        'summarizing an UNPUBLISHED conference abstract (Makkoukdji et al., ACAAI 2024, cross-sectional '
        'survey of 298 parents), not a peer-reviewed source. The abstract\'s actual takeaway: '
        'elimination diets produced only mild improvement in ~⅓ and are NOT recommended — the '
        '"benefits 33%"/food-specific-percentage framing here is selective. proposedContent above is '
        'UNCHANGED from live. Reject to remove, or request changes to swap in a real peer-reviewed '
        'source instead: Bath-Hextall F, Delamere FM, Williams HC, "Dietary exclusions for established '
        'atopic eczema," Cochrane Database Syst Rev 2008;(1):CD005203, DOI '
        '10.1002/14651858.CD005203.pub2 (the trigger still has a second citation, E2, either way).',
  ),

  // E2 — Trigger: Food Allergen Exposure, ordinal 1 (Boyce -> Katta)
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Food Allergen Exposure (Milk, Nuts, Eggs)',
    ordinal: 1,
    previousContent: _content(
      title: 'Diet and Dermatitis: Food Triggers in Atopic Dermatitis',
      authors: 'Boyce JA, et al.',
      year: '2007',
      journal: 'Advances in Dermatology',
      doi: 'XXX',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC3970830/',
      keyFinding: 'Only ~10-15% of AD is IgE-mediated food allergy; non-IgE triggers more common (food intolerance)',
      citationCount: 123,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'Diet and dermatitis: food triggers',
      authors: 'Katta R, Schlichte M',
      year: '2014',
      journal: 'Journal of Clinical and Aesthetic Dermatology',
      doi: '',
      pmid: '24688624',
      url: 'https://pmc.ncbi.nlm.nih.gov/articles/PMC3970830/',
      keyFinding: 'Only ~10-15% of AD is IgE-mediated food allergy; non-IgE triggers more common (food intolerance)',
      citationCount: 123,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E2): the live url already pointed to the real paper (Katta & '
        'Schlichte 2014, PMC3970830) but title/authors/year/journal/doi were wrong and it has no '
        'registered DOI (cited via PMID). ⚠️ keyFinding UNCHANGED but soft-flagged: '
        'direction is consistent with the review, but Katta actually cites food-allergy-prevalence '
        'estimates of 20-80% in moderate-severe AD, not a 10-15% figure.',
  ),

  // E3 — Trigger: Stress & Sleep Deprivation
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Stress & Sleep Deprivation',
    ordinal: 0,
    previousContent: _content(
      title: 'Psychological Stress in Atopic Dermatitis',
      authors: 'Multiple - NIH/PMC Review',
      year: '2024',
      journal: 'International Journal of Molecular Sciences',
      doi: 'XXX',
      url: 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8359866/',
      keyFinding: '72% of AD patients report stress exacerbates symptoms; 2-3 day lag observed between stress and flare onset',
      citationCount: 167,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'Association between Stress and the HPA Axis in the Atopic Dermatitis',
      authors: 'Lin TK, Zhong L, Santiago JL',
      year: '2017',
      journal: 'International Journal of Molecular Sciences',
      doi: '10.3390/ijms18102131',
      pmid: '29023418',
      url: 'https://doi.org/10.3390/ijms18102131',
      keyFinding: '72% of AD patients report stress exacerbates symptoms; 2-3 day lag observed between stress and flare onset',
      citationCount: 167,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E3): live url pointed to an unrelated COVID-19 paediatric-radiology '
        'paper; no 2024 IJMS review on this topic exists. Swapped to Lin et al. 2017, which matches '
        'the entry\'s HPA-axis mechanism text. ⚠️ keyFinding UNCHANGED but flagged: this is '
        'a mechanistic review — it does not report a 72% figure or a 2-3 day lag. Needs your decision.',
  ),

  // E12/13b — Trigger: Harsh Soaps, Detergents, Fragrances
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Harsh Soaps, Detergents, Fragrances',
    ordinal: 0,
    previousContent: _content(
      title: 'Atopic Dermatitis Guidelines 2023',
      authors: 'AAD/ACAAI Consensus',
      year: '2023',
      journal: 'JAMA Dermatology',
      doi: '10.1001/jamadermatol.2023.5606',
      url: 'https://pubmed.ncbi.nlm.nih.gov/38108679/',
      keyFinding: '81% of AD patients report irritant triggers; fragrance-free + ceramide products recommended as 1st-line prevention',
      citationCount: 102,
      evidenceType: 'guideline',
    ),
    proposedContent: _content(
      title:
          'Atopic dermatitis (eczema) guidelines: 2023 AAAAI/ACAAI Joint Task Force on Practice Parameters GRADE- and Institute of Medicine-based recommendations',
      authors: 'Chu DK, Schneider L, Asiniwasis RN, et al.',
      year: '2024',
      journal: 'Annals of Allergy, Asthma & Immunology',
      doi: '10.1016/j.anai.2023.11.009',
      pmid: '38108679',
      url: 'https://pubmed.ncbi.nlm.nih.gov/38108679/',
      keyFinding: '81% of AD patients report irritant triggers; fragrance-free + ceramide products recommended as 1st-line prevention',
      citationCount: 102,
      evidenceType: 'guideline',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E12/E13) — same judgment call as "Trigger: High Humidity + '
        'Sweating": existing DOI does not resolve (Crossref 404), journal was wrong ("JAMA '
        'Dermatology"). Proposed the Chu et al. AAAAI/ACAAI guideline (matches the existing url). '
        'Alternative: Sidbury et al. AAD topical-therapy guideline (see the High Humidity entry for '
        'full citation). Please make a consistent choice across all 3 uses of this guideline.',
  ),

  // E4 — Trigger: Environmental Allergens (RECOMMEND REJECT)
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Environmental Allergens (Dust Mites, Pollen, Pet Dander)',
    ordinal: 0,
    previousContent: _content(
      title: 'HEPA Filtration & Allergen-Proof Bedding in AD',
      authors: 'Randomized Trial',
      year: '2024',
      journal: 'Journal of Allergy and Clinical Immunology',
      doi: 'XXX',
      url: 'https://www.jaci-inpractice.org/',
      keyFinding: 'HEPA + allergen covers reduced SCORAD by 42% over 12 weeks; 70% of flares correlate with high pollen days',
      citationCount: 67,
      evidenceType: 'randomized_trial',
    ),
    proposedContent: _content(
      title: 'HEPA Filtration & Allergen-Proof Bedding in AD',
      authors: 'Randomized Trial',
      year: '2024',
      journal: 'Journal of Allergy and Clinical Immunology',
      doi: 'XXX',
      url: 'https://www.jaci-inpractice.org/',
      keyFinding: 'HEPA + allergen covers reduced SCORAD by 42% over 12 weeks; 70% of flares correlate with high pollen days',
      citationCount: 67,
      evidenceType: 'randomized_trial',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E4): \u{1F6A9} RECOMMEND REJECT — no such trial could be found, and '
        'the best real evidence points the OTHER way: mattress/bedding-encasing RCTs in AD have been '
        'negative (e.g. Gutgesell et al. 2001), and the Cochrane review (Nankervis et al. 2015) '
        'concluded there is insufficient/very-low-quality evidence. The "42% SCORAD reduction / 70% '
        'pollen correlation" keyFinding appears fabricated and contradicts that evidence base. This '
        'also affects the trigger\'s expectedImprovement (25.0) and baselineIncidence (48.7) fields. '
        'proposedContent above is UNCHANGED from live. Reject to remove, or request changes to cite '
        'the Cochrane review honestly with a softened claim instead: Nankervis H, et al., "House dust '
        'mite reduction and avoidance measures for treating eczema," Cochrane Database Syst Rev '
        '2015;(1):CD008426, DOI 10.1002/14651858.CD008426.pub2.',
  ),

  // E5 — Trigger: Dry Air & Low Humidity
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Dry Air & Low Humidity (less than 30%)',
    ordinal: 0,
    previousContent: _content(
      title: 'Humidity and AD Control',
      authors: 'Climate Studies',
      year: '2020',
      journal: 'Dermatology Reviews',
      doi: 'XXX',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      keyFinding: 'Humidity less than 30% associated with 3.2x higher flare rate',
      citationCount: 56,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title: 'The effect of environmental humidity and temperature on skin barrier function and dermatitis',
      authors: 'Engebretsen KA, Johansen JD, Kezic S, et al.',
      year: '2016',
      journal: 'Journal of the European Academy of Dermatology and Venereology',
      doi: '10.1111/jdv.13301',
      pmid: '26449379',
      url: 'https://doi.org/10.1111/jdv.13301',
      keyFinding: 'Humidity less than 30% associated with 3.2x higher flare rate',
      citationCount: 56,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E5): no "Dermatology Reviews" journal/article matching this exists. '
        'Swapped to Engebretsen et al. 2016. ⚠️ keyFinding UNCHANGED but flagged: the real '
        'review is qualitative/mechanistic — the "3.2x higher flare rate" figure is not from it. Needs '
        'your decision.',
  ),

  // E6 — Trigger: Bacterial Infection (Staph aureus)
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Bacterial Infection (Staph aureus Colonization)',
    ordinal: 0,
    previousContent: _content(
      title: 'Staph aureus in Atopic Dermatitis',
      authors: 'Immunology Reviews',
      year: '2019',
      journal: 'Clinical & Experimental Dermatology',
      doi: 'XXX',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      keyFinding: '90% of AD skin colonized with S. aureus; superantigen toxins drive inflammation; antimicrobial bathing reduces colonization',
      citationCount: 134,
      evidenceType: 'review',
    ),
    proposedContent: _content(
      title: 'Exploring the Role of Staphylococcus aureus Toxins in Atopic Dermatitis',
      authors: 'Yoshikawa FSY, Feitosa de Lima J, Notomi Sato M, et al.',
      year: '2019',
      journal: 'Toxins',
      doi: '10.3390/toxins11060321',
      pmid: '31195639',
      url: 'https://doi.org/10.3390/toxins11060321',
      keyFinding: '90% of AD skin colonized with S. aureus; superantigen toxins drive inflammation; antimicrobial bathing reduces colonization',
      citationCount: 134,
      evidenceType: 'review',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E6): no matching "Clinical & Experimental Dermatology" 2019 review '
        'found. Swapped to Yoshikawa et al. 2019 (superantigen-focused, matches the mechanism text). '
        'Alternative if you prefer a more general/authoritative source: Geoghegan JA, Irvine AD, '
        'Foster TJ, "Staphylococcus aureus and Atopic Dermatitis: A Complex and Evolving Relationship," '
        'Trends Microbiol 2018;26(6):484-497, DOI 10.1016/j.tim.2017.11.008. keyFinding ("90% '
        'colonized") is not contradicted by either source (Toxins review says 30-100%) — no change '
        'proposed.',
  ),

  // E7 — Trigger: Itch-Scratch Cycle
  _Seed(
    condition: 'eczema',
    location: 'Trigger: Itch-Scratch Cycle / Lichenification',
    ordinal: 0,
    previousContent: _content(
      title: 'Cognitive Behavioral Therapy for Habit Reversal in AD',
      authors: 'JAMA Dermatology Study',
      year: '2024',
      journal: 'JAMA Dermatology',
      doi: 'XXX',
      url: 'https://pubmed.ncbi.nlm.nih.gov/',
      keyFinding: 'CBT-based habit reversal reduced scratching episodes by 65%; improved DLQI 8.2 points over 8 weeks',
      citationCount: 78,
      evidenceType: 'randomized_trial',
    ),
    proposedContent: _content(
      title:
          'The positive effects of habit reversal treatment of scratching in children with atopic dermatitis: a randomized controlled study',
      authors: 'Norén P, Hagströmer L, Alimohammadi M, Melin L',
      year: '2018',
      journal: 'British Journal of Dermatology',
      doi: '10.1111/bjd.16009',
      pmid: '28940213',
      url: 'https://doi.org/10.1111/bjd.16009',
      keyFinding: 'CBT-based habit reversal reduced scratching episodes by 65%; improved DLQI 8.2 points over 8 weeks',
      citationCount: 78,
      evidenceType: 'randomized_trial',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E7): no 2024 JAMA Dermatology habit-reversal RCT could be found. '
        'Swapped to Norén et al. 2018 (real RCT, n=39, objective SCORAD change -31.7 vs -19.7 at 8 '
        'weeks, P=0.0038). \u{1F6A9} keyFinding UNCHANGED but does not match the real RCT: it reports '
        'SCORAD, not "65% reduction in scratching episodes" or "DLQI 8.2" (also a paediatric study, '
        'not the adult-implied framing here). Needs your decision.',
  ),

  // E8 — Treatment: Emollients & Moisturizers
  _Seed(
    condition: 'eczema',
    location: 'Treatment: Emollients & Moisturizers (1st-line Therapy)',
    ordinal: 0,
    previousContent: _content(
      title: 'Emollient Use in Atopic Dermatitis',
      authors: 'Cochrane Systematic Review',
      year: '2023',
      journal: 'Cochrane Database of Systematic Reviews',
      doi: 'XXX',
      url: 'https://www.cochranelibrary.com/',
      keyFinding: '23 RCTs: liberal emollient use (greater than 250g/week) reduces AD severity by 35-45% and topical steroid requirements by 30%',
      citationCount: 198,
      evidenceType: 'meta_analysis',
    ),
    proposedContent: _content(
      title: 'Emollients and moisturisers for eczema',
      authors: 'van Zuuren EJ, Fedorowicz Z, Christensen R, et al.',
      year: '2017',
      journal: 'Cochrane Database of Systematic Reviews',
      doi: '10.1002/14651858.CD012119.pub2',
      pmid: '28166390',
      url: 'https://doi.org/10.1002/14651858.CD012119.pub2',
      keyFinding: '23 RCTs: liberal emollient use (greater than 250g/week) reduces AD severity by 35-45% and topical steroid requirements by 30%',
      citationCount: 198,
      evidenceType: 'meta_analysis',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E8): there is no 2023 update to this Cochrane review — the real, '
        'current version is van Zuuren et al. 2017 (.pub2). \u{1F6A9} keyFinding UNCHANGED but '
        'FABRICATED: the real review covers 77 studies / 6,603 participants (not "23 RCTs") and '
        'reaches far more cautious conclusions ("emollients + active treatment better than active '
        'treatment alone; insufficient evidence to prefer one emollient") — no 35-45%/30% figures. '
        'Needs your decision.',
  ),

  // E9 — Treatment: JAK Inhibitors (judgment call)
  _Seed(
    condition: 'eczema',
    location: 'Treatment: JAK Inhibitors (Topical: ruxolitinib cream, or Systemic)',
    ordinal: 0,
    previousContent: _content(
      title: 'JAK Inhibitors in Atopic Dermatitis',
      authors: 'FDA Approval Data',
      year: '2022-2024',
      journal: 'JAMA Dermatology / FDA Documents',
      doi: 'XXX',
      url: 'https://www.fda.gov/',
      keyFinding: 'Ruxolitinib cream: 75% EASI-75 (75% improvement); systemic JAK inhibitors: 85%+ response rates',
      citationCount: 256,
      evidenceType: 'randomized_trial',
    ),
    proposedContent: _content(
      title:
          'Comparative efficacy and safety of abrocitinib, baricitinib, and upadacitinib for moderate-to-severe atopic dermatitis: A network meta-analysis',
      authors: 'Wan H, Jia H, Xia T, Zhang D',
      year: '2022',
      journal: 'Dermatologic Therapy',
      doi: '10.1111/dth.15636',
      pmid: '35703351',
      url: 'https://doi.org/10.1111/dth.15636',
      keyFinding: 'Ruxolitinib cream: 75% EASI-75 (75% improvement); systemic JAK inhibitors: 85%+ response rates',
      citationCount: 256,
      evidenceType: 'randomized_trial',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E9) — JUDGMENT CALL: "FDA Approval Data" is not a citable single '
        'source. Proposed Wan et al. 2022 network meta-analysis of SYSTEMIC JAK inhibitors '
        '(abrocitinib/baricitinib/upadacitinib) only — it does NOT cover topical ruxolitinib cream, '
        'which the keyFinding also names. ⚠️ keyFinding UNCHANGED but only partly supported '
        'by the proposed citation. Options: (a) trim the keyFinding to systemic JAKs only and keep '
        'this single citation, or (b) add a second citation for the ruxolitinib-cream claim: Papp K, '
        'et al. (TRuE-AD1/AD2), J Am Acad Dermatol 2021;85(4):863-872, DOI '
        '10.1016/j.jaad.2021.04.085. Needs your decision.',
  ),

  // E11b / E12/13c — Key research paper, ordinal 0 (Eichenfield/Chu guideline, 3rd use)
  _Seed(
    condition: 'eczema',
    location: 'Key research paper',
    ordinal: 0,
    previousContent: _content(
      title: 'Atopic Dermatitis (Eczema) Guidelines 2023',
      authors: 'Eichenfield LF, et al. (AAD/ACAAI)',
      year: '2023',
      journal: 'Journal of the American Academy of Dermatology',
      doi: '10.1016/j.jaad.2023.03.002',
      url: 'https://pubmed.ncbi.nlm.nih.gov/38108679/',
      keyFinding: 'Comprehensive clinical practice guidelines; barrier repair + anti-inflammatory as therapeutic cornerstones',
      citationCount: 89,
      evidenceType: 'guideline',
    ),
    proposedContent: _content(
      title:
          'Atopic dermatitis (eczema) guidelines: 2023 AAAAI/ACAAI Joint Task Force on Practice Parameters GRADE- and Institute of Medicine-based recommendations',
      authors: 'Chu DK, Schneider L, Asiniwasis RN, et al.',
      year: '2024',
      journal: 'Annals of Allergy, Asthma & Immunology',
      doi: '10.1016/j.anai.2023.11.009',
      pmid: '38108679',
      url: 'https://pubmed.ncbi.nlm.nih.gov/38108679/',
      keyFinding: 'Comprehensive clinical practice guidelines; barrier repair + anti-inflammatory as therapeutic cornerstones',
      citationCount: 89,
      evidenceType: 'guideline',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E12/E13) — third use of the guideline citation (see "Trigger: High '
        'Humidity + Sweating" and "Trigger: Harsh Soaps..." for the other two). Existing doi resolves '
        'to a JAAD trivia column, not a guideline; "Eichenfield LF" led the 2014 guidelines, not 2023. '
        'Proposed the Chu et al. AAAAI/ACAAI guideline for consistency with the existing url (PMID '
        '38108679). Alternative: Sidbury et al. AAD topical-therapy guideline (full citation on the '
        'High Humidity entry). Please make one consistent choice across all 3 uses.',
  ),

  // E11c — Key research paper, ordinal 1 (Silverberg/Sargen PEER, 2nd use)
  _Seed(
    condition: 'eczema',
    location: 'Key research paper',
    ordinal: 1,
    previousContent: _content(
      title: 'Climate & Eczema Control in Children (PEER cohort)',
      authors: 'Silverberg JI, et al.',
      year: '2013',
      journal: 'JAMA Dermatology',
      doi: '10.1001/jamadermatol.2013.9122',
      url: 'https://jamanetwork.com/journals/jamadermatology/article-abstract/1769179',
      keyFinding: 'n=5,595 children; cold climates + low humidity worsen control; seasonal patterns',
      citationCount: 156,
      evidenceType: 'observational',
    ),
    proposedContent: _content(
      title:
          'Warm, humid, and high sun exposure climates are associated with poorly controlled eczema: PEER (Pediatric Eczema Elective Registry) cohort, 2004-2012',
      authors: 'Sargen MR, Hoffstad O, Margolis DJ',
      year: '2014',
      journal: 'Journal of Investigative Dermatology',
      doi: '10.1038/jid.2013.274',
      pmid: '23774527',
      url: 'https://doi.org/10.1038/jid.2013.274',
      keyFinding: 'n=5,595 children; cold climates + low humidity worsen control; seasonal patterns',
      citationCount: 156,
      evidenceType: 'observational',
    ),
    reviewNotes:
        'AUDIT (CITATION_AUDIT.md E11): second use of the same paper as "Trigger: Cold Weather & '
        'Temperature Drops" ordinal 1 — same identifier correction and same direction-of-finding '
        'concern (the real PEER paper says warm/humid climates worsen control, not cold climates). '
        'Please review together with that entry.',
  ),
];

Map<String, dynamic> _entryRef(_Seed s) => {
      'condition': s.condition,
      'location': s.location,
      'ordinal': s.ordinal,
      'title': s.liveTitle,
    };

// ── Firestore REST value encoding ──────────────────────────────────────

dynamic _encodeValue(dynamic v) {
  if (v == null) return {'nullValue': null};
  if (v is String) return {'stringValue': v};
  if (v is int) return {'integerValue': v.toString()};
  if (v is double) return {'doubleValue': v};
  if (v is bool) return {'booleanValue': v};
  if (v is Map) {
    return {
      'mapValue': {
        'fields': v.map((k, val) => MapEntry(k as String, _encodeValue(val))),
      },
    };
  }
  if (v is List) {
    return {
      'arrayValue': {'values': v.map(_encodeValue).toList()},
    };
  }
  throw ArgumentError('Cannot encode value of type ${v.runtimeType}: $v');
}

Map<String, dynamic> _fields(Map<String, dynamic> doc) =>
    doc.map((k, v) => MapEntry(k, _encodeValue(v)));

Future<String> _signIn(String apiKey, String email, String password) async {
  final uri = Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
  );
  final resp = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'returnSecureToken': true,
    }),
  );
  if (resp.statusCode != 200) {
    stderr.writeln('Sign-in failed (HTTP ${resp.statusCode}): ${resp.body}');
    exit(2);
  }
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  return body['idToken'] as String;
}

Future<void> main() async {
  final projectId =
      Platform.environment['FIREBASE_PROJECT_ID'] ?? _defaultProjectId;
  final apiKey = Platform.environment['FIREBASE_API_KEY'] ?? _defaultApiKey;
  final email = Platform.environment['PORTAL_ADMIN_EMAIL'];
  final password = Platform.environment['PORTAL_ADMIN_PASSWORD'];

  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    stderr.writeln(
      'ERROR: set PORTAL_ADMIN_EMAIL and PORTAL_ADMIN_PASSWORD to a Firebase '
      'Auth account in this project (any authenticated user can create a '
      'pending review — see the header comment in this file).',
    );
    exit(2);
  }

  stdout.writeln('Signing in as $email ...');
  final idToken = await _signIn(apiKey, email, password);

  stdout.writeln(
    'Submitting ${_seeds.length} pending clinicalEvidenceReviews to '
    'project $projectId ...',
  );

  final commitUri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit',
  );

  var ok = 0;
  var failed = 0;
  for (final seed in _seeds) {
    // Client-generated document ID: timestamp + a short slug so re-runs are
    // easy to spot/clean up, and IDs stay valid Firestore path segments.
    final slug = seed.location
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .toLowerCase();
    final docId =
        'citation-audit-${seed.condition}-$slug-${seed.ordinal}-${DateTime.now().millisecondsSinceEpoch}';
    final docName =
        'projects/$projectId/databases/(default)/documents/clinicalEvidenceReviews/$docId';

    final doc = {
      'status': 'pending',
      'entryRef': _entryRef(seed),
      'proposedContent': seed.proposedContent,
      'previousContent': seed.previousContent,
      // firestore.rules (2026-09-14) requires submittedBy to equal the
      // signed-in account's Auth email exactly — it can no longer be a
      // free-text label. The "who ran this" context lives in reviewNotes
      // instead.
      'submittedBy': email,
      'reviewedBy': null,
      'reviewedAt': null,
      'reviewNotes':
          'Filed by citation audit script (submitted via $email, '
          '${DateTime.now().toIso8601String().substring(0, 10)}). '
          '${seed.reviewNotes}',
      'gradeLevel': null,
    };

    final body = jsonEncode({
      'writes': [
        {
          'update': {
            'name': docName,
            'fields': _fields(doc),
          },
          'currentDocument': {'exists': false},
          'updateTransforms': [
            {
              'fieldPath': 'submittedAt',
              'setToServerValue': 'REQUEST_TIME',
            },
          ],
        },
      ],
    });

    final resp = await http.post(
      commitUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: body,
    );

    if (resp.statusCode == 200) {
      ok++;
      stdout.writeln('  OK    ${seed.condition} / ${seed.location} [#${seed.ordinal}]');
    } else {
      failed++;
      stderr.writeln(
        '  FAIL  ${seed.condition} / ${seed.location} [#${seed.ordinal}] '
        '(HTTP ${resp.statusCode}): ${resp.body}',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln('Done: $ok submitted, $failed failed, out of ${_seeds.length}.');
  if (failed > 0) exit(1);
}
