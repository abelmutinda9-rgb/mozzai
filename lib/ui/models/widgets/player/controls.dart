import 'dart:io';

import 'package:animestream/core/commons/utils.dart';
import 'package:animestream/ui/models/widgets/player/desktopControls/desktopControls.dart';
import 'package:animestream/ui/models/widgets/player/mobileControls/mobileControls.dart';
import 'package:flutter/material.dart';

/// Uses touch-first controls on phones and keyboard/D-pad controls on TV.
class Controls extends StatelessWidget {
  const Controls({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return const _AndroidControls();
    return Platform.isIOS ? const MobileControls() : const DesktopControls();
  }
}

class _AndroidControls extends StatefulWidget {
  const _AndroidControls();

  @override
  State<_AndroidControls> createState() => _AndroidControlsState();
}

class _AndroidControlsState extends State<_AndroidControls> {
  late final Future<bool> _isTv = isTv();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isTv,
      builder: (context, snapshot) => snapshot.data == true
          ? const DesktopControls(remoteMode: true)
          : const MobileControls(),
    );
  }
}
