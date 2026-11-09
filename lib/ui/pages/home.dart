import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:animestream/core/app/logging.dart';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/commons/types.dart';
import 'package:animestream/core/data/watching.dart';
import 'package:animestream/core/database/anilist/types.dart';
import 'package:animestream/ui/models/providers/mainNavProvider.dart';
import 'package:animestream/ui/models/screenType.dart';
import 'package:animestream/ui/models/snackBar.dart';
import 'package:animestream/ui/models/widgets/cards.dart';
import 'package:animestream/ui/models/widgets/cards/animeCard.dart';
import 'package:animestream/ui/pages/downloads.dart';
import 'package:animestream/ui/pages/info.dart';
import 'package:animestream/ui/pages/lists.dart';
import 'package:animestream/ui/pages/settingPages/common.dart';
import 'package:animestream/ui/pages/settingPages/stats.dart';
import 'package:animestream/ui/pages/settings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animestream/core/database/tmdb/tmdb.dart';
import 'package:animestream/core/database/tmdb/tmdbTypes.dart';
import 'package:animestream/ui/models/widgets/cards/mediaCard.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class Home extends StatefulWidget {
  final MainNavProvider mainNavProvider;

  const Home({
    super.key,
    required this.mainNavProvider,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ScrollController _recentlyUpdatedScrollController = ScrollController();
  final ScrollController _recommendedScrollController = ScrollController();
  final ScrollController _trendingScrollController = ScrollController();

  final PageController _heroPageController = PageController();
  int _heroCurrentPage = 0;
  Timer? _heroTimer;

  int _selectedCategory = 0; // 0: All Anime, 1: Movies, 2: TV Series
  List<TMDBItem> _trendingMovies = [];
  List<TMDBItem> _popularMovies = [];
  List<TMDBItem> _trendingTV = [];
  List<TMDBItem> _popularTV = [];
  bool _loadingMedia = false;

  void _loadMediaData() async {
    if (_trendingMovies.isNotEmpty && _trendingTV.isNotEmpty) return;
    if (mounted) setState(() => _loadingMedia = true);
    final results = await Future.wait([
      TMDBService.getTrendingMovies(),
      TMDBService.getPopularMovies(),
      TMDBService.getTrendingTV(),
      TMDBService.getPopularTV(),
    ]);
    if (mounted) {
      setState(() {
        _trendingMovies = results[0];
        _popularMovies = results[1];
        _trendingTV = results[2];
        _popularTV = results[3];
        _loadingMedia = false;
      });
    }
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final trending = widget.mainNavProvider.trendingList;
      if (trending.isNotEmpty && _heroPageController.hasClients) {
        final total = trending.length.clamp(1, 10);
        _heroCurrentPage = (_heroCurrentPage + 1) % total;
        _heroPageController.animateToPage(
          _heroCurrentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.mainNavProvider.addListener(_onProviderUpdate);
    if (!widget.mainNavProvider.discoverDataLoaded) {
      widget.mainNavProvider.loadDiscoverItems().then((_) {
        if (mounted) setState(() {});
      });
    }
    _startHeroTimer();
    _loadMediaData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    widget.mainNavProvider.removeListener(_onProviderUpdate);
    _recentlyUpdatedScrollController.dispose();
    _recommendedScrollController.dispose();
    _trendingScrollController.dispose();
    super.dispose();
  }

  List<HomePageList> recentlyWatched = [];
  bool refreshing = false;

  Future<void> getLists({String? userName}) async {
    try {
      if (mounted) {
        setState(() {
          refreshing = true;
        });
      }
      List<UserAnimeListItem> watched = await getWatchedList(userName: userName);
      if (watched.length > 40) watched = watched.sublist(0, 40);
      recentlyWatched = [];
      for (final item in watched) {
        recentlyWatched.add(
          HomePageList(
            coverImage: item.coverImage,
            id: item.id,
            rating: item.rating,
            title: item.title,
            totalEpisodes: item.episodes,
            watchedEpisodeCount: item.watchProgress,
          ),
        );
      }

      widget.mainNavProvider.updateWatchedList(recentlyWatched);

      if (mounted) {
        setState(() {
          refreshing = false;
        });
      }
    } catch (err) {
      Logs.app.log(err.toString());
      if (currentUserSettings?.showErrors ?? false) floatingSnackBar(err.toString());
      if (mounted) {
        setState(() {
          refreshing = false;
        });
      }
    }
  }

  AnimeListData<HomePageList>? selectedList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      body: SmartRefresher(
        controller: widget.mainNavProvider.homeRefreshController = RefreshController(initialRefresh: false),
        onRefresh: () async {
          await widget.mainNavProvider.refresh(refreshPage: 0, fromSettings: false);
        },
        header: WaterDropMaterialHeader(
          backgroundColor: appTheme.backgroundSubColor,
          color: appTheme.accentColor,
        ),
        child: Container(
          padding: pagePadding(context).copyWith(left: 0, right: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Crunchyroll-style Top Hero Spotlight
                      _heroSpotlight(),

                      // Category Filter Tabs (Anime, Movies, TV Series)
                      _categoryFilterBar(),

                      if (_selectedCategory == 1) ...[
                        if (_loadingMedia)
                          Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(child: CircularProgressIndicator(color: appTheme.accentColor)),
                          )
                        else ...[
                          _mediaSection("Trending Movies", _trendingMovies),
                          divider(),
                          _mediaSection("Popular Blockbusters", _popularMovies),
                        ],
                      ] else if (_selectedCategory == 2) ...[
                        if (_loadingMedia)
                          Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(child: CircularProgressIndicator(color: appTheme.accentColor)),
                          )
                        else ...[
                          _mediaSection("Trending TV Series", _trendingTV),
                          divider(),
                          _mediaSection("Popular Shows", _popularTV),
                        ],
                      ] else ...[
                      // Logged-in user stats bar
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: storedUserData != null
                            ? Align(
                                alignment: Alignment.center,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  constraints: const BoxConstraints(maxWidth: 450),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _accountCard(),
                                      _listButton(),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),

                      // Continue Watching shelf (with 16:9 cards & orange progress bar)
                      if (widget.mainNavProvider.recentlyWatched.items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _titleAndList("Continue Watching", widget.mainNavProvider.recentlyWatched,
                            showRefreshIndication: refreshing),
                        divider(),
                      ],

                      // Trending This Season
                      if (widget.mainNavProvider.thisSeason.isNotEmpty) ...[
                        _animeSection(
                            "Trending This Season", widget.mainNavProvider.thisSeason, _trendingScrollController),
                        divider(),
                      ],

                      // Recently Updated Episodes
                      if (widget.mainNavProvider.recentlyUpdatedList.isNotEmpty) ...[
                        _animeSection("Recently Updated", widget.mainNavProvider.recentlyUpdatedList,
                            _recentlyUpdatedScrollController),
                        divider(),
                      ],

                      // Aired This Season
                      _titleAndList("Aired This Season", widget.mainNavProvider.currentlyAiring),

                      // Popular & Recommended
                      if (widget.mainNavProvider.recommendedList.isNotEmpty) ...[
                        divider(),
                        _animeSection("Popular & Recommended", widget.mainNavProvider.recommendedList,
                            _recommendedScrollController),
                      ],

                      // From Your Planned
                      if (widget.mainNavProvider.loggedIn) ...[
                        divider(),
                        _titleAndList("From Your Planned", widget.mainNavProvider.plannedList),
                      ],
                      ], // End of Anime category else block
                      footSpace(),
                    ],
                  ),
                ),
              ),
              if (selectedList != null)
                Expanded(
                  flex: selectedList == null ? 0 : 1,
                  child: _rightPanel(),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryFilterBar() {
    final categories = ["All Anime", "Movies", "TV Series"];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategory == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = index);
              if (index > 0 && (_trendingMovies.isEmpty || _trendingTV.isEmpty)) {
                _loadMediaData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? appTheme.accentColor : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? appTheme.accentColor : Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: appTheme.accentColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: isSelected ? appTheme.onAccent : appTheme.textMainColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: "NotoSans",
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mediaSection(String title, List<TMDBItem> list) {
    if (list.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: appTheme.textMainColor,
              fontFamily: "NotoSans",
            ),
          ),
        ),
        SizedBox(
          height: Platform.isWindows || Platform.isLinux ? 280 : 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              return MediaCard(item: list[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _heroSpotlight() {
    final trending = widget.mainNavProvider.trendingList;
    final double heroHeight = (Platform.isWindows || Platform.isLinux) ? 460.0 : 410.0;
    final topPadding = MediaQuery.of(context).padding.top;

    if (trending.isEmpty) {
      return Container(
        height: heroHeight,
        width: double.infinity,
        color: appTheme.backgroundColor,
        child: Stack(
          children: [
            _topFloatingBar(topPadding),
            Center(
              child: CircularProgressIndicator(
                color: appTheme.accentColor,
              ),
            ),
          ],
        ),
      );
    }

    final totalPages = trending.length.clamp(1, 10);

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _heroPageController,
            itemCount: totalPages,
            onPageChanged: (idx) {
              setState(() {
                _heroCurrentPage = idx;
              });
            },
            itemBuilder: (context, index) {
              final item = trending[index];
              final titles = item.title;
              final defaultTitle = titles['english'] ?? titles['romaji'] ?? titles['title'] ?? '';
              final preferNative = currentUserSettings?.nativeTitle ?? false;
              final title = preferNative ? titles['native'] ?? defaultTitle : defaultTitle;
              final rating = item.rating;

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Info(id: item.id),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full-bleed backdrop art
                    CachedNetworkImage(
                      imageUrl: item.banner ?? item.cover,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        color: appTheme.backgroundSubColor,
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        "lib/assets/images/chisato.jpeg",
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Top dark vignette for readable app bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Deep cinematic gradient fade into background
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 260,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.4, 0.75, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.8),
                              appTheme.backgroundColor,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom info overlay
                    Positioned(
                      bottom: 22,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Anime Title
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: "Rubik",
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Badges Row: Rating + Genre Tags
                          Row(
                            children: [
                              if (rating != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: appTheme.accentColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, color: appTheme.onAccent, size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        "${(rating / 10).toStringAsFixed(1)}",
                                        style: TextStyle(
                                          color: appTheme.onAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: item.genres.take(3).map((g) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          g.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: "NotoSans",
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Crunchyroll "START WATCHING" & "DETAILS" Buttons
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => Info(id: item.id),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: appTheme.onAccent,
                                  size: 24,
                                ),
                                label: Text(
                                  "START WATCHING",
                                  style: TextStyle(
                                    fontFamily: "NotoSans",
                                    color: appTheme.onAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appTheme.accentColor,
                                  elevation: 4,
                                  shadowColor: appTheme.accentColor.withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => Info(id: item.id),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: const Text(
                                  "DETAILS",
                                  style: TextStyle(
                                    fontFamily: "NotoSans",
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Floating Top App Bar over hero
          _topFloatingBar(topPadding),

          // Hero Page Indicator Dots
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (idx) {
                final isSelected = idx == _heroCurrentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: isSelected ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected ? appTheme.accentColor : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topFloatingBar(double topPadding) {
    return Positioned(
      top: topPadding + 6,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                "MOZZAI",
                style: TextStyle(
                  fontFamily: "Rubik",
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 3, top: 8),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appTheme.accentColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DownloadsPage()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      )
                          .then((_) {
                        getLists(userName: storedUserData?.name);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AnimatedContainer _rightPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: appTheme.backgroundSubColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(8),
      width: selectedList != null ? null : 0,
      child: selectedList == null
          ? Container()
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          selectedList = null;
                        });
                      },
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: appTheme.textMainColor,
                        size: 20,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        selectedList!.title ?? "Which list might this be?",
                        style: TextStyle(fontFamily: "Rubik", fontSize: 20, color: appTheme.textMainColor),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GridView.builder(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: Platform.isAndroid ? 140 : 180,
                        mainAxisExtent: Platform.isAndroid ? 220 : 265,
                        childAspectRatio: 120 / 220,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: selectedList!.items.length,
                      itemBuilder: (context, index) {
                        final item = selectedList!.items[index];
                        return Center(
                          child: Cards.animeCard(
                            item.id,
                            item.title['english'] ?? item.title['romaji'] ?? "",
                            item.coverImage,
                            rating: item.rating,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  SizedBox footSpace() {
    return SizedBox(
      height: MediaQuery.of(context).padding.bottom + 60,
    );
  }

  Widget _listButton() {
    return Expanded(
      flex: 4,
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(left: 10),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: appTheme.backgroundSubColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => const AnimeLists()))
              .then((val) => getLists(userName: storedUserData?.name)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_rounded,
                color: appTheme.textMainColor,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  "Lists",
                  style: TextStyle(
                    color: appTheme.textMainColor,
                    fontFamily: "Poppins",
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountCard() {
    return Expanded(
      flex: 6,
      child: Material(
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.hardEdge,
        color: appTheme.backgroundSubColor,
        child: InkWell(
          overlayColor: WidgetStatePropertyAll(appTheme.accentColor.withValues(alpha: 0.1)),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserStats(userModal: storedUserData!),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            height: 56,
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundImage: storedUserData!.avatar != null
                      ? NetworkImage(storedUserData!.avatar!)
                      : const AssetImage('lib/assets/images/chisato_AI.jpg') as ImageProvider,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    storedUserData!.name,
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: appTheme.textMainColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget divider() {
    return const SizedBox(height: 24);
  }

  Widget _animeSection(String title, List<AnimeCard> list, ScrollController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: "Rubik",
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: appTheme.textMainColor,
            ),
          ),
        ),
        SizedBox(
          height: (list.firstOrNull?.isMobile ?? true) ? 220 : 265,
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: list.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => list[index],
          ),
        ),
      ],
    );
  }

  Column _titleAndList(String title, AnimeListData<HomePageList> list, {bool showRefreshIndication = false}) {
    final bool isContinueWatching = title == "Continue Watching";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: "Rubik",
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: appTheme.textMainColor,
                ),
              ),
              if (showRefreshIndication)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                    color: appTheme.accentColor,
                    strokeWidth: 2,
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  if (context.screenType == ScreenType.expanded || context.screenType == ScreenType.large) {
                    setState(() {
                      selectedList = list;
                    });
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (context) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 12),
                            child: Text(
                              title,
                              style: textStyle(),
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: Platform.isAndroid ? 140 : 180,
                                mainAxisExtent: Platform.isAndroid ? 220 : 260,
                                childAspectRatio: 120 / 220,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: list.items.length,
                              itemBuilder: (context, index) {
                                final item = list.items[index];
                                return Center(
                                  child: Cards.animeCard(
                                    item.id,
                                    item.title['english'] ?? item.title['romaji'] ?? "",
                                    item.coverImage,
                                    rating: item.rating,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: isContinueWatching ? 185 : 160,
          child: list.state.isError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        "lib/assets/images/ghost.png",
                        color: const Color.fromARGB(255, 80, 80, 80),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10.0),
                        child: Text(
                          "Aww... Something's wrong!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "NunitoSans",
                            fontWeight: FontWeight.w500,
                            color: Color.fromARGB(255, 80, 80, 80),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : list.state.isLoaded
                  ? list.items.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          scrollDirection: Axis.horizontal,
                          itemCount: list.items.length,
                          itemBuilder: (context, index) {
                            final item = list.items[index];
                            final preferNative = currentUserSettings?.nativeTitle ?? false;
                            final normalTitle =
                                item.title['english'] ?? item.title['romaji'] ?? item.title['title'] ?? '';
                            final title = preferNative ? item.title['native'] ?? normalTitle : normalTitle;
                            return Cards.animeCardExtended(
                              item.id,
                              title,
                              item.coverImage,
                              item.rating ?? 0.0,
                              bannerImageUrl: item.coverImage,
                              watchedEpisodeCount: item.watchedEpisodeCount,
                              totalEpisodes: item.totalEpisodes,
                              afterNavigation: () => getLists(userName: storedUserData?.name),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                "lib/assets/images/ghost.png",
                                color: const Color.fromARGB(255, 80, 80, 80),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 10.0),
                                child: Text(
                                  "Boo! Nothing's here!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: "NunitoSans",
                                    fontWeight: FontWeight.w500,
                                    color: Color.fromARGB(255, 80, 80, 80),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                  : Center(
                      child: CircularProgressIndicator(
                        color: appTheme.accentColor,
                      ),
                    ),
        ),
      ],
    );
  }
}
