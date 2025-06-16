import 'package:DiscordStorage/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:DiscordStorage/screens/settings/screen.dart';


int selectedIndex = 0;

class BottomNavBarWidget extends StatefulWidget {
  State<BottomNavBarWidget> createState() => _BottomNavBarWidgetState();
}

class _BottomNavBarWidgetState extends State<BottomNavBarWidget> {
  void _selectIndex(int index) {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DiscordStorageLobi()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SalomonBottomBar(
      currentIndex: selectedIndex,
      onTap: _selectIndex,
      items: [
        SalomonBottomBarItem(
          icon: Icon(Icons.home),
          title: Text(Language.get('files')),
          selectedColor: Theme.of(context).colorScheme.primary,
        ),
        SalomonBottomBarItem(
          icon: Icon(Icons.settings),
          title: Text(Language.get('settings')),
          selectedColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}
