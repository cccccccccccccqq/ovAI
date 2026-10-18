import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hosted with the web app; App Store Connect lists the same address.
final privacyPolicyUrl = Uri.parse('https://ov-ai-5ae61.web.app/privacy.html');

Future<void> openPrivacyPolicy(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      privacyPolicyUrl,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Open $privacyPolicyUrl in your browser.')),
    );
  }
}
