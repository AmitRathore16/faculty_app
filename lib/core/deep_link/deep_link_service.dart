import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> init({
    required void Function(Uri uri) onLink,
  }) async {
    // When app is terminated
    final Uri? initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      onLink(initialUri);
    }

    // When app is in background/foreground
    _sub = _appLinks.uriLinkStream.listen((uri) {
      onLink(uri);
    });
  }

  void dispose() => _sub?.cancel();
}
