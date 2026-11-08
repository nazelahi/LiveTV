import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../data/models/playlist_state.dart';
import '../providers/deep_link_provider.dart';
import '../providers/playlist_providers.dart';
import 'root_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  final ValueNotifier<String> _status = ValueNotifier<String>('Starting…');

  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _progress.dispose();
    _status.dispose();
    super.dispose();
  }

  /// Smoothly move the bar toward [target]. The animation runs on the UI
  /// thread, so the bar glides instead of jumping between milestones.
  Future<void> _setProgress(double target, {Duration duration = const Duration(milliseconds: 450)}) async {
    await _progress.animateTo(
      target.clamp(0.0, 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _run() async {
    final started = DateTime.now();
    try {
      _status.value = 'Preparing storage…';
      await _setProgress(0.12);
      await _setProgress(0.28);

      _status.value = 'Starting media engine…';
      await _setProgress(0.40);

      _status.value = 'Loading LiveTV…';
      // Animate toward 0.85 while the (possibly slow) fetch is in flight, so
      // the bar keeps moving instead of freezing.
      unawaited(
        _progress.animateTo(
          0.85,
          duration: const Duration(seconds: 4),
          curve: Curves.easeOut,
        ),
      );

      PlaylistState? result;
      try {
        result = await ref.read(playlistProvider.future).timeout(
              const Duration(seconds: 8),
            );

      } on TimeoutException {
        result = ref.read(playlistProvider).valueOrNull;
      }

      // Stop the creep animation and settle on the real value.
      if (_progress.isAnimating) _progress.stop();
      await _setProgress(result == null ? 0.85 : 0.95);

      _status.value = 'Ready';
      await _setProgress(1.0, duration: const Duration(milliseconds: 300));

      // Keep the splash visible briefly so it never flashes on fast devices,
      // but skip the wait when the playlist came from cache (instant load).
      final elapsed = DateTime.now().difference(started);
      final cached = result?.fromCache ?? false;
      const minDisplay = Duration(milliseconds: 400);
      if (!cached && elapsed < minDisplay) {
        await Future.delayed(minDisplay - elapsed);
      }

      if (!mounted) return;

      // Deep link: capture a channel id from the URL hash on web.
      if (kIsWeb) {
        final fragment = Uri.base.fragment;
        final match = RegExp(r'^/?watch/(.+)$').firstMatch(fragment);
        if (match != null) {
          ref.read(pendingDeepLinkProvider.notifier).state =
              Uri.decodeComponent(match.group(1)!);
        }
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const RootScreen()),
      );
    } catch (error) {
      if (_progress.isAnimating) _progress.stop();
      if (!mounted) return;
      setState(() {
        _failed = true;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _failed = false;
      _errorMessage = null;
    });
    _progress.value = 0;
    _status.value = 'Starting…';
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.appName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live channels, instantly',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_failed) ...[
                    Text(
                      _errorMessage ?? 'Something went wrong',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.danger,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ] else ...[
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progress.value.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor:
                                AppTheme.textSecondary.withValues(alpha: 0.18),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accent,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<String>(
                      valueListenable: _status,
                      builder: (context, value, _) {
                        return Text(
                          value,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
