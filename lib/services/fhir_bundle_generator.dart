import 'dart:convert';
import 'package:dhealth/models/daily_log.dart';
import 'package:dhealth/models/flare_event.dart';
import 'package:dhealth/models/medication_exception_event.dart';
import 'package:uuid/uuid.dart';

/// FHIR R4 Bundle Generator - HIPAA & ABDM Compliant
class FHIRBundleGenerator {
  static const String fhirVersion = '4.0.1';
  static const String abdmVersion = '1.2.0';

  /// Generate FHIR Bundle from DailyLog entries
  static Map<String, dynamic> generateFHIRBundle({
    required String patientId,
    required String patientName,
    required String condition,
    required List<DailyLog> logs,
    required DateTime reportDate,
    List<MedicationExceptionEvent>? medicationExceptions,
    List<FlareEvent>? flareEvents,
  }) {
    const uuid = Uuid();
    final bundleId = uuid.v4();

    // Create Patient Resource
    final patientResource = _createPatientResource(patientId, patientName);

    // Create Condition Resource
    final conditionResource = _createConditionResource(
      resourceId: uuid.v4(),
      patientId: patientId,
      condition: condition,
    );

    // Create Observation Resources from Logs
    final observations = logs.map((log) {
      return _createObservationResource(
        resourceId: uuid.v4(),
        patientId: patientId,
        log: log,
      );
    }).toList();

    final extraObservations = <Map<String, dynamic>>[];
    if (medicationExceptions != null && medicationExceptions.isNotEmpty) {
      extraObservations.add(
        _createMedicationExceptionSummaryObservation(
          resourceId: uuid.v4(),
          patientId: patientId,
          events: medicationExceptions,
        ),
      );
    }
    if (flareEvents != null && flareEvents.isNotEmpty) {
      extraObservations.addAll(
        _createFlareObservations(
          uuid: uuid,
          patientId: patientId,
          events: flareEvents,
        ),
      );
    }

    // Create Composition (Document)
    final compositionResource = _createCompositionResource(
      resourceId: uuid.v4(),
      patientId: patientId,
      patientName: patientName,
      condition: condition,
      date: reportDate,
      observationCount: observations.length,
      extraObservationIds: extraObservations.map((o) => o['id'] as String).toList(),
    );

    // Build Bundle
    final entry = [
      {'resource': patientResource, 'fullUrl': 'urn:uuid:$patientId'},
      {'resource': conditionResource, 'fullUrl': 'urn:uuid:${conditionResource['id']}'},
      {'resource': compositionResource, 'fullUrl': 'urn:uuid:${compositionResource['id']}'},
      ...observations.map((obs) => {
            'resource': obs,
            'fullUrl': 'urn:uuid:${obs['id']}',
          }),
      ...extraObservations.map((obs) => {
            'resource': obs,
            'fullUrl': 'urn:uuid:${obs['id']}',
          }),
    ];

    return {
      'resourceType': 'Bundle',
      'id': bundleId,
      'meta': {
        'profile': [
          'http://hl7.org/fhir/bundle',
          'http://abdm.gov.in/fhir/Bundle/HealthDocumentRecord',
        ],
        'versionId': '1.0',
        'lastUpdated': DateTime.now().toIso8601String(),
      },
      'type': 'document',
      'timestamp': DateTime.now().toIso8601String(),
      'entry': entry,
      'signature': {
        'type': [
          {
            'system': 'urn:iso-astm:E1762-95:2013',
            'code': '1.2.840.10065.1.12.1.5',
          }
        ],
        'when': DateTime.now().toIso8601String(),
        'whoReference': {'reference': 'urn:uuid:$patientId'},
      },
    };
  }

  /// Create FHIR Patient Resource
  static Map<String, dynamic> _createPatientResource(String id, String name) {
    return {
      'resourceType': 'Patient',
      'id': id,
      'meta': {
        'profile': [
          'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient',
          'http://abdm.gov.in/fhir/StructureDefinition/Patient',
        ],
      },
      'identifier': [
        {
          'system': 'urn:abdm:official',
          'value': id,
        }
      ],
      'name': [
        {
          'use': 'official',
          'text': name,
        }
      ],
      'active': true,
    };
  }

