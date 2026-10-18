import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_scope.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'sign_in_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: buildOvTheme(true),
    child: Scaffold(
      backgroundColor: OvColors.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppImage(path: 'assets/images/welcome.jpg'),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x7D0C1F14),
                  Color(0x330C1F14),
                  Color(0xE80C1F14),
                  Color(0xFF0C1F14),
                ],
                stops: [0, .28, .69, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 26, 26, 28),
                        child: SizedBox(
                          height: (constraints.maxHeight - 54).clamp(
                            640.0,
                            double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _GeretWordmark(),
                              const Spacer(),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: DemoBadge(
                                  text: 'ÖV AI · INTERACTIVE PROTOTYPE',
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Every place on the steppe has a story.',
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      color: OvColors.cream,
                                      fontSize: constraints.maxWidth < 370
                                          ? 35
                                          : 40,
                                      height: 1.1,
                                      letterSpacing: -.8,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Stand where history happened. Read it, listen to it, and write the next chapter yourself.',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: OvColors.cream.withValues(
                                        alpha: .86,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 28),
                              PillButton(
                                label: 'Begin your journey',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: () => context.push('/profile-setup'),
                              ),
                              const SizedBox(height: 10),
                              PillButton(
                                label: 'Explore as a guest',
                                secondary: true,
                                onPressed: () async {
                                  await AppScope.of(context).enterGuest();
                                  if (context.mounted) context.go('/steppe');
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                AuthScope.maybeOf(context) == null
                                    ? 'Prepared stories. Real places.\nYour journey stays on this device.'
                                    : AuthScope.of(context).isEmulator
                                    ? 'Prepared stories. Real places.\nExplore with a local test account.'
                                    : 'Prepared stories. Real places.\nSign in to save your journey.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: OvColors.cream.withValues(
                                        alpha: .68,
                                      ),
                                      height: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GeretWordmark extends StatelessWidget {
  const _GeretWordmark();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 47,
        height: 47,
        child: CustomPaint(painter: _GerMarkPainter()),
      ),
      SizedBox(width: 12),
      Text(
        'geret',
        style: TextStyle(
          fontFamily: 'Poppins',
          color: OvColors.cream,
          fontSize: 39,
          fontWeight: FontWeight.w500,
          letterSpacing: -1.7,
        ),
      ),
    ],
  );
}

class _GerMarkPainter extends CustomPainter {
  const _GerMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = OvColors.cream
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(w * .13, h * .42)
        ..lineTo(w * .5, h * .15)
        ..lineTo(w * .87, h * .42)
        ..lineTo(w * .87, h * .85)
        ..lineTo(w * .13, h * .85)
        ..close(),
      p,
    );
    canvas.drawLine(Offset(w * .13, h * .45), Offset(w * .87, h * .45), p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .42, h * .58, w * .16, h * .27),
        const Radius.circular(3),
      ),
      p,
    );
    canvas.drawLine(Offset(w * .44, h * .13), Offset(w * .56, h * .13), p);
    canvas.drawLine(Offset(w * .5, h * .15), Offset(w * .5, h * .04), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DemoProfileScreen extends StatefulWidget {
  const DemoProfileScreen({super.key});
  @override
  State<DemoProfileScreen> createState() => _DemoProfileScreenState();
}

class _DemoProfileScreenState extends State<DemoProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final state = AppScope.of(context);
      if (!state.isGuest) _name.text = state.profileName ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _destination({bool guest = false}) {
    final value = GoRouterState.of(context).uri.queryParameters['next'];
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        uri.path.startsWith('/') &&
        uri.path != '/profile-setup' &&
        !uri.path.startsWith('//')) {
      if (guest &&
          (uri.path.startsWith('/inscribe/') || uri.path == '/offline')) {
        return '/steppe';
      }
      return uri.toString();
    }
    return '/steppe';
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).setProfile(_name.text.trim());
      if (mounted) context.go(_destination());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your profile could not be saved. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScope.maybeOf(context) != null
      ? const SignInScreen()
      : AppScaffold(
          title: 'Make yourself\nat home.',
          eyebrow: 'Your journey begins',
          child: Form(
            key: _formKey,
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
                const SizedBox(height: 22),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: DemoBadge(text: 'DEMO PROFILE · ON THIS DEVICE'),
                ),
                const SizedBox(height: 16),
                Text(
                  'A name for your stories.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose how you’d like to be known on the steppe. Your profile, stories and reading progress are saved here.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Traveller name',
                    hintText: 'e.g. Saran',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter a name with at least 2 characters.'
                      : null,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Start exploring',
                  icon: Icons.arrow_forward_rounded,
                  busy: _busy,
                  onPressed: _save,
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Continue as a guest',
                  secondary: true,
                  onPressed: _busy
                      ? null
                      : () async {
                          await AppScope.of(context).enterGuest();
                          if (context.mounted) {
                            context.go(_destination(guest: true));
                          }
                        },
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.phone_iphone_rounded,
                        color: OvColors.brown,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This prototype uses a local profile and prepared stories. Cloud accounts and live AI are planned for a later version.',
                          style: TextStyle(fontSize: 12, height: 1.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
}
