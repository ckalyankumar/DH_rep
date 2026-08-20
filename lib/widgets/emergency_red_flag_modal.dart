import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/services/firestore_red_flag_acknowledgement_service.dart';

/// Full-screen non-dismissable modal for emergency red flags.
/// Only the confirm button dismisses. Logs RedFlagAcknowledgement to Firestore.
class EmergencyRedFlagModal extends StatelessWidget {
  final RedFlag flag;
  final VoidCallback onDismissed;
  final FirestoreRedFlagAcknowledgementService acknowledgementService;

  const EmergencyRedFlagModal({
    super.key,
    required this.flag,
    required this.onDismissed,
    required this.acknowledgementService,
  });

  static Future<void> show(
    BuildContext context, {
    required RedFlag flag,
    required FirestoreRedFlagAcknowledgementService acknowledgementService,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PopScope(
          canPop: false,
          child: EmergencyRedFlagModal(
            flag: flag,
            acknowledgementService: acknowledgementService,
            onDismissed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    await acknowledgementService.logAcknowledgement(
      flagType: flag.symptom,
      timestamp: DateTime.now(),
      actionConfirmed: true,
      urgency: 'emergency',
    );
    onDismissed();
  }

  Future<void> _onCallEmergency() async {
    final uri = Uri.parse('tel:112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _onContactDermatologist() async {
    final uri = Uri.parse('tel:000');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Emergency Health Alert',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                flag.symptom,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB71C1C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                flag.whyImportant,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _onCallEmergency();
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call emergency services'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _onContactDermatologist,
                  icon: const Icon(Icons.medical_services),
                  label: const Text('Contact dermatologist now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[800],
                    side: BorderSide(color: Colors.red[700]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('I understand and will seek help'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
