import 'package:animestream/ui/theme/types.dart';
import 'package:flutter/material.dart';

/// The default Crunchyroll-inspired theme
class LimeZest implements ThemeItem {
  @override
  int get id => 01;

  @override
  String get name => "Crunchy Orange";

  @override
  bool get dev => false;

  @override
  AnimeStreamTheme get lightVariant => AnimeStreamTheme(
        accentColor: const Color(0xffF47521),
        backgroundColor: const Color(0xffF8F9FA),
        textMainColor: const Color(0xff141519),
        textSubColor: const Color(0xff707278),
        modalSheetBackgroundColor: Colors.white,
        backgroundSubColor: const Color(0xffE5E7EB),
        onAccent: Colors.white,
      );

  @override
  AnimeStreamTheme get theme => AnimeStreamTheme(
        accentColor: const Color(0xffF47521),
        backgroundColor: const Color(0xff0D0E12),
        backgroundSubColor: const Color(0xff1D1F26),
        textMainColor: const Color(0xffFFFFFF),
        textSubColor: const Color(0xffA0A2A8),
        modalSheetBackgroundColor: const Color(0xff141519),
        onAccent: Colors.black,
      );
}
