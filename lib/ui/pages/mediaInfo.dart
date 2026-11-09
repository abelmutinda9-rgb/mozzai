import 'dart:io';
import 'dart:ui';
import 'package:animestream/core/anime/downloader/downloadManager.dart';
import 'package:animestream/core/anime/providers/types.dart';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/database/tmdb/tmdb.dart';
import 'package:animestream/core/database/tmdb/tmdbTypes.dart';
import 'package:animestream/core/media/mediaStreamResolver.dart';
import 'package:animestream/ui/models/playerControllers/betterPlayer.dart';
import 'package:animestream/ui/models/playerControllers/fvp.dart';
import 'package:animestream/ui/models/providers/playerDataProvider.dart';
import 'package:animestream/ui/models/providers/playerProvider.dart';
import 'package:animestream/ui/models/snackBar.dart';
import 'package:animestream/ui/pages/watch.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaInfo extends StatefulWidget {
  final TMDBItem item;

  const MediaInfo({super.key, required this.item});

  @override
  State<MediaInfo> createState() => _MediaInfoState();
}

class _MediaInfoState extends State<MediaInfo> {
  int _selectedSeason = 1;
  int _totalSeasons = 1;
  List<TMDBEpisode> _episodes = [];
  bool _loadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    if (!widget.item.isMovie) {
      _loadSeasonData();
    }
  }

  Future<void> _loadSeasonData() async {
    final count = await TMDBService.getTVSeasonCount(widget.item.id);
    if (mounted) {
      setState(() => _totalSeasons = count > 0 ? count : 1);
    }
    _loadEpisodesForSeason(_selectedSeason);
  }

  Future<void> _loadEpisodesForSeason(int season) async {
    setState(() => _loadingEpisodes = true);
    final eps = await TMDBService.getTVSeasonEpisodes(widget.item.id, season);
    if (mounted) {
      setState(() {
        _episodes = eps;
        _loadingEpisodes = false;
      });
    }
  }

  void _openWebStream(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      floatingSnackBar("Could not open web player: $e");
    }
  }

  void _playInNativePlayer({
    required List<MediaStreamSource> sources,
    required int initialIndex,
    required String title,
    required int episodeIndex,
    required List<EpisodeDetails> epLinks,
  }) {
    try {
      final videoStreams = MediaStreamResolver.convertToVideoStreams(sources);
      final controller = Platform.isAndroid ? BetterPlayerWrapper() : FvpWrapper();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (context) => PlayerDataProvider(
                  initialStreams: videoStreams,
                  initialStream: videoStreams[initialIndex],
                  epLinks: epLinks,
                  showTitle: title,
                  coverImageUrl: widget.item.posterUrl.isNotEmpty ? widget.item.posterUrl : widget.item.backdropUrl,
                  showId: widget.item.id,
                  selectedSource: 'tmdb_media',
                  startIndex: episodeIndex,
                  altDatabases: [],
                  lastWatchDuration: null,
                ),
              ),
              ChangeNotifierProvider(
                create: (context) => PlayerProvider(controller, true),
              ),
            ],
            child: Watch(
              controller: controller,
            ),
          ),
        ),
      );
    } catch (e) {
      floatingSnackBar("Error launching native player: $e");
    }
  }

  void _startDownload({
    required String streamUrl,
    required String fileName,
    Map<String, String>? headers,
  }) async {
    try {
      await DownloadManager().addDownloadTask(
        streamUrl,
        fileName,
        customHeaders: headers ?? const {},
      );
      floatingSnackBar("Queued download: $fileName");
    } catch (e) {
      floatingSnackBar("Download error: $e");
    }
  }

  List<EpisodeDetails> _generateEpisodeDetailsList(int season) {
    if (widget.item.isMovie) {
      return [
        EpisodeDetails(
          episodeLink: widget.item.id.toString(),
          episodeNumber: 1,
          episodeTitle: widget.item.title,
          thumbnail: widget.item.backdropUrl.isNotEmpty ? widget.item.backdropUrl : widget.item.posterUrl,
          description: widget.item.overview,
        )
      ];
    }

    if (_episodes.isNotEmpty) {
      return _episodes
          .map((ep) => EpisodeDetails(
                episodeLink: "${widget.item.id}+${ep.seasonNumber}+${ep.episodeNumber}",
                episodeNumber: ep.episodeNumber,
                episodeTitle: ep.name,
                thumbnail: ep.stillUrl,
                description: ep.overview,
              ))
          .toList();
    }

    return [
      EpisodeDetails(
        episodeLink: "${widget.item.id}+$season+1",
        episodeNumber: 1,
        episodeTitle: "Episode 1",
      )
    ];
  }

  void _showServerSheet({int season = 1, int episode = 1, bool isDownload = false}) {
    final isMovie = widget.item.isMovie;
    final sources = isMovie
        ? MediaStreamResolver.getMovieStreams(widget.item.id)
        : MediaStreamResolver.getTVStreams(widget.item.id, season, episode);

    final epTitle = isMovie ? widget.item.title : "${widget.item.title} S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}";
    final epLinks = _generateEpisodeDetailsList(season);
    final epIdx = (episode - 1).clamp(0, epLinks.length - 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: appTheme.modalSheetBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isDownload
                            ? "Download: $epTitle"
                            : (isMovie ? "Watch: ${widget.item.title}" : "Play: $epTitle"),
                        style: TextStyle(
                          color: appTheme.textMainColor,
                          fontFamily: "NotoSans",
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (!isDownload) ...[
                    // Primary Native Player Option
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: appTheme.accentColor.withValues(alpha: 0.15),
                        border: Border.all(color: appTheme.accentColor.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: appTheme.accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.play_arrow, color: appTheme.onAccent, size: 20),
                        ),
                        title: Text(
                          "Play in Native ExoPlayer",
                          style: TextStyle(
                            color: appTheme.textMainColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "Custom gestures, subtitles, and Android TV controls",
                          style: TextStyle(color: appTheme.textSubColor, fontSize: 11),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: appTheme.accentColor),
                        onTap: () {
                          Navigator.pop(context);
                          _playInNativePlayer(
                            sources: sources,
                            initialIndex: 0,
                            title: epTitle,
                            episodeIndex: epIdx,
                            epLinks: epLinks,
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Streaming Servers & Mirrors:",
                        style: TextStyle(color: appTheme.textSubColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  ...sources.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return ListTile(
                      leading: Icon(
                        isDownload ? Icons.download_for_offline : Icons.cast_connected,
                        color: appTheme.accentColor,
                      ),
                      title: Text(
                        s.serverName,
                        style: TextStyle(color: appTheme.textMainColor, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        isDownload ? "Queue for offline playback" : "In-App Clean Player Mirror",
                        style: TextStyle(color: appTheme.textSubColor, fontSize: 11),
                      ),
                      trailing: Icon(
                        isDownload ? Icons.download_rounded : Icons.open_in_new,
                        size: 16,
                        color: appTheme.textSubColor,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (isDownload) {
                          _startDownload(
                            streamUrl: s.streamUrl,
                            fileName: epTitle,
                            headers: s.headers,
                          );
                        } else {
                          _openWebStream(s.embedUrl);
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero Backdrop with Parallax
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: appTheme.backgroundColor,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: appTheme.backgroundSubColor),
                        errorWidget: (context, url, error) => Container(color: appTheme.backgroundSubColor),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              appTheme.backgroundColor.withValues(alpha: 0.8),
                              appTheme.backgroundColor,
                            ],
                            stops: const [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: appTheme.accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.isMovie ? "MOVIE" : "TV SERIES",
                              style: TextStyle(
                                color: appTheme.onAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.releaseDate.isNotEmpty)
                            Text(
                              item.releaseDate.length >= 4 ? item.releaseDate.substring(0, 4) : item.releaseDate,
                              style: TextStyle(color: appTheme.textSubColor, fontSize: 13),
                            ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                "${item.rating} TMDB",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        item.title,
                        style: TextStyle(
                          color: appTheme.textMainColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: "NotoSans",
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons for Movie
                      if (item.isMovie) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appTheme.accentColor,
                                  foregroundColor: appTheme.onAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text(
                                  "Watch Movie",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                onPressed: () => _showServerSheet(isDownload: false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text("Download"),
                              onPressed: () => _showServerSheet(isDownload: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Overview
                      if (item.overview.isNotEmpty) ...[
                        Text(
                          "Synopsis",
                          style: TextStyle(
                            color: appTheme.textMainColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.overview,
                          style: TextStyle(
                            color: appTheme.textSubColor,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // TV Series Seasons & Episodes
                      if (!item.isMovie) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Episodes",
                              style: TextStyle(
                                color: appTheme.textMainColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_totalSeasons > 1)
                              DropdownButton<int>(
                                value: _selectedSeason,
                                dropdownColor: appTheme.backgroundSubColor,
                                style: TextStyle(color: appTheme.accentColor, fontWeight: FontWeight.bold),
                                underline: const SizedBox(),
                                items: List.generate(
                                  _totalSeasons,
                                  (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text("Season ${i + 1}"),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedSeason = val);
                                    _loadEpisodesForSeason(val);
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_loadingEpisodes)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: CircularProgressIndicator(color: appTheme.accentColor),
                            ),
                          )
                        else if (_episodes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              "No episodes found for this season.",
                              style: TextStyle(color: appTheme.textSubColor),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _episodes.length,
                            separatorBuilder: (context, i) => const Divider(color: Colors.white12),
                            itemBuilder: (context, i) {
                              final ep = _episodes[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 80,
                                    height: 50,
                                    color: appTheme.backgroundSubColor,
                                    child: ep.stillUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: ep.stillUrl,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) =>
                                                const Icon(Icons.tv, color: Colors.white24),
                                          )
                                        : const Icon(Icons.tv, color: Colors.white24),
                                  ),
                                ),
                                title: Text(
                                  "E${ep.episodeNumber} • ${ep.name}",
                                  style: TextStyle(
                                    color: appTheme.textMainColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: ep.overview.isNotEmpty
                                    ? Text(
                                        ep.overview,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: appTheme.textSubColor, fontSize: 11),
                                      )
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.download_rounded, color: appTheme.textSubColor, size: 20),
                                      onPressed: () => _showServerSheet(
                                        season: ep.seasonNumber,
                                        episode: ep.episodeNumber,
                                        isDownload: true,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.play_circle_fill, color: appTheme.accentColor, size: 24),
                                      onPressed: () => _showServerSheet(
                                        season: ep.seasonNumber,
                                        episode: ep.episodeNumber,
                                        isDownload: false,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _showServerSheet(
                                  season: ep.seasonNumber,
                                  episode: ep.episodeNumber,
                                  isDownload: false,
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