  /// Create FHIR Condition Resource
  static Map<String, dynamic> _createConditionResource({
    required String resourceId,
    required String patientId,
    required String condition,
  }) {
    String snomedCode;
    String display;

    switch (condition.toLowerCase()) {
      case 'psoriasis':
        snomedCode = '9014002';
        display = 'Psoriasis';
        break;
      case 'eczema':
      case 'atopic dermatitis':
        snomedCode = '24079001';
        display = 'Atopic dermatitis';
        break;
      default:
        snomedCode = '404684003';
        display = 'Dermatological condition';
    }

    return {
      'resourceType': 'Condition',
      'id': resourceId,
      'meta': {
        'profile': [
          'http://hl7.org/fhir/us/core/StructureDefinition/us-core-condition',
          'http://abdm.gov.in/fhir/StructureDefinition/Condition',
        ],
      },
      'clinicalStatus': {
        'coding': [
          {
            'system': 'http://terminology.hl7.org/CodeSystem/condition-clinical',
            'code': 'active',
          }
        ],
      },
      'verificationStatus': {
        'coding': [
          {
            'system': 'http://terminology.hl7.org/CodeSystem/condition-ver-status',
            'code': 'unconfirmed',
          }
        ],
      },
      'code': {
        'coding': [
          {
            'system': 'http://snomed.info/sct',
            'code': snomedCode,
            'display': display,
          }
        ],
        'text': display,
      },
      'subject': {
        'reference': 'urn:uuid:$patientId',
      },
      'recordedDate': DateTime.now().toIso8601String(),
    };
  }

