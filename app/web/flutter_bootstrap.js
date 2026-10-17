{{flutter_js}}
{{flutter_build_config}}

// UX review builds always load the current application. Offline demo content
// lives in the native bundle / explicit pack storage, not a stale web cache.
_flutter.loader.load();
