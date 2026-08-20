import 'package:flutter/material.dart';
import 'package:dhealth/models/clinical_evidence_models.dart';
import 'package:dhealth/services/firestore_red_flag_acknowledgement_service.dart';

/// Persistent banner for urgent red flags. Reappears on every app open
/// until patient logs action taken.
class UrgentRedFlagBanner extends StatefulWidget {
  final List<RedFlag> urgentFlags;
  final FirestoreRedFlagAcknowledgementService acknowledgementService;
  final VoidCallback? onActionLogged;

  const UrgentRedFlagBanner({
    super.key,
    required this.urgentFlags,
    required this.acknowledgementService,
    this.onActionLogged,
  });

  @override
  State<UrgentRedFlagBanner> createState() => _UrgentRedFlagBannerState();
}

class _UrgentRedFlagBannerState extends State<UrgentRedFlagBanner> {
  List<RedFlag> _unacknowledgedFlags = [];
  bool _isLoading = true;
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _filterUnacknowledged();
  }

  @override
  void didUpdateWidget(UrgentRedFlagBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urgentFlags != widget.urgentFlags) {
      _filterUnacknowledged();
    }
  }

  Future<void> _filterUnacknowledged() async {
    setState(() => _isLoading = true);
    try {
      final types = widget.urgentFlags.map((f) => f.symptom).toList();
      final unackTypes =
          await widget.acknowledgementService.filterUnacknowledgedUrgentFlags(
        types,
      );
      final unack = widget.urgentFlags
          .where((f) => unackTypes.contains(f.symptom))
          .toList();
      if (mounted) {
        setState(() {
          _unacknowledgedFlags = unack;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unacknowledgedFlags = widget.urgentFlags;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onLogActionTaken(RedFlag flag) async {
    setState(() => _isLogging = true);
    try {
      await widget.acknowledgementService.logAcknowledgement(
        flagType: flag.symptom,
        timestamp: DateTime.now(),
        actionConfirmed: true,
        urgency: 'urgent',
      );
      if (mounted) {
        setState(() {
          _unacknowledgedFlags =
              _unacknowledgedFlags.where((f) => f.symptom != flag.symptom).toList();
          _isLogging = false;
        });
        widget.onActionLogged?.call();
      }
    } catch (e) {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _unacknowledgedFlags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border(
          bottom: BorderSide(color: Colors.orange[300]!, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange[800], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Urgent: ${_unacknowledgedFlags.first.symptom}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _unacknowledgedFlags.first.whyImportant,
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[900],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLogging
                  ? null
                  : () => _onLogActionTaken(_unacknowledgedFlags.first),
              icon: _isLogging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle, size: 18),
              label: Text(_isLogging ? 'Logging...' : 'I\'ve taken action'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
