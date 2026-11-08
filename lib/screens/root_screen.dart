import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
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

  Future<void> _consumeDeepLink() async {
    if (!kIsWeb) return;
    final id = ref.read(pendingDeepLinkProvider);
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