  /// Create FHIR Observation Resource from DailyLog
  static Map<String, dynamic> _createObservationResource({
    required String resourceId,
    required String patientId,
    required DailyLog log,
  }) {
    final riskScore = log.calculateRiskScore();

    return {
      'resourceType': 'Observation',
      'id': resourceId,
      'meta': {
        'profile': [
          'http://hl7.org/fhir/us/core/StructureDefinition/us-core-observation-lab',
          'http://abdm.gov.in/fhir/StructureDefinition/Observation',
        ],
      },
      'status': 'final',
      'category': [
        {
          'coding': [
            {
              'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': 'survey',
              'display': 'Survey',
            }
          ]
        }
      ],
      'code': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': '80546-7',
            'display': 'Symptom Survey',
          }
        ],
      },
      'subject': {
        'reference': 'urn:uuid:$patientId',
      },
      'effectiveDateTime': log.date.toIso8601String(),
      'issued': DateTime.now().toIso8601String(),
      'value': {
        'component': [
          {
            'code': {
              'coding': [
                {
                  'system': 'http://snomed.info/sct',
                  'code': '367450005',
                  'display': 'Mood',
                }
              ],
            },
            'valueQuantity': {
              'value': log.mood,
              'unit': '/5',
            },
          },
          {
            'code': {
              'coding': [
                {
                  'system': 'http://snomed.info/sct',
                  'code': '418799008',
                  'display': 'Symptom intensity',
                }
              ],
            },
            'valueQuantity': {
              'value': log.itchIntensity,
              'unit': '/10',
            },
          },
          {
            'code': {
              'coding': [
                {
                  'system': 'http://snomed.info/sct',
                  'code': '248218005',
                  'display': 'Stress level',
                }
              ],
            },
            'valueQuantity': {
              'value': log.stressLevel,
              'unit': '/10',
            },
          },
          {
            'code': {
              'coding': [
                {
                  'system': 'http://snomed.info/sct',
                  'code': '248262006',
                  'display': 'Sleep quality',
                }
              ],
            },
            'valueQuantity': {
              'value': log.sleepQuality,
              'unit': '/5',
            },
          },
        ],
      },
      'component': [
        {
          'code': {
            'coding': [
              {
                'system': 'http://abdm.gov.in/CodeSystem/risk-score',
                'code': 'risk-score',
                'display': 'Risk Assessment Score',
              }
            ],
          },
          'valueQuantity': {
            'value': riskScore,
            'unit': '/100',
          },
        }
      ],
      'note': [
        {
          'text': log.notes.isNotEmpty ? log.notes : 'Patient-logged symptom data',
        }
      ],
    };
  }

  /// Create FHIR Composition Resource (Document metadata)
  static Map<String, dynamic> _createCompositionResource({
    required String resourceId,
    required String patientId,
    required String patientName,
    required String condition,
    required DateTime date,
    required int observationCount,
    required List<String> extraObservationIds,
  }) {
    return {
      'resourceType': 'Composition',
      'id': resourceId,
      'meta': {
        'profile': [
          'http://hl7.org/fhir/us/ccda/StructureDefinition/us-core-composition',
          'http://abdm.gov.in/fhir/StructureDefinition/Composition',
        ],
      },
      'status': 'final',
      'type': {
        'coding': [
          {
            'system': 'http://loinc.org',
            'code': '60591-5',
            'display': 'Patient Summary note',
          }
        ],
      },
      'category': [
        {
          'coding': [
            {
              'system': 'http://loinc.org',
              'code': '11503-0',
              'display': 'Medical records',
            }
          ],
        }
      ],
      'subject': {
        'reference': 'urn:uuid:$patientId',
        'display': patientName,
      },
      'date': date.toIso8601String(),
      'author': [
        {
          'reference': 'urn:uuid:$patientId',
          'display': patientName,
        }
      ],
      'title': 'Health Document Record - $condition',
      'confidentiality': 'R',
      'section': [
        {
          'title': 'Symptom Summary',
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '29299-5',
                'display': 'Reason for visit note',
              }
            ],
          },
          'text': {
            'status': 'generated',
            'div': '<div xmlns="http://www.w3.org/1999/xhtml"><p>Patient-tracked symptom data for $condition over $observationCount days</p></div>',
          },
          'entry': [
            {
              'reference': 'urn:uuid:observation-summary',
            }
          ],
        }
        ,
        if (extraObservationIds.isNotEmpty)
          {
            'title': 'Flares and adherence',
            'text': {
              'status': 'generated',
              'div':
                  '<div xmlns="http://www.w3.org/1999/xhtml"><p>Derived flare events and patient-noted treatment exceptions (for context).</p></div>',
            },
            'entry': [
              ...extraObservationIds.map((id) => {'reference': 'urn:uuid:$id'}),
            ],
          },
      ],
    };
  }

  static Map<String, dynamic> _createMedicationExceptionSummaryObservation({
    required String resourceId,
    required String patientId,
    required List<MedicationExceptionEvent> events,
  }) {
    final missed =
        events.where((e) => e.type == MedicationExceptionType.missedDose).length;
    final stopped =
        events.where((e) => e.type == MedicationExceptionType.stopped).length;
    final changed =
        events.where((e) => e.type == MedicationExceptionType.changedDose).length;
    final side =
        events.where((e) => e.type == MedicationExceptionType.sideEffect).length;
    final latest = events
        .map((e) => e.occurredAt)
        .reduce((a, b) => a.isAfter(b) ? a : b)
        .toIso8601String();

    final narrative =
        'Exceptions recorded: ${events.length}. Missed: $missed. Changed: $changed. Stopped: $stopped. Side effects: $side. Latest: $latest.';

    return {
      'resourceType': 'Observation',
      'id': resourceId,
      'status': 'final',
      'category': [
        {
          'coding': [
            {
              'system':
                  'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': 'survey',
              'display': 'Survey',
            }
          ]
        }
      ],
      'code': {
        'coding': [
          {
            'system': 'http://dhealth.app/fhir',
            'code': 'medication-exceptions-summary',
            'display': 'Medication exceptions summary',
          }
        ],
        'text': 'Medication exceptions summary',
      },
      'subject': {'reference': 'urn:uuid:$patientId'},
      'effectiveDateTime': DateTime.now().toIso8601String(),
      'valueString': narrative,
    };
  }

  static List<Map<String, dynamic>> _createFlareObservations({
    required Uuid uuid,
    required String patientId,
    required List<FlareEvent> events,
  }) {
    final eligible =
        events.where((e) => e.isOutcomeEligible).toList(growable: false);
    eligible.sort((a, b) => a.onsetDate.compareTo(b.onsetDate));

    final summaryId = uuid.v4();
    final count = eligible.length;
    final mostRecent = eligible.isNotEmpty
        ? eligible.last.onsetDate.toIso8601String()
        : null;

    final obs = <Map<String, dynamic>>[
      {
        'resourceType': 'Observation',
        'id': summaryId,
        'status': 'final',
        'category': [
          {
            'coding': [
              {
                'system':
                    'http://terminology.hl7.org/CodeSystem/observation-category',
                'code': 'survey',
                'display': 'Survey',
              }
            ]
          }
        ],
        'code': {
          'coding': [
            {
              'system': 'http://dhealth.app/fhir',
              'code': 'flare-events-summary',
              'display': 'Flare events summary',
            }
          ],
          'text': 'Flare events summary',
        },
        'subject': {'reference': 'urn:uuid:$patientId'},
        'effectiveDateTime': DateTime.now().toIso8601String(),
        'valueString': mostRecent == null
            ? 'Confirmed/patient-initiated flare events: 0.'
            : 'Confirmed/patient-initiated flare events: $count. Most recent onset: $mostRecent.',
      }
    ];

    for (final e in eligible.take(30)) {
      obs.add({
        'resourceType': 'Observation',
        'id': uuid.v4(),
        'status': 'final',
        'category': [
          {
            'coding': [
              {
                'system':
                    'http://terminology.hl7.org/CodeSystem/observation-category',
                'code': 'survey',
                'display': 'Survey',
              }
            ]
          }
        ],
        'code': {
          'coding': [
            {
              'system': 'http://dhealth.app/fhir',
              'code': 'flare-event',
              'display': 'Flare event',
            }
          ],
          'text': 'Flare event',
        },
        'subject': {'reference': 'urn:uuid:$patientId'},
        'effectiveDateTime': e.onsetDate.toIso8601String(),
        'valueString': 'Source: ${e.source.jsonValue}'
            '${e.resolutionDate != null ? '; Resolved: ${e.resolutionDate!.toIso8601String()}' : ''}',
      });
    }
    return obs;
  }

  /// Convert FHIR Bundle to JSON string
  static String bundleToJson(Map<String, dynamic> bundle) {
    return jsonEncode(bundle);
  }

  /// Convert FHIR Bundle to XML (CCDA format)
  static String bundleToXml(Map<String, dynamic> bundle) {
    return _generateCCDAXml(bundle);
  }

  /// Generate CDA XML wrapper for HIPAA compliance
  static String _generateCCDAXml(Map<String, dynamic> bundle) {
    final timestamp = DateTime.now().toIso8601String();
    final patientId = bundle['entry']?[0]?['resource']?['id'] ?? 'unknown';

    return '''<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:sdtc="urn:hl7-org:sdtc" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <realmCode code="US"/>
    <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
    <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
    <id root="2.16.840.1.113883.3.3" extension="DHealth-$patientId"/>
    <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Summary of Care"/>
    <effectiveTime value="$timestamp"/>
    <confidentialityCode code="R" codeSystem="2.16.840.1.113883.5.25"/>
    <recordTarget>
        <patientRole>
            <id root="2.16.840.1.113883.3.3" extension="$patientId"/>
            <patient>
                <name>${bundle['entry']?[0]?['resource']?['name']?[0]?['text'] ?? 'Unknown Patient'}</name>
            </patient>
        </patientRole>
    </recordTarget>
    <author>
        <time value="$timestamp"/>
        <assignedAuthor>
            <id root="2.16.840.1.113883.3.3" extension="dhealth-system"/>
            <representedOrganization>
                <name>DHealth</name>
            </representedOrganization>
        </assignedAuthor>
    </author>
    <custodian>
        <assignedCustodian>
            <representedCustodianOrganization>
                <id root="2.16.840.1.113883.3.3" extension="dhealth-custodian"/>
                <name>DHealth Custodian</name>
            </representedCustodianOrganization>
        </assignedCustodian>
    </custodian>
    <component>
        <structuredBody>
            <component>
                <section>
                    <templateId root="2.16.840.1.113883.10.20.22.2.4"/>
                    <code code="8716-3" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Vital Signs"/>
                    <title>Symptom Data</title>
                    <text>Patient-tracked health information</text>
                </section>
            </component>
        </structuredBody>
    </component>
</ClinicalDocument>''';
  }
}
