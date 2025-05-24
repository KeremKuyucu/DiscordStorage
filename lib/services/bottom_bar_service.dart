import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:DiscordStorage/screens/settings/screen.dart';


int selectedIndex = 0;

class BottomNavBarWidget extends StatefulWidget {
  final List<String> titles;

  const BottomNavBarWidget({Key? key, required this.titles}) : super(key: key);

  @override
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
          title: Text(widget.titles[0]),
          selectedColor: Theme.of(context).colorScheme.primary,
        ),
        SalomonBottomBarItem(
          icon: Icon(Icons.settings),
          title: Text(widget.titles[1]),
          selectedColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}
