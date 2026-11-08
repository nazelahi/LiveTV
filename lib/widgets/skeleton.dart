import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A single shared animation clock for every [Shimmer] in its subtree, so the
/// grid skeleton, list skeleton and all logo placeholders animate from one
/// ticker instead of one per surface (which caused jank on mobile).
class ShimmerScope extends StatefulWidget {
  const ShimmerScope({super.key, required this.child});

  final Widget child;

  static Animation<double>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScopeInherited>()
        ?.animation;
  }

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      // Rebuild so dependents (Shimmer) pick up the new reduce-motion state.
      if (mounted) setState(() {});
    }
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScopeInherited(
      animation: _controller,
      reduceMotion: _reduceMotion,
      child: widget.child,
    );
  }
}

class _ShimmerScopeInherited extends InheritedWidget {
  const _ShimmerScopeInherited({
    required this.animation,
    required this.reduceMotion,
    required super.child,
  });

  final Animation<double> animation;
  final bool reduceMotion;

  @override
  bool updateShouldNotify(_ShimmerScopeInherited oldWidget) =>
      animation != oldWidget.animation ||
      reduceMotion != oldWidget.reduceMotion;
}

/// Sweeps a soft highlight across [child]. Uses the nearest [ShimmerScope]'s
/// shared clock when available, otherwise creates its own controller.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  AnimationController? _ownController;

  AnimationController get _controller {
    final shared = ShimmerScope.of(context);
    if (shared is AnimationController) return shared;
    return _ownController ??= AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  bool get _usesShared => ShimmerScope.of(context) is AnimationController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usesShared) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _ownController?.stop();
    } else if (_ownController != null && !_ownController!.isAnimating) {
      _ownController!.repeat();
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;

    final controller = _controller;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: controller,
        child: widget.child,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                stops: const [0.25, 0.5, 0.75],
                transform: _SlidingGradientTransform(
                  controller.value * 2 - 1,
                ),
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * slidePercent,
      bounds.height * slidePercent,
      0,
    );
  }
}

/// A plain rounded placeholder shape. Wrap a group of these in one [Shimmer]
/// so they sweep together.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
    );
  }
}

/// Loading placeholder for the channel grid. Mirrors [ChannelGrid]'s delegate,
/// padding and default card layout.
class ChannelGridSkeleton extends StatelessWidget {
  const ChannelGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 80),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 96,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.78,
        ),
        itemCount: 30,
        itemBuilder: (context, index) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: const Column(
        children: [
          AspectRatio(
            aspectRatio: 2,
            child: SkeletonBox(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
          SizedBox(height: 3),
          _SkeletonLine(
            width: 44,
            fontSize: 9.5,
            height: 1.0,
            fontWeight: FontWeight.w600,
            lines: 2,
          ),
          SizedBox(height: 1),
          _SkeletonLine(width: 28, fontSize: 7.5),
        ],
      ),
    );
  }
}

/// Loading placeholder for the channel list. Mirrors [ChannelList]'s padding,
/// separators and tile layout.
class ChannelListSkeleton extends StatelessWidget {
  const ChannelListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 80),
        itemCount: 12,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) => const _SkeletonTile(),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 40, height: 40),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(
                  width: 120,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(height: 2),
                _SkeletonLine(width: 64, fontSize: 11),
              ],
            ),
          ),
          SizedBox(width: 4),
          SkeletonBox(
            width: 22,
            height: 22,
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
        ],
      ),
    );
  }
}

/// A shimmering bar that reserves exactly the height of [lines] lines of real
/// text. A transparent [Text] with the same style does the measuring, so the
/// skeleton follows the app's font metrics and text scale automatically.
class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.fontSize,
    this.height,
    this.fontWeight = FontWeight.normal,
    this.lines = 1,
  });

  final double width;
  final double fontSize;
  final double? height;
  final FontWeight fontWeight;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Opacity(
              opacity: 0,
              child: Text(
                List.filled(lines, 'M').join('\n'),
                maxLines: lines,
                style: TextStyle(
                  fontSize: fontSize,
                  height: height,
                  fontWeight: fontWeight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SkeletonBox(borderRadius: BorderRadius.circular(3)),
          ),
        ],
      ),
    );
  }
}

/// A single skeleton box with its own shimmer sweep.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.borderRadius});

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SkeletonBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
      ),
    );
  }
}
