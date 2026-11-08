import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a channel id parsed from the URL hash on web, to be consumed after
/// the playlist has loaded.
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);