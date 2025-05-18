import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:discordstorage/utilities.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:discordstorage/screens/main/screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _botTokenController = TextEditingController();
  final _guildIdController = TextEditingController();
  final _categoryIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _botTokenController.text = prefs.getString('bot_token') ?? '';
    _guildIdController.text = prefs.getString('guild_id') ?? '';
    _categoryIdController.text = prefs.getString('category_id') ?? '';
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bot_token', _botTokenController.text);
    await prefs.setString('guild_id', _guildIdController.text);
    await prefs.setString('category_id', _categoryIdController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayarlar kaydedildi')),
    );
  }

  @override
  void dispose() {
    _botTokenController.dispose();
    _guildIdController.dispose();
    _categoryIdController.dispose();
    super.dispose();
  }

  void _selectIndex(int index) async {
    setState(() {
      selectedIndex = index;
    });
    if (selectedIndex == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DiscordStorageLobi()),
      );
    }
    else if (selectedIndex == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage()),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _botTokenController,
              decoration: const InputDecoration(labelText: 'Bot Token'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _guildIdController,
              decoration: const InputDecoration(labelText: 'Guild ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _categoryIdController,
              decoration: const InputDecoration(labelText: 'Kategori ID'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xff6200ee),
        unselectedItemColor: const Color(0xff757575),
        onTap: (index) async {
          setState(() {
            selectedIndex = index;
          });
          _selectIndex(selectedIndex);
        },
        items: navBarItems,
      ),
    );
  }
}
