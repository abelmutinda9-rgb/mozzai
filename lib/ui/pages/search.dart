import 'dart:async';
import 'dart:io';

import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/data/preferences.dart';
import 'package:animestream/core/data/types.dart';
import 'package:animestream/core/database/handler/handler.dart';
import 'package:animestream/core/database/types.dart';
import 'package:animestream/ui/models/widgets/cards.dart';
import 'package:animestream/ui/models/widgets/cards/animeCardExtended.dart';
import 'package:animestream/ui/models/widgets/header.dart';
import 'package:animestream/ui/pages/settingPages/common.dart';
import 'package:animestream/core/database/tmdb/tmdb.dart';
import 'package:animestream/core/database/tmdb/tmdbTypes.dart';
import 'package:animestream/ui/models/widgets/cards/mediaCard.dart';
import 'package:flutter/material.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  List<DatabaseSearchResult> results = [];
  List<DatabaseSearchResult> exactMatches = [];

  TextEditingController textEditingController = TextEditingController();

  bool _searching = false;

  Timer? debounce;

  final db = DatabaseHandler();

  int searchMode = 0; // 0: Anime, 1: Movies & Series
  List<TMDBItem> tmdbResults = [];

  Future searchTMDB(String query) async {
    tmdbResults = [];
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searching = false);
      return;
    }
    final items = await TMDBService.searchMulti(query);
    if (mounted) {
      setState(() {
        tmdbResults = items;
        _searching = false;
      });
    }
  }

  void _triggerSearch(String val) async {
    if (val.trim().length <= 1) return;
    setState(() => _searching = true);
    if (searchMode == 1) {
      await searchTMDB(val);
    } else {
      await addCards(val);
    }
  }

  Future addCards(String query) async {
    results = []; //for cleaning the UI
    exactMatches = [];
    final searchResults = await db.search(query);
    results = []; //for removing the data from previous search invokation due to debouncing
    exactMatches = [];
    if (searchResults.length == 0)
      return setState(() {
        _searching = false;
      });
    searchResults.forEach((ele) {
      final String title = ele.title['english'] ?? ele.title['romaji'] ?? '';
      results.add(ele);
      if (query.toLowerCase() == title.toLowerCase()) {
        exactMatches.add(ele);
      }
    });
    setState(() {
      _searching = false;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  bool exactMatch = false;
  bool verticalCards = userPreferences?.searchPageListMode ?? false;
  final nativeTitle = currentUserSettings?.nativeTitle ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Padding(
          padding: pagePadding(context).copyWith(left: 0),
          child: Column(
            children: [
              buildHeader("Search", context, afterNavigation: () => setState(() {})),
              Container(
                padding: EdgeInsets.only(top: 15, left: 25, right: 25, bottom: 10),
                child: Column(
                  children: [
                    _searchBar(),
                    _searchOptions(),
                  ],
                ),
              ),
              Expanded(
                child: _searching
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: appTheme.accentColor,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "searching...",
                              style: TextStyle(
                                  color: appTheme.accentColor,
                                  fontFamily: "NotoSans",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          )
                        ],
                      )
                    : _searchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SizedBox footSpace() {
    return SizedBox(
      height: MediaQuery.of(context).padding.bottom + 60,
    );
  }

  Widget _modeButton(int mode, String label) {
    final isSel = searchMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => searchMode = mode);
        if (textEditingController.text.trim().length > 1) {
          _triggerSearch(textEditingController.text);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? appTheme.accentColor : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? appTheme.accentColor : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? appTheme.onAccent : appTheme.textMainColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            fontFamily: "NotoSans",
          ),
        ),
      ),
    );
  }

  Container _searchOptions() {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _modeButton(0, "Anime"),
              const SizedBox(width: 8),
              _modeButton(1, "Movies & Series"),
            ],
          ),
          const SizedBox(height: 6),
          Row(
        children: [
          Checkbox(
            value: exactMatch,
            onChanged: (val) => setState(() {
              exactMatch = val!;
            }),
            activeColor: appTheme.accentColor,
            checkColor: Colors.black,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            "exact match",
            style: TextStyle(
              color: appTheme.textMainColor,
              fontFamily: "NotoSans",
              fontWeight: FontWeight.bold,
            ),
          ),
          Checkbox(
            value: verticalCards,
            onChanged: (val) => setState(() {
              verticalCards = val!;
              UserPreferences.saveUserPreferences(UserPreferencesModal(searchPageListMode: val));
            }),
            activeColor: appTheme.accentColor,
            checkColor: Colors.black,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            "list view",
            style: TextStyle(
              color: appTheme.textMainColor,
              fontFamily: "NotoSans",
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      ],
      ),
    );
  }

  Container _searchResults() {
    if (searchMode == 1) {
      if (tmdbResults.isEmpty) {
        if (textEditingController.text.length > 2) {
          return Center(
            child: Text(
              "No movies or TV shows found",
              style: TextStyle(color: appTheme.textSubColor, fontFamily: "NotoSans"),
            ),
          );
        }
        return Container();
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: Platform.isAndroid ? 230 : 270,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 15,
                ),
                itemCount: tmdbResults.length,
                itemBuilder: (context, index) {
                  return MediaCard(item: tmdbResults[index]);
                },
              ),
              footSpace(),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.only(left: 15, right: 15),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: verticalCards ? 450 : 180,
                  mainAxisExtent: verticalCards
                      ? 150
                      : Platform.isAndroid
                          ? 220
                          : 265,
                  crossAxisSpacing: verticalCards ? 10 : 0,
                  // crossAxisCount: MediaQuery.of(context).orientation == Orientation.portrait ? 3 : 6,
                  // childAspectRatio: 1 / 1.88,
                  // childAspectRatio: 120 / 220, //set as width and height of each child container
                  mainAxisSpacing: 15),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: exactMatch ? exactMatches.length : results.length,
              itemBuilder: (context, index) {
                if (verticalCards) {
                  final it = results[index];
                  final image = it.cover;
                  final String title = it.title['english'] ?? it.title['romaji'] ?? '';
                  final id = it.id;
                  return AnimeCardExtended(
                    id: id,
                    title: nativeTitle ? it.title['native'] ?? title : title,
                    imageUrl: image,
                    rating: it.rating ?? 0,
                    customWidth: 450,
                    totalEpisodes: it.totalEpisodes,
                    surfaceColor: appTheme.backgroundSubColor.withAlpha(100),
                  );
                } else {
                  final it = exactMatch ? exactMatches[index] : results[index];
                  final image = it.cover;
                  final String title = it.title['english'] ?? it.title['romaji'] ?? '';
                  final id = it.id;
                  return Container(
                    child: Cards.animeCard(id, nativeTitle ? it.title['native'] ?? title : title, image,
                        rating: it.rating, isAnime: true, isMobile: Platform.isAndroid),
                  );
                }
              },
            ),
            footSpace(),
          ],
        ),
      ),
    );
  }

  TextField _searchBar() {
    return TextField(
      controller: textEditingController,
      onChanged: (val) {
        if (debounce?.isActive ?? false) debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 400), () async {
          if (val.trim().length <= 2) {
            return;
          }
          setState(() {
            _searching = true;
          });
          _triggerSearch(val);
        });
      },
      onSubmitted: (val) async {
        if (debounce?.isActive ?? false) debounce?.cancel();
        if (val.trim().length <= 2) {
          return;
        }
        setState(() {
          _searching = true;
        });
        _triggerSearch(val);
      },
      autocorrect: false,
      cursorColor: appTheme.accentColor,
      decoration: InputDecoration(
        labelText: "search",
        labelStyle:
            TextStyle(color: appTheme.textMainColor, fontFamily: "Rubik", fontWeight: FontWeight.bold, fontSize: 17),
        suffixIcon: Padding(
          padding: EdgeInsets.only(right: 10),
          child: Image.asset(
            'lib/assets/images/search.png',
            color: appTheme.textMainColor,
            scale: 1.75,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50.0),
          borderSide: BorderSide(width: 1.5, color: appTheme.textMainColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50.0),
          borderSide: BorderSide(color: appTheme.accentColor),
        ),
        hintText: "Search...",
        hintStyle: TextStyle(fontFamily: "Poppins", color: Color.fromARGB(255, 168, 168, 168)),
        contentPadding: EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 15),
      ),
      style: TextStyle(color: appTheme.textMainColor, fontFamily: "Poppins"),
    );
  }

  @override
  void dispose() {
    textEditingController.dispose();
    debounce?.cancel();
    super.dispose();
  }
}
