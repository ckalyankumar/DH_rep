import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:dhealth/models/wearable_source.dart';
import 'package:dhealth/models/sync_audit_record.dart';
import 'package:dhealth/services/wearable_repository.dart';
import 'package:dhealth/services/wearable_sync_service.dart';
import 'package:dhealth/services/wearables/wearable_adapter_factory.dart';
import 'package:dhealth/utils/theme.dart';
import 'package:dhealth/utils/spacing.dart';
import 'package:dhealth/widgets/empty_state_widget.dart';

class WearableViewModel extends ChangeNotifier {
  final String uid;
  final WearableRepository _repo;
  final WearableSyncService _sync;

  List<WearableSource> _sources = [];
  final Set<WearableProvider> _connecting = {};
  bool _loading = true;
  String? _loadError;
  bool _syncing = false;
  DateTime? _lastSyncAt;

  WearableViewModel({
    required this.uid,
    WearableRepository? repo,
    WearableSyncService? sync,
  })  : _repo = repo ?? WearableRepository(),
        _sync = sync ?? WearableSyncService(repo: repo ?? WearableRepository());

  List<WearableSource> get sources => _sources;
  bool get loading => _loading;
  String? get loadError => _loadError;
  bool get syncing => _syncing;
  DateTime? get lastSyncAt => _lastSyncAt;

  bool isConnected(WearableProvider p) =>
      _sources.any((s) => s.provider == p && s.isActive);

  bool isConnecting(WearableProvider p) => _connecting.contains(p);

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      _sources = await _repo.listActiveSources(uid);
      _loadError = null;
      final audit = await _repo.getLatestSyncAudit(uid);
      final maxSourceSync = _sources.isEmpty
          ? null
          : _sources.map((s) => s.lastSyncedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      if (audit != null && (maxSourceSync == null || audit.ranAt.isAfter(maxSourceSync))) {
        _lastSyncAt = audit.ranAt;
      } else if (maxSourceSync != null) {
        _lastSyncAt = maxSourceSync;
      } else {
        _lastSyncAt = audit?.ranAt;
      }
    } catch (e) {
      _loadError = 'Failed to load devices: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> connect(WearableProvider provider) async {
    _connecting.add(provider);
    notifyListeners();

    try {
      await _sync.connect(uid, provider);
      await load();
      return true;
    } catch (e) {
      rethrow;
    } finally {
      _connecting.remove(provider);
      notifyListeners();
    }
  }

  Future<void> disconnect(WearableProvider provider) async {
    await _sync.disconnect(uid, provider);
    await load();
  }

  Future<SyncResult> syncNow() async {
    _syncing = true;
    notifyListeners();
    final stopwatch = Stopwatch()..start();
    try {
      final result = await _sync.syncAll(uid);
      stopwatch.stop();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final date =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      await _repo.saveSyncAudit(SyncAuditRecord(
        uid: uid,
        ranAt: DateTime.now(),
        date: date,
        successCount: result.successCount,
        failureCount: result.failureCount,
        errors: result.errors,
        durationMs: stopwatch.elapsedMilliseconds,
      ));
      _lastSyncAt = DateTime.now();
      await load();
      return result;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}

class ConnectDevicesScreen extends StatefulWidget {
  final WearableViewModel? viewModel;

  const ConnectDevicesScreen({
    super.key,
    this.viewModel,
  });

  @override
  State<ConnectDevicesScreen> createState() => _ConnectDevicesScreenState();
}

class _ConnectDevicesScreenState extends State<ConnectDevicesScreen> {
  late WearableViewModel _vm;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _vm = WearableViewModel(uid: '');
      return;
    }
    _vm = widget.viewModel ?? WearableViewModel(uid: user.uid);
    _vm.addListener(_onVmChanged);
    _vm.load();
  }

