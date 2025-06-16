import 'package:DiscordStorage/screens/logs/screen.dart';
import 'package:flutter/material.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:DiscordStorage/services/utilities.dart';
import 'package:DiscordStorage/screens/settings/service.dart';
import 'package:DiscordStorage/services/bottom_bar_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/file_system_service.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _botTokenController = TextEditingController();
  final _guildIdController = TextEditingController();
  final _categoryIdController = TextEditingController();
  final DiscordService discordService = DiscordService();
  final FileSystemService fileSystemService = FileSystemService();
  final SettingsService settingsService = SettingsService();
  bool _obscureToken = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    setState(() {
      _botTokenController.text = token;
      _guildIdController.text = guildId;
      _categoryIdController.text = categoryId;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _botTokenController.dispose();
    _guildIdController.dispose();
    _categoryIdController.dispose();
    super.dispose();
  }

  Future<void> _loadFilesLabel() async {
    await fileSystemService.load();
    final channels = await discordService.getChannelsInCategory();

    for (var channel in channels) {
      final name = channel['name'] ?? 'unknown';
      final id = channel['id'] ?? '';

      Logger.log('Channel Name: $name - ID: $id');

      fileSystemService.createFile([], name, id);
    }
    await fileSystemService.save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Language.get('filesLoaded'))),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    VoidCallback? toggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: toggleVisibility != null
            ? IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggleVisibility,
        )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings - DiscordStorage',style: TextStyle(color: Colors.purple)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _botTokenController,
                      label: Language.get('botToken'),
                      obscure: _obscureToken,
                      toggleVisibility: () {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _guildIdController,
                      label: Language.get('guildId'),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _categoryIdController,
                      label: Language.get('categoryId'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await settingsService.saveSettings(
                            token2: _botTokenController.text,
                            guildId2: _guildIdController.text,
                            categoryId2: _categoryIdController.text,
                            context: context,
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: Text(Language.get('saveLabel')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loadFilesLabel,
                        icon: Icon(Icons.search),
                        label: Text(Language.get('loadFilesLabel')),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(Language.get('themeLabel'), style: TextStyle(fontSize: 16)),
                        Switch(
                          value: isDarkMode,
                          onChanged: (val) {
                            setState(() {
                              isDarkMode = val;
                              if (val) {
                                ThemeModeBuilderConfig.setDark();
                              } else {
                                ThemeModeBuilderConfig.setLight();
                              }
                              settingsService.saveThemaMode(val);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(Language.get('language'), style: TextStyle(fontSize: 16)),
                            DropdownButton<String>(
                              value: languageCode,
                              items: languageCodes.map((code) {
                                return DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(Language.get(code)),
                                );
                              }).toList(),
                              onChanged: (String? newCode) async {
                                if (newCode == null) return;

                                await Language.load(newCode);
                                setState(() {
                                  languageCode = newCode;
                                });
                                settingsService.saveLanguageCode(newCode);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LogsPage()),
                          );
                        },
                        icon: const Icon(Icons.list),
                        label: Text(Language.get('viewLogs')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBarWidget(),
    );
  }
}