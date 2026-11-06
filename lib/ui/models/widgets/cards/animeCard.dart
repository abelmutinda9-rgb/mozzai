import 'dart:io';

import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/commons/enums.dart';
import 'package:animestream/core/database/handler/syncHandler.dart';
import 'package:animestream/ui/models/snackBar.dart';
import 'package:animestream/ui/models/widgets/ContextMenu.dart';
import 'package:animestream/ui/pages/info.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AnimeCard extends StatefulWidget {
  final int id;
  final String title;
  final String imageUrl;
  final bool ongoing;
  final bool shouldNavigate;
  final bool isAnime;
  final bool isMobile;
  final String? subText;
  final double? rating;
  final void Function()? afterNavigation;

  const AnimeCard({
    super.key,
    required this.id,
    required this.title,
    required this.afterNavigation,
    required this.imageUrl,
    this.isAnime = true,
    this.ongoing = false,
    this.rating = null,
    this.shouldNavigate = true,
    this.subText = null,
    this.isMobile = true,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool isFocused = false;
  double width = Platform.isWindows || Platform.isLinux ? 150 : 110;
  double height = Platform.isWindows || Platform.isLinux ? 210 : 160;

  void updateFocus(bool val) {
    if (mounted) {
      setState(() {
        isFocused = val;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (!widget.isAnime) return floatingSnackBar("Manga or Novels aren't supported");
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
              widget.afterNavigation?.call();
            });
          }
        },
        child: ContextMenu(
          menuItems: [
            ContextMenuItem(
              icon: Icons.movie_outlined,
              label: "Add to Watching",
              onClick: () {
                SyncHandler()
                    .mutateAnimeList(id: widget.id, status: MediaStatus.CURRENT)
                    .then((_) => floatingSnackBar("Added to watching!"));
              },
            ),
            ContextMenuItem(
              icon: Icons.calendar_today_outlined,
              label: "Add to Planned",
              onClick: () {
                SyncHandler()
                    .mutateAnimeList(id: widget.id, status: MediaStatus.PLANNING)
                    .then((_) => floatingSnackBar("Added to planned!"));
              },
            ),
            ContextMenuItem(
              icon: Icons.done,
              label: "Add to Completed",
              onClick: () {
                SyncHandler()
                    .mutateAnimeList(id: widget.id, status: MediaStatus.COMPLETED)
                    .then((_) => floatingSnackBar("Added to completed!"));
              },
            ),
          ],
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
                      imageUrl: widget.imageUrl,
                      fadeInDuration: const Duration(milliseconds: 200),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: appTheme.backgroundSubColor,
                        height: height,
                        width: width,
                      ),
                      errorWidget: (context, url, error) {
                        return Container(
                          color: appTheme.backgroundSubColor,
                          child: const Icon(Icons.broken_image, color: Colors.white24),
                        );
                      },
                    ),
                  ),
                  // SUB | DUB Badge (Crunchyroll style)
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
                      child: const Text(
                        "SUB | DUB",
                        style: TextStyle(
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
                          Icon(
                            Icons.star,
                            color: appTheme.onAccent,
                            size: 11,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "${widget.rating ?? '??'}",
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
                widget.title,
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
              if (widget.subText != null)
                Text(
                  widget.subText!,
                  style: TextStyle(fontFamily: "NunitoSans", color: appTheme.textSubColor, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
