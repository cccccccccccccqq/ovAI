import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_scope.dart';
import '../auth/social_auth.dart';
import '../core/app_scope.dart';
import '../widgets/common.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  static const appleConfigured = bool.fromEnvironment('APPLE_SIGN_IN_ENABLED');

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final identity = auth.identity;
    final signedIn = auth.isSignedIn;
    final appleAvailable = auth.isEmulator || appleConfigured;
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
                : 'Your sign-in is secured by Firebase. Stories and reading progress are currently saved on this device for each account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
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