  void _onVmChanged() => setState(() {});

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    super.dispose();
  }

  Future<void> _onConnect(WearableProvider provider) async {
    try {
      final ok = await _vm.connect(provider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '${_providerName(provider)} connected' : 'Connection failed'),
          backgroundColor: ok ? AppTheme.accentColor : AppTheme.dangerColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _onSyncNow() async {
    if (_vm.sources.isEmpty) return;
    try {
      final result = await _vm.syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureCount > 0
                ? 'Synced ${result.successCount} sources (${result.failureCount} failed)'
                : 'Synced ${result.successCount} sources',
          ),
          backgroundColor:
              result.successCount > 0 ? AppTheme.accentColor : AppTheme.warningColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _onDisconnect(WearableProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect device'),
        content: Text(
          'Disconnect ${_providerName(provider)}? All synced data from this device will be removed.',
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
    await _vm.disconnect(provider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_providerName(provider)} disconnected')),
      );
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

  static String _scopeLabel(WearableScope s) {
    switch (s) {
      case WearableScope.sleep:
        return 'Sleep';
      case WearableScope.hrv:
        return 'HRV';
      case WearableScope.activity:
        return 'Activity';
      case WearableScope.heartRate:
        return 'Heart rate';
      case WearableScope.stress:
        return 'Stress';
      case WearableScope.readiness:
        return 'Readiness';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_vm.uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Connect devices'),
          backgroundColor: AppTheme.primary,
        ),
        body: EmptyStateWidget(
          emoji: '🔐',
          title: 'Sign in required',
          description: 'Sign in to connect your wearable devices and sync health data.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect devices'),
        backgroundColor: AppTheme.primary,
      ),
      body: _vm.loading
          ? const Center(child: CircularProgressIndicator())
          : _vm.loadError != null
              ? EmptyStateWidget(
                  emoji: '⚠️',
                  title: 'Couldn\'t load devices',
                  description: _vm.loadError!,
                  actionLabel: 'Retry',
                  onAction: _vm.load,
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ConsentBanner(),
                      SizedBox(height: AppSpacing.lg),
                      _SyncNowSection(
                        lastSyncAt: _vm.lastSyncAt,
                        syncing: _vm.syncing,
                        hasConnected: _vm.sources.isNotEmpty,
                        onSyncNow: _onSyncNow,
                      ),
                      SizedBox(height: AppSpacing.xl),
                      Text(
                        'Providers',
                        style: theme.textTheme.labelMedium,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        itemCount: WearableProvider.values.length,
                        itemBuilder: (context, i) {
                          final p = WearableProvider.values[i];
                          return _ProviderCard(
                            provider: p,
                            name: _providerName(p),
                            emoji: _providerEmoji(p),
                            scopes: WearableAdapterFactory.get(p).supportedScopes,
                            isConnected: _vm.isConnected(p),
                            isConnecting: _vm.isConnecting(p),
                            onConnect: () => _onConnect(p),
                            onDisconnect: () => _onDisconnect(p),
                            scopeLabel: _scopeLabel,
                          );
                        },
                      ),
                      SizedBox(height: AppSpacing.xxl),
                      Text(
                        'What each data type is used for',
                        style: theme.textTheme.labelMedium,
                      ),
                      SizedBox(height: AppSpacing.md),
                      _DataUsageSection(scopeLabel: _scopeLabel),
                    ],
                  ),
                ),
    );
  }
}

String _timeAgo(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${(diff.inDays / 7).floor()} wk ago';
}

class _SyncNowSection extends StatelessWidget {
  final DateTime? lastSyncAt;
  final bool syncing;
  final bool hasConnected;
  final VoidCallback onSyncNow;

  const _SyncNowSection({
    required this.lastSyncAt,
    required this.syncing,
    required this.hasConnected,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastSyncAt != null
                  ? 'Last synced: ${_timeAgo(lastSyncAt!)}'
                  : 'Never synced',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasConnected && !syncing ? onSyncNow : null,
                icon: syncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.sync),
                label: Text(syncing ? 'Syncing…' : 'Sync now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: AppTheme.primary),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your data, your control',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Wearable data syncs nightly to your account only. Disconnect any time to delete all synced data.\n'
            'Doctors see derived summaries only — never your raw device data.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final WearableProvider provider;
  final String name;
  final String emoji;
  final List<WearableScope> scopes;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final String Function(WearableScope) scopeLabel;

  const _ProviderCard({
    required this.provider,
    required this.name,
    required this.emoji,
    required this.scopes,
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
    required this.onDisconnect,
    required this.scopeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isConnected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: scopes
                  .map((s) => Chip(
                        label: Text(
                          scopeLabel(s),
                          style: TextStyle(fontSize: 11),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: isConnecting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Text('Connecting…', style: theme.textTheme.bodySmall),
                      ],
                    )
                  : isConnected
                      ? OutlinedButton(
                          onPressed: onDisconnect,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceAlt,
                            foregroundColor: AppTheme.textSecondary,
                          ),
                          child: const Text('Disconnect'),
                        )
                      : ElevatedButton(
                          onPressed: onConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Connect'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataUsageSection extends StatelessWidget {
  final String Function(WearableScope) scopeLabel;

  const _DataUsageSection({required this.scopeLabel});

  static const Map<WearableScope, String> _descriptions = {
    WearableScope.sleep:
        'Total sleep, deep %, awakenings — mapped to your daily sleep quality score',
    WearableScope.hrv:
        'Nightly HRV — used by InsightEngine for personalised risk weighting',
    WearableScope.activity:
        'Steps & active minutes — sedentary context for stress and inflammation risk',
    WearableScope.heartRate:
        'Resting HR — secondary HRV proxy where HRV is unavailable',
    WearableScope.stress:
        'Device stress score (Garmin only) — fused with self-reported stress',
    WearableScope.readiness:
        'Oura readiness score — direct input to flare risk modifier',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: WearableScope.values
          .map((s) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(
                        scopeLabel(s),
                        style: const TextStyle(fontSize: 11),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _descriptions[s] ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
