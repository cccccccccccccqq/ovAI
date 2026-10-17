/// The two account providers offered by the application.
enum SocialProvider { google, apple }

extension SocialProviderDetails on SocialProvider {
  String get providerId => switch (this) {
    SocialProvider.google => 'google.com',
    SocialProvider.apple => 'apple.com',
  };

  String get label => switch (this) {
    SocialProvider.google => 'Google',
    SocialProvider.apple => 'Apple',
  };
}

/// Public profile information only. Credentials and tokens never enter app state.
class AppIdentity {
  AppIdentity({
    required this.uid,
    String? displayName,
    this.email,
    this.photoUrl,
    required Set<String> providers,
    this.isAnonymous = false,
    this.emailVerified = false,
  }) : displayName = sanitizeDisplayName(displayName),
       providers = Set.unmodifiable(providers) {
    if (uid.trim().isEmpty) throw ArgumentError.value(uid, 'uid');
  }

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
  final Set<String> providers;
  final bool isAnonymous;
  final bool emailVerified;

  bool get isRegistered => !isAnonymous && providers.isNotEmpty;

  /// Matches the backend profile limit and avoids storing control characters.
  static String sanitizeDisplayName(String? value) {
    final name = (value ?? '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return name.isEmpty
        ? 'Traveler'
        : String.fromCharCodes(name.runes.take(60));
  }
}

/// A code with no provider response, credentials, or personal data attached.
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final String code;

  bool get isCancelled => const {
    'cancelled',
    'canceled',
    'sign_in_canceled',
    'sign-in-canceled',
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-cancelled',
    'web-context-canceled',
    'user-cancelled',
    'user-canceled',
  }.contains(code);
}

/// Firebase-independent boundary so session and error behavior can be tested.
abstract interface class AuthGateway {
  bool get isEmulator;
  AppIdentity? get currentIdentity;
  Stream<AppIdentity?> get identityChanges;

  /// Restores the SDK's persisted session; it must not sign in a new user.
  Future<void> initialize();

  /// An anonymous user is linked, preserving their UID, or the operation fails.
  Future<AppIdentity> signIn(SocialProvider provider);
  Future<void> signOut();
  Future<void> dispose();
}
