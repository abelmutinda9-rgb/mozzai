import 'dart:ui';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/ui/models/widgets/floatyBar/controller.dart';
import 'package:flutter/material.dart';

class FloatyBarItem {
  final String title;
  final IconData icon;

  const FloatyBarItem({
    required this.title,
    required this.icon,
  });
}

class FloatyBottomBar extends StatefulWidget {
  final List<FloatyBarItem> items;
  final FloatyBottomBarController controller;
  final double height;
  final double bottomPadding;
  final Color backgroundColor;
  final Color accentColor;
  final Duration animationDuration;
  final double detachGap;
  final double outerRadius;
  final double activeRadius;

  const FloatyBottomBar({
    super.key,
    required this.items,
    required this.controller,
    this.height = 50,
    this.bottomPadding = 10,
    this.backgroundColor = Colors.black,
    this.accentColor = const Color(0xffF47521),
    this.animationDuration = const Duration(milliseconds: 200),
    this.detachGap = 5,
    this.outerRadius = 24,
    this.activeRadius = 24,
  });

  @override
  State<FloatyBottomBar> createState() => _FloatyBottomBarState();
}

class _FloatyBottomBarState extends State<FloatyBottomBar> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.currentIndex;
    widget.controller.currentIndexNotifier.addListener(_onControllerIndexChanged);
  }

  @override
  void dispose() {
    widget.controller.currentIndexNotifier.removeListener(_onControllerIndexChanged);
    super.dispose();
  }

  void _onControllerIndexChanged() {
    final newIndex = widget.controller.currentIndex;
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  void _onItemTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      widget.controller.currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final lastIndex = widget.items.length - 1;

    bool hasGapBetween(int leftIndex, int rightIndex) {
      if (leftIndex < 0 || rightIndex > lastIndex) return false;
      final leftIsActive = leftIndex == _currentIndex;
      final rightIsActive = rightIndex == _currentIndex;
      return leftIsActive != rightIsActive;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + widget.bottomPadding),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.outerRadius + 4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: appTheme.backgroundSubColor.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(widget.outerRadius + 4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final isActive = i == _currentIndex;
                  final hasLeftGap = i > 0 && hasGapBetween(i - 1, i);
                  final hasRightGap = i < lastIndex && hasGapBetween(i, i + 1);
                  final leftNeighborIsActive = i > 0 && (i - 1) == _currentIndex;
                  final rightNeighborIsActive = i < lastIndex && (i + 1) == _currentIndex;
                  final segmentRadius = Radius.circular(isActive ? widget.activeRadius : widget.outerRadius);
                  final activeFacingCornerRadius = Radius.circular(widget.outerRadius / 2);

                  return GestureDetector(
                    onTap: () => _onItemTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: widget.animationDuration,
                      curve: Curves.easeInOut,
                      height: widget.height,
                      margin: EdgeInsets.only(
                        left: hasLeftGap ? widget.detachGap / 2 : 0,
                        right: hasRightGap ? widget.detachGap / 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? appTheme.accentColor : Colors.transparent,
                        borderRadius: BorderRadius.only(
                          topLeft: (!isActive && leftNeighborIsActive)
                              ? activeFacingCornerRadius
                              : (i == 0 || hasLeftGap)
                                  ? segmentRadius
                                  : Radius.zero,
                          bottomLeft: (!isActive && leftNeighborIsActive)
                              ? activeFacingCornerRadius
                              : (i == 0 || hasLeftGap)
                                  ? segmentRadius
                                  : Radius.zero,
                          topRight: (!isActive && rightNeighborIsActive)
                              ? activeFacingCornerRadius
                              : (i == lastIndex || hasRightGap)
                                  ? segmentRadius
                                  : Radius.zero,
                          bottomRight: (!isActive && rightNeighborIsActive)
                              ? activeFacingCornerRadius
                              : (i == lastIndex || hasRightGap)
                                  ? segmentRadius
                                  : Radius.zero,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: appTheme.accentColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isActive ? 18 : 18,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.items[i].icon,
                            size: 22,
                            color: isActive ? appTheme.onAccent : appTheme.textSubColor,
                          ),
                          AnimatedSize(
                            duration: widget.animationDuration,
                            curve: Curves.easeInOut,
                            child: isActive
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.items[i].title,
                                      style: TextStyle(
                                        color: appTheme.onAccent,
                                        fontFamily: "NotoSans",
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
