import 'dart:io';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/database/tmdb/tmdbTypes.dart';
import 'package:animestream/ui/pages/mediaInfo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MediaCard extends StatefulWidget {
  final TMDBItem item;
  final bool isMobile;

  const MediaCard({
    super.key,
    required this.item,
    this.isMobile = true,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool isFocused = false;
  double width = Platform.isWindows || Platform.isLinux ? 150 : 110;
  double height = Platform.isWindows || Platform.isLinux ? 210 : 160;

  void updateFocus(bool val) {
    if (mounted) setState(() => isFocused = val);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      width: widget.isMobile ? width : width + 5,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        onHover: updateFocus,
        onFocusChange: updateFocus,
        splashFactory: NoSplash.splashFactory,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaInfo(item: item),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.linear,
                  height: widget.isMobile
                      ? height
                      : isFocused
                          ? height * 1.03
                          : height,
                  width: widget.isMobile
                      ? width
                      : isFocused
                          ? width * 1.03
                          : width,
                  margin: EdgeInsets.only(bottom: 8, top: widget.isMobile ? 0 : 5),
                  decoration: BoxDecoration(
                    border: isFocused
                        ? Border.all(
                            color: appTheme.accentColor,
                            strokeAlign: BorderSide.strokeAlignOutside,
                            width: 2.5,
                          )
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 0.5,
                          ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: appTheme.accentColor.withValues(alpha: 0.4),
                              blurRadius: 14,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: CachedNetworkImage(
                    imageUrl: item.posterUrl,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: appTheme.backgroundSubColor,
                      height: height,
                      width: width,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: appTheme.backgroundSubColor,
                      child: const Icon(Icons.movie_creation_outlined, color: Colors.white24),
                    ),
                  ),
                ),
                // Media Type Badge (MOVIE / TV)
                Positioned(
                  top: widget.isMobile ? 5 : (isFocused ? 10 : 8),
                  left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12, width: 0.5),
                    ),
                    child: Text(
                      item.isMovie ? "MOVIE" : "SERIES",
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                // Rating Badge
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                      color: appTheme.accentColor,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: appTheme.onAccent, size: 11),
                        const SizedBox(width: 2),
                        Text(
                          "${item.rating}",
                          style: TextStyle(
                            fontSize: 11,
                            color: appTheme.onAccent,
                            fontFamily: "NotoSans",
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              item.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: "NotoSans",
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isFocused ? appTheme.accentColor : appTheme.textMainColor,
              ),
            ),
            if (item.releaseDate.isNotEmpty)
              Text(
                item.releaseDate.length >= 4 ? item.releaseDate.substring(0, 4) : item.releaseDate,
                style: TextStyle(fontFamily: "NunitoSans", color: appTheme.textSubColor, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}
