import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_scope.dart';
import '../auth/social_auth.dart';
import '../core/app_scope.dart';
import '../core/audio_controller.dart';
import '../core/legal.dart';
import '../widgets/common.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  /// iOS builds always offer Apple next to Google (App Review Guideline 4.8).
  /// Web and Android need an Apple Services ID first, so they opt in per build.
  static const appleConfigured = bool.fromEnvironment('APPLE_SIGN_IN_ENABLED');

  static bool get appleOnThisPlatform =>
      appleConfigured ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final identity = auth.identity;
    final signedIn = auth.isSignedIn;
    final appleAvailable = auth.isEmulator || appleOnThisPlatform;
    return AppScaffold(
      title: signedIn ? 'Your account.' : 'Make yourself\nat home.',
      eyebrow: signedIn ? 'A home for your journeys' : 'Your journey begins',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: const AppImage(
              path: 'assets/images/steppe.jpg',
              height: 190,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 24),
          if (auth.isEmulator) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: DemoBadge(text: 'LOCAL TEST · SIMULATED ACCOUNTS'),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            signedIn ? identity!.displayName : 'Your journey, your account.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            signedIn
                ? identity!.email ?? 'Signed in securely with your account.'
                : 'Sign in or create an account with Google or Apple. No separate password to remember.',
          ),
          const SizedBox(height: 26),
          if (signedIn) ...[
            PillButton(
              label: 'Continue exploring',
              icon: Icons.arrow_forward_rounded,
              onPressed: auth.busy ? null : () => context.go('/steppe'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: auth.busy ? null : () => auth.signOut(),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: auth.busy ? null : () => _deleteAccount(context),
              icon: const Icon(Icons.delete_forever_outlined, size: 20),
              label: const Text('Delete account'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
            if (auth.busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ] else ...[
            _ProviderButton(
              label: 'Continue with Google',
              icon: Image.asset(
                'assets/icons/google_g.png',
                width: 20,
                height: 20,
              ),
              onPressed: auth.busy
                  ? null
                  : () => auth.signIn(SocialProvider.google),
            ),
            const SizedBox(height: 12),
            _ProviderButton(
              label: 'Continue with Apple',
              icon: const Icon(Icons.apple, size: 24),
              dark: true,
              onPressed: auth.busy || !appleAvailable
                  ? null
                  : () => auth.signIn(SocialProvider.apple),
            ),
            if (!appleAvailable) ...[
              const SizedBox(height: 8),
              Text(
                'Apple sign-in is coming soon.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (auth.busy)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: auth.busy
                  ? null
                  : () async {
                      await AppScope.of(context).enterGuest();
                      if (context.mounted) context.go('/steppe');
                    },
              child: const Text('Continue as a guest'),
            ),
          ],
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              child: Text(
                auth.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            auth.isEmulator
                ? 'These are simulated sign-ins for local testing. No real Google or Apple account is used.'
                : 'Your stories and reading progress are saved to your account. Reading settings and downloads stay on this device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
          TextButton(
            onPressed: () => openPrivacyPolicy(context),
            child: const Text('Privacy Policy'),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently deletes your account, your saved stories and your reading progress. '
        'You will be asked to sign in once more to confirm. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final auth = AuthScope.of(context);
  final app = AppScope.of(context);
  final audio = context.getInheritedWidgetOfExactType<AudioScope>()?.notifier;
  if (!await auth.deleteAccount()) return;
  await audio?.stop();
  // Nothing from the deleted account stays behind on this device either.
  await app.resetDemo();
  // Ending the session rebuilds the app, which returns to the welcome screen.
  if (context.mounted) context.go('/welcome');
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.dark = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool dark;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: icon,
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: dark ? Colors.white : const Color(0xFF1F1F1F),
      backgroundColor: dark ? Colors.black : Colors.white,
      disabledBackgroundColor: dark ? const Color(0xFF707070) : Colors.white,
      disabledForegroundColor: dark ? Colors.white70 : Colors.grey,
      side: BorderSide(color: dark ? Colors.black : const Color(0xFF747775)),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  );
}
