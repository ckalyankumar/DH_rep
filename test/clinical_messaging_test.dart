import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dhealth/models/clinical_message.dart';
import 'package:dhealth/models/doctor_session.dart';
import 'package:dhealth/screens/doctor_clinical_thread_screen.dart';
import 'package:dhealth/screens/patient_clinical_thread_screen.dart';
import 'package:dhealth/services/clinical_messaging_service.dart';

class _FakeClinicalMessagingService extends Fake
    implements ClinicalMessagingService {
  Object? sendError;
  final List<String> sentContents = [];
  final StreamController<List<ClinicalMessage>> _updates =
      StreamController<List<ClinicalMessage>>.broadcast();

  void emitMessages(List<ClinicalMessage> messages) {
    _updates.add(messages);
  }

  @override
  Future<DoctorSession?> getLastDoctorView({
    required String patientId,
    required String doctorEmail,
  }) async =>
      null;

  @override
  Stream<List<ClinicalMessage>> streamMessages({
    required String patientId,
    required String doctorEmail,
  }) =>
      _updates.stream;

  @override
  Future<void> sendMessage({
    required String patientId,
    required String doctorEmail,
    required String sender,
    required String content,
    String? dataRangeReviewed,
  }) async {
    if (sendError != null) throw sendError!;
    sentContents.add(content);
  }

  void dispose() {
    _updates.close();
  }
}

