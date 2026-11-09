import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/sync_url_stub.dart'
    if (dart.library.html) '../core/sync_url_web.dart';
import '../providers/deep_link_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_providers.dart';
import '../widgets/glass.dart';
import '../widgets/skeleton.dart';
import 'desktop_shell.dart';
import 'favorites_screen.dart';
import 'featured_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'watch_screen.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  int _index = 0;

  // Tracks whether the layout is currently in the wide (desktop) mode, with a
  // small hysteresis band so dragging the window across the breakpoint does not
  // flicker between mobile and desktop.
  bool? _wasWide;
  bool _handlingResize = false;
  // The WatchScreen route we pushed during a desktop->mobile transition, if any.
  // Tracked so we never push a duplicate on top of an already-active player.
  Route<dynamic>? _watchRoute;

  static const List<Widget> _pages = [
    HomeScreen(),
    FavoritesScreen(),
    FeaturedScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeDeepLink());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RootScreen is web-only, but keep this safe on every platform.
    final width = MediaQuery.sizeOf(context).width;
    final isWide = _isWideFor(width);
    if (_wasWide == null) {
      _wasWide = isWide;
      return;
    }
    if (isWide == _wasWide) return;
    _wasWide = isWide;

    if (_handlingResize) return;
    final session = ref.read(playerProvider);
    if (session == null) return;

    _handlingResize = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _handlingResize = false;
        return;
      }
      final currentWidth = MediaQuery.sizeOf(context).width;
      final currentWide = _isWideFor(currentWidth);
      if (currentWide != isWide) {
        _handlingResize = false;
        return;
      }
      try {
        if (currentWide) {
          // Mobile -> desktop: the pushed WatchScreen (if any) pops itself when
          // it detects the wide viewport, so there is nothing to do here beyond
          // clearing our tracked route.
          _watchRoute = null;
        } else {
          // Desktop -> mobile: open the mobile player for the active session,
          // unless one is already on the stack.
          if (_watchRoute?.isActive == true) {
            _handlingResize = false;
            return;
          }
          final queue = session.queue;
          if (queue.isEmpty) {
            _handlingResize = false;
            return;
          }
          final index = session.index.clamp(0, queue.length - 1);
          final route = MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'responsive_watch_player'),
            builder: (_) => WatchScreen(queue: queue, initialIndex: index),
          );
          _watchRoute = route;
          unawaited(Navigator.of(context).push(route).then((_) {
            if (_watchRoute == route) _watchRoute = null;
          }));
        }
      } catch (_) {
        // Ignore navigation errors during resize transitions.
      } finally {
        _handlingResize = false;
      }
    });
  }

  bool _isWideFor(double width) {
    return width >= AppConfig.desktopBreakpoint;
  }

  Future<void> _consumeDeepLink() async {
    if (!kIsWeb) return;
    var id = ref.read(pendingDeepLinkProvider);
    // On web there is no splash screen to capture the URL hash, so parse it
    // here as well.
    if (id == null) {
      final fragment = Uri.base.fragment;
      final match = RegExp(r'^/?watch/(.+)$').firstMatch(fragment);
      if (match != null) {
        id = Uri.decodeComponent(match.group(1)!);
      }
    }
    if (id == null) return;
    ref.read(pendingDeepLinkProvider.notifier).state = null;

    // Wait for the playlist to load.
    for (int i = 0; i < 50; i++) {
      final state = ref.read(playlistProvider).valueOrNull;
      if (state != null) {
        final idx = state.channels.indexWhere((c) => c.id == id);
        if (idx >= 0 && mounted) {
          if (MediaQuery.sizeOf(context).width >= AppConfig.desktopBreakpoint) {
            ref.read(playerProvider.notifier).play(
                  state.channels[idx],
                  state.channels,
                  idx,
                );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WatchScreen(
                  queue: state.channels,
                  initialIndex: idx,
                ),
              ),
            );
          }
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProvider, (previous, next) {
      if (next == null) {
        _watchRoute = null;
      }
    });

    // Keep the browser URL in sync with the playing channel on web so that
    // refresh/share/deep-link all land on the right channel.
    if (kIsWeb) {
      ref.listen(playerProvider, (previous, next) {
        syncPlaybackUrl(next?.channel.id);
      });
    }

    if (MediaQuery.sizeOf(context).width >= AppConfig.desktopBreakpoint) {
      return const DesktopShell();
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
            ),
          ),
          ShimmerScope(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: GlassContainer(
        blur: 18,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          backgroundColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.live_tv_outlined),
              selectedIcon: Icon(Icons.live_tv_rounded),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Favourites',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Featured',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
