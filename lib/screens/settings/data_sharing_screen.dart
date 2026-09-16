import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:dhealth/models/doctor_patient_link.dart';
import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/services/doctor_patient_link_service.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/services/wearable_sync_service.dart';
import 'package:dhealth/screens/share_with_doctor_screen.dart';
import 'package:dhealth/screens/wearables/connect_devices_screen.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/widgets/empty_state_widget.dart';
import 'package:dhealth/widgets/error_state_widget.dart';
import 'package:dhealth/widgets/skeleton_widgets.dart';

/// Single overview of everyone/everything with access to this patient's
/// data — doctors granted access and connected wearable providers — each
/// with a one-tap revoke. Reads [DoctorPatientLinkService] and
/// [WearableRepository]/[WearableSyncService], the same services
/// ShareWithDoctorScreen and ConnectDevicesScreen already use; no new
/// backend structures.
class DataSharingScreen extends StatefulWidget {
  const DataSharingScreen({super.key});

  @override
  State<DataSharingScreen> createState() => _DataSharingScreenState();
}

class _DataSharingScreenState extends State<DataSharingScreen> {
  final DoctorPatientLinkService _linkService = DoctorPatientLinkService();
  final WearableRepository _wearableRepo = WearableRepository();
  late final WearableSyncService _wearableSync =
      WearableSyncService(repo: _wearableRepo);

  bool _loading = true;
  String? _error;
  List<DoctorPatientLink> _doctorLinks = [];
  List<WearableSource> _wearableSources = [];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _linkService.getLinksForPatient(uid),
        _wearableRepo.listActiveSources(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _doctorLinks = results[0] as List<DoctorPatientLink>;
        _wearableSources = results[1] as List<WearableSource>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _revokeDoctor(DoctorPatientLink link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          '${link.doctorEmail} will no longer be able to view your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Revoke', style: TextStyle(color: AppTheme.dangerColor)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await _linkService.revokeLink(
        patientId: link.patientId,
        doctorEmail: link.doctorEmail,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access revoked.')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _revokeWearable(WearableSource source) async {
    final name = _providerName(source.provider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect device'),
        content: Text(
          'Disconnect $name? All synced data from this device will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disconnect', style: TextStyle(color: AppTheme.dangerColor)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final uid = _uid;
    if (uid == null) return;
    try {
      await _wearableSync.disconnect(uid, source.provider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name disconnected')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  static String _providerName(WearableProvider p) {
    switch (p) {
      case WearableProvider.fitbit:
        return 'Fitbit';
      case WearableProvider.appleHealth:
        return 'Apple Health';
      case WearableProvider.garmin:
        return 'Garmin';
      case WearableProvider.oura:
        return 'Oura';
      case WearableProvider.samsungHealth:
        return 'Samsung Health';
      case WearableProvider.googleFit:
        return 'Google Fit';
    }
  }

  static String _providerEmoji(WearableProvider p) {
    switch (p) {
      case WearableProvider.fitbit:
        return '⌚';
      case WearableProvider.appleHealth:
        return '🍎';
      case WearableProvider.garmin:
        return '🏃';
      case WearableProvider.oura:
        return '💍';
      case WearableProvider.samsungHealth:
        return '📱';
      case WearableProvider.googleFit:
        return '📊';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sharing'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_uid == null) {
      return const EmptyStateWidget(
        emoji: '🔐',
        title: 'Sign in required',
        description: 'Sign in to see who has access to your data.',
      );
    }

    if (_loading) {
      return ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: const [
          SkeletonLogCard(),
          SizedBox(height: 12),
          SkeletonLogCard(),
        ],
      );
    }

    if (_error != null) {
      return ErrorStateWidget(
        title: 'Could not load sharing settings',
        description: _error!,
        onRetry: _load,
      );
    }

    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Doctors with access', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: AppSpacing.sm),
        if (_doctorLinks.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No doctors have access yet.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ShareWithDoctorScreen()),
                    ).then((_) => _load()),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Share with a doctor'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._doctorLinks.map((link) => Card(
                margin: EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: Text(link.doctorEmail),
                  subtitle: Text(
                    'Since ${link.consentedAt.toString().substring(0, 10)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _revokeDoctor(link),
                    child: Text('Revoke', style: TextStyle(color: AppTheme.dangerColor)),
                  ),
                ),
              )),
        SizedBox(height: AppSpacing.xl),
        Text('Connected wearables', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: AppSpacing.sm),
        if (_wearableSources.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No wearables connected yet.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConnectDevicesScreen()),
                    ).then((_) => _load()),
                    icon: const Icon(Icons.watch, size: 18),
                    label: const Text('Connect a device'),
                  ),
                ],
              ),
            ),
          )
        else
          ..._wearableSources.map((source) => Card(
                margin: EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: Text(
                    _providerEmoji(source.provider),
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(_providerName(source.provider)),
                  subtitle: Text(
                    'Last synced ${source.lastSyncedAt.toString().substring(0, 10)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _revokeWearable(source),
                    child: Text('Disconnect', style: TextStyle(color: AppTheme.dangerColor)),
                  ),
                ),
              )),
      ],
    );
  }
}
