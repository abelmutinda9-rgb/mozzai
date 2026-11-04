import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/ui/pages/settingPages/account.dart';
import 'package:animestream/ui/pages/settingPages/appInfo.dart';
import 'package:animestream/ui/pages/settingPages/common.dart';
import 'package:animestream/ui/pages/settingPages/downloader.dart';
import 'package:animestream/ui/pages/settingPages/general.dart';
import 'package:animestream/ui/pages/settingPages/player.dart';
import 'package:animestream/ui/pages/settingPages/ui.dart';
import 'package:animestream/ui/pages/subscription/mozzai_subscription_page.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class SettingItem {
  final IconData icon;
  final String label;
  final Widget navigateTo;
  final String description;

  SettingItem({
    required this.icon,
    required this.label,
    required this.navigateTo,
    required this.description,
  });
}

class _SettingsPageState extends State<SettingsPage> {
  final List<SettingItem> settingItems = [
    SettingItem(
        icon: Icons.workspace_premium_rounded,
        label: "MOZZAI Premium",
        description: "M-Pesa KSh 70 / 30 Days (2-Day Trial)",
        navigateTo: const MozzaiSubscriptionPage()),
    SettingItem(
        icon: Icons.account_circle,
        label: "Account",
        description: "Personal stuff",
        navigateTo: AccountSetting()),
    SettingItem(
        icon: Icons.brush_rounded,
        label: "UI",
        description: "Colors n Visuals",
        navigateTo: ThemeSetting()),
    SettingItem(
        icon: Icons.play_circle_fill_rounded,
        label: "Player",
        description: "Tailor your playback",
        navigateTo: PlayerSetting()),
    SettingItem(
        label: "Downloader",
        description: "Configure your downloads",
        icon: Icons.download_rounded,
        navigateTo: DownloaderSettings()),
    SettingItem(
        icon: Icons.tune_rounded,
        label: "General",
        description: "Basic tweaks",
        navigateTo: GeneralSetting()),
    SettingItem(
        icon: Icons.info_outline_rounded,
        label: "App Info",
        description: "The App stuff",
        navigateTo: AppInfoSetting()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      appBar: settingPagesAppBar(context),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(left: MediaQuery.of(context).padding.left),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 40, left: 20, bottom: 40),
                child: Text(
                  "Settings",
                  style: TextStyle(
                      fontFamily: "Rubik",
                      fontSize: 40,
                      color: appTheme.textMainColor),
                ),
              ),
              ListView.builder(
                itemCount: settingItems.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final isPremiumItem = index == 0;
                  return Container(
                    padding: const EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 5),
                    child: Container(
                      decoration: BoxDecoration(
                          color: isPremiumItem
                              ? appTheme.accentColor.withOpacity(0.18)
                              : appTheme.backgroundSubColor,
                          border: isPremiumItem
                              ? Border.all(color: appTheme.accentColor, width: 1.5)
                              : null,
                          borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.hardEdge,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context)
                                .push(
                              PageRouteBuilder(
                                pageBuilder: (context, anim, anim2) {
                                  return settingItems[index].navigateTo;
                                },
                                transitionDuration: const Duration(milliseconds: 100),
                                reverseTransitionDuration: const Duration(milliseconds: 100),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            )
                                .then((val) {
                              if (mounted) setState(() {});
                            });
                          },
                          focusColor: appTheme.accentColor.withOpacity(0.3),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      settingItems[index].icon,
                                      color: isPremiumItem ? Colors.amber : appTheme.textMainColor,
                                      size: 35,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            settingItems[index].label,
                                            style: TextStyle(
                                                fontFamily: "NotoSans",
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: appTheme.textMainColor),
                                          ),
                                          Text(
                                            settingItems[index].description,
                                            style: TextStyle(
                                              fontFamily: "NunitoSans",
                                              color: isPremiumItem
                                                  ? appTheme.accentColor
                                                  : appTheme.textSubColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: appTheme.textMainColor,
                                  size: 30,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
