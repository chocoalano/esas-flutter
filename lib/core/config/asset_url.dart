import 'env.dart';

/// Resolve [path] against the asset CDN.
///
/// A value that is already absolute is returned unchanged, so a payload that
/// starts serving full URLs needs no client change. Was `imageUrl()` in
/// `utils/helper.dart`, where the CDN origin came from a second hardcoded
/// constant (`utils/api_constants.dart`) rather than from [Env].
String assetUrl(String path) {
  if (path.startsWith('http')) return path;

  final origin = Env.assetBaseUrl.endsWith('/')
      ? Env.assetBaseUrl.substring(0, Env.assetBaseUrl.length - 1)
      : Env.assetBaseUrl;
  final relative = path.startsWith('/') ? path.substring(1) : path;

  return '$origin/$relative';
}
