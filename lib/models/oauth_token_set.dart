/// A decrypted OAuth2 token pair passed between [WearableAdapter] and
/// [WearableSyncService]. Adapters never see the encrypted-at-rest
/// representation stored on [WearableSource] — the sync service handles
/// that boundary.
class OAuthTokenSet {
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;

  const OAuthTokenSet({
    required this.accessToken,
    this.refreshToken = '',
    this.expiresAt,
  });

  /// True once within 5 minutes of [expiresAt], or if [expiresAt] is unset
  /// but a refresh token exists (unknown expiry — safer to assume stale).
  /// Adapters with no real OAuth (on-device / mock) never set [expiresAt]
  /// or [refreshToken], so this stays false for them and refreshToken()
  /// is skipped, same as their existing no-op behavior.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 5)));
  }
}
