import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../data/featured_programs.dart';
import 'featured_visuals.dart';

/// A wide, artwork-led card used by the Home featured rail.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({
    super.key,
    required this.item,
    required this.now,
    required this.onTap,
  });

  static const double width = 160;
  static const double height = 96;

  static const double desktopWidth = 280;
  static const double desktopHeight = 160;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConfig.desktopBreakpoint;

  static double widthFor(BuildContext context) =>
      isDesktop(context) ? desktopWidth : width;

  static double heightFor(BuildContext context) =>
      isDesktop(context) ? desktopHeight : height;

  final FeaturedProgramme item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final programme = item.programme;
    final live = programme.isLiveAt(now);

    final cardWidth = FeaturedCard.widthFor(context);
    final cardHeight = FeaturedCard.heightFor(context);

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ProgrammeBackdrop(
                programme: programme,
                channel: item.channel,
                kind: item.kind,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD9000000)],
                    stops: [0.32, 1],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: FeaturedKindBadge(kind: item.kind),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: FeaturedStatusChip(
                  label: featuredStartLabel(programme, now),
                  live: live,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programme.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _ChannelLogo(logo: item.channel.logo),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${item.channel.name}  ·  ${featuredTimeRange(programme)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xCCFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.logo});

  final String? logo;

  @override
  Widget build(BuildContext context) {
    final value = logo?.trim();
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CachedNetworkImage(
        imageUrl: value,
        width: 14,
        height: 14,
        fit: BoxFit.contain,
        memCacheWidth: 28,
        imageRenderMethodForWeb: kIsWeb
            ? ImageRenderMethodForWeb.HtmlImage
            : ImageRenderMethodForWeb.HtmlImage,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}
