/// The app uses hash URLs on web. Preserve a local route while startup widgets
/// load, rejecting external/authority-style fragments as route destinations.
String? webStartupLocation(Uri browserUri) {
  final fragment = browserUri.fragment;
  if (!fragment.startsWith('/') || fragment.startsWith('//')) return null;
  final route = Uri.tryParse(fragment);
  if (route == null || route.hasScheme || route.hasAuthority) return null;
  return route.toString();
}
