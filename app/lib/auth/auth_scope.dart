import 'package:flutter/widgets.dart';

import 'social_auth.dart';

class AuthScope extends InheritedNotifier<SocialAuthController> {
  const AuthScope({
    super.key,
    required SocialAuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static SocialAuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;

  static SocialAuthController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'AuthScope is missing');
    return controller!;
  }
}
