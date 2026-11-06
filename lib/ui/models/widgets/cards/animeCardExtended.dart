import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/ui/models/snackBar.dart';
import 'package:animestream/ui/pages/info.dart';

class AnimeCardExtended extends StatefulWidget {
  final int id;
  final String title;
  final String imageUrl;
  final double rating;
  final bool shouldNavigate;
  final bool isAnime;
  final void Function()? afterNavigation;
  final int? watchedEpisodeCount;
  final int? totalEpisodes;
  final String? bannerImageUrl;
  final Color? surfaceColor;
  final double? customWidth;

  const AnimeCardExtended({
    super.key,
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.rating,
    this.shouldNavigate = true,
    this.isAnime = true,
    this.afterNavigation,
    this.watchedEpisodeCount,
    this.totalEpisodes,
    this.bannerImageUrl,
    this.customWidth,
    this.surfaceColor,
  });

  @override
  State<AnimeCardExtended> createState() => _AnimeCardExtendedState();
}

class _AnimeCardExtendedState extends State<AnimeCardExtended> {
  bool isFocused = false;

  void updateFocus(bool val) {
    if (mounted) {
      setState(() {
        isFocused = val;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = widget.customWidth ?? 280;
    final double progress = (widget.totalEpisodes != null &&
            widget.totalEpisodes! > 0 &&
            widget.watchedEpisodeCount != null)
        ? (widget.watchedEpisodeCount! / widget.totalEpisodes!).clamp(0.08, 1.0)
        : 0.55;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: widget.surfaceColor ?? appTheme.backgroundSubColor,
        border: Border.all(
          color: isFocused ? appTheme.accentColor : Colors.white.withValues(alpha: 0.08),
          width: isFocused ? 2 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: appTheme.accentColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onHover: updateFocus,
          onFocusChange: updateFocus,
          onTap: () async {
            if (!widget.isAnime) return floatingSnackBar("Mangas/Novels aren't supported");
            if (widget.shouldNavigate) {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => Info(
                    id: widget.id,
                  ),
                ),
              )
                  .then((val) {
                if (widget.afterNavigation != null) widget.afterNavigation?.call();
              });
            }
          },
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Thumbnail with Episode badge
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.bannerImageUrl ?? widget.imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (context, url) => Container(
                            color: appTheme.backgroundColor,
                          ),
                          errorWidget: (context, url, error) {
                            return Image.asset(
                              "lib/assets/images/broken_heart.png",
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                        // Dark gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        // Play button icon center
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: isFocused ? appTheme.accentColor : Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        // Episode badge on top-left
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white12, width: 0.5),
                            ),
                            child: Text(
                              "EPISODE ${widget.watchedEpisodeCount ?? 1}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: "NotoSans",
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Rating on top-right
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: appTheme.accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: appTheme.onAccent, size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  "${widget.rating}",
                                  style: TextStyle(
                                    color: appTheme.onAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Crunchyroll Orange Progress Bar along the bottom of the thumbnail
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3.5,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(appTheme.accentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Title & Episode details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: isFocused ? appTheme.accentColor : appTheme.textMainColor,
                            fontFamily: "NotoSans",
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Watched ${widget.watchedEpisodeCount ?? 0} of ${widget.totalEpisodes ?? '?'} eps",
                          style: TextStyle(
                            color: appTheme.textSubColor,
                            fontFamily: "NunitoSans",
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