ClinicalMessage _msg({
  required String id,
  required String sender,
  required String content,
  bool hasPendingWrites = false,
}) {
  return ClinicalMessage(
    id: id,
    sender: sender,
    content: content,
    sentAt: DateTime(2026, 3, 13, 10, 30),
    hasPendingWrites: hasPendingWrites,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ClinicalMessage sender integrity', () {
    test('fromJson does not silently default malformed sender to patient', () {
      final missing = ClinicalMessage.fromJson({'content': 'hello'}, id: 'a');
      expect(missing.sender, ClinicalMessage.unknownSender);
      expect(missing.hasUnknownSender, isTrue);
      expect(missing.isFromPatient, isFalse);
      expect(missing.isFromDoctor, isFalse);

      final invalid = ClinicalMessage.fromJson(
        {'sender': 'nurse', 'content': 'guidance'},
        id: 'b',
      );
      expect(invalid.sender, ClinicalMessage.unknownSender);
      expect(invalid.hasUnknownSender, isTrue);
    });

    test('fromJson keeps valid patient and doctor senders', () {
      expect(
        ClinicalMessage.fromJson({'sender': 'patient', 'content': 'q'}, id: 'p')
            .isFromPatient,
        isTrue,
      );
      expect(
        ClinicalMessage.fromJson({'sender': 'doctor', 'content': 'a'}, id: 'd')
            .isFromDoctor,
        isTrue,
      );
    });
  });

  group('messageFromSnapshot pending writes and sender', () {
    test('maps metadata.hasPendingWrites onto the message', () {
      final pending = ClinicalMessagingService.messageFromSnapshot(
        id: 'm1',
        data: {
          'sender': 'doctor',
          'content': 'Queued locally',
          'sentAt': '2026-03-13T10:30:00.000',
        },
        hasPendingWrites: true,
      );
      expect(pending.hasPendingWrites, isTrue);
      expect(pending.isFromDoctor, isTrue);

      final confirmed = ClinicalMessagingService.messageFromSnapshot(
        id: 'm1',
        data: {
          'sender': 'doctor',
          'content': 'Queued locally',
          'sentAt': '2026-03-13T10:30:00.000',
        },
        hasPendingWrites: false,
      );
      expect(confirmed.hasPendingWrites, isFalse);
    });

    test('malformed sender is unknown, not patient', () {
      final msg = ClinicalMessagingService.messageFromSnapshot(
        id: 'bad',
        data: {'content': 'Do this twice daily'},
        hasPendingWrites: false,
      );
      expect(msg.sender, isNot('patient'));
      expect(msg.hasUnknownSender, isTrue);
      expect(msg.content, 'Do this twice daily');
    });
  });

  group('sanitizeEmailForPath', () {
    test('already-lowercase email produces the same path as before', () {
      expect(
        ClinicalMessagingService.sanitizeEmailForPath('doc@example.com'),
        'doc_at_example_com',
      );
      expect(
        ClinicalMessagingService.sanitizeEmailForPath('doc@example.com'),
        ClinicalMessagingService.sanitizeEmailForPath(
            'doc@example.com'.toLowerCase()),
      );
    });

    test('mixed-case input is lowercased inside the helper', () {
      expect(
        ClinicalMessagingService.sanitizeEmailForPath('Doc@Example.COM'),
        'doc_at_example_com',
      );
      expect(
        ClinicalMessagingService.sanitizeEmailForPath('DOC@EXAMPLE.COM'),
        ClinicalMessagingService.sanitizeEmailForPath('doc@example.com'),
      );
    });
  });

  group('message length validation', () {
    test('rejects over-limit content client-side', () {
      final over = 'x' * (ClinicalMessage.maxContentLength + 1);
      expect(
        ClinicalMessage.validateContentLength(over),
        'Message exceeds ${ClinicalMessage.maxContentLength} characters.',
      );
    });

    test('accepts content at the limit', () {
      final atLimit = 'x' * ClinicalMessage.maxContentLength;
      expect(ClinicalMessage.validateContentLength(atLimit), isNull);
      expect(ClinicalMessage.validateContentLength('short note'), isNull);
    });

    test('counter is hidden for short messages and shown near the limit', () {
      expect(ClinicalMessage.composerCounterText(10), '');
      expect(
        ClinicalMessage.composerCounterText(
          ClinicalMessage.maxContentLength -
              ClinicalMessage.counterVisibleRemaining,
        ),
        '${ClinicalMessage.maxContentLength - ClinicalMessage.counterVisibleRemaining}/${ClinicalMessage.maxContentLength}',
      );
    });
  });

  group('thread screens', () {
    late _FakeClinicalMessagingService fake;

    setUp(() {
      fake = _FakeClinicalMessagingService();
    });

    tearDown(() {
      fake.dispose();
    });

    Future<void> pumpDoctor(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorClinicalThreadScreen(
            patientId: 'patient-1',
            patientDisplayName: 'Ada',
            doctorEmail: 'doc@example.com',
            logs: const [],
            messagingService: fake,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> pumpPatient(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PatientClinicalThreadScreen(
            patientId: 'patient-1',
            doctorEmail: 'doc@example.com',
            messagingService: fake,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('doctor retry-after-failed-send preserves message text',
        (tester) async {
      fake.sendError = StateError('permission-denied');
      await pumpDoctor(tester);

      await tester.enterText(
          find.byType(TextField), 'Please review itch trend');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Please review itch trend'), findsOneWidget);
      expect(find.textContaining('Failed to send:'), findsOneWidget);
      expect(fake.sentContents, isEmpty);

      fake.sendError = null;
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      expect(fake.sentContents, ['Please review itch trend']);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('patient retry-after-failed-send preserves message text',
        (tester) async {
      fake.sendError = Exception('network');
      await pumpPatient(tester);

      await tester.enterText(find.byType(TextField), 'Is this expected?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Is this expected?'), findsOneWidget);
      expect(find.textContaining('Failed to send:'), findsOneWidget);

      fake.sendError = null;
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      expect(fake.sentContents, ['Is this expected?']);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);
    });

    testWidgets('pending-write indicator shows then hides when confirmed',
        (tester) async {
      await pumpDoctor(tester);

      fake.emitMessages([
        _msg(
          id: 'm1',
          sender: 'doctor',
          content: 'Still in local queue',
          hasPendingWrites: true,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('pending-write-m1')), findsOneWidget);
      expect(find.byTooltip('Sending...'), findsOneWidget);

      fake.emitMessages([
        _msg(
          id: 'm1',
          sender: 'doctor',
          content: 'Still in local queue',
          hasPendingWrites: false,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('pending-write-m1')), findsNothing);
      expect(find.byTooltip('Sending...'), findsNothing);
      expect(find.text('Still in local queue'), findsOneWidget);
    });

    testWidgets('patient thread pending-write indicator shows and hides',
        (tester) async {
      await pumpPatient(tester);

      fake.emitMessages([
        _msg(
          id: 'p1',
          sender: 'patient',
          content: 'Queued question',
          hasPendingWrites: true,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('pending-write-p1')), findsOneWidget);

      fake.emitMessages([
        _msg(
          id: 'p1',
          sender: 'patient',
          content: 'Queued question',
          hasPendingWrites: false,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('pending-write-p1')), findsNothing);
    });

    testWidgets('malformed sender is labeled unknown, not as patient or doctor',
        (tester) async {
      await pumpDoctor(tester);

      fake.emitMessages([
        _msg(
          id: 'u1',
          sender: ClinicalMessage.unknownSender,
          content: 'Do not misattribute this',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Unknown sender'), findsOneWidget);
      expect(find.text('Do not misattribute this'), findsOneWidget);
    });

    testWidgets('composer enforces maxLength of 2000', (tester) async {
      await pumpPatient(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, ClinicalMessage.maxContentLength);
    });

    testWidgets('length validation snackbar when over-limit text is submitted',
        (tester) async {
      await pumpDoctor(tester);
      final over = 'y' * (ClinicalMessage.maxContentLength + 1);
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.text = over;
      await tester.pump();

      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(
        find.text(
            'Message exceeds ${ClinicalMessage.maxContentLength} characters.'),
        findsOneWidget,
      );
      expect(fake.sentContents, isEmpty);
      expect(field.controller!.text, over);
    });
  });
}
