import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:DiscordStorage/screens/main/screen.dart';
import 'package:DiscordStorage/utilities.dart';
import 'package:DiscordStorage/services/token_checker_service.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/file_system_service.dart';

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

  late FileSystemService fileSystemService = FileSystemService();
  bool _obscureToken = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _botTokenController.text = prefs.getString('bot_token') ?? '';
      _guildIdController.text = prefs.getString('guild_id') ?? '';
      _categoryIdController.text = prefs.getString('category_id') ?? '';
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final token = _botTokenController.text.trim();

    final tokenChecker = TokenCheckerService();
    await tokenChecker.init();

    final isValid = await tokenChecker.checkAndSaveToken(token);

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Bot token geçersiz!')),
      );
      return;
    }

    // Token geçerliyse, kaydetme işlemi zaten TokenCheckerService içinde yapılıyor
    // Ek bilgi alanlarını ayrı kaydedebilirsin
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guild_id', _guildIdController.text.trim());
    await prefs.setString('category_id', _categoryIdController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Token geçerli. Ayarlar kaydedildi.')),
    );
  }


  @override
  void dispose() {
    _botTokenController.dispose();
    _guildIdController.dispose();
    _categoryIdController.dispose();
    super.dispose();
  }

  Future<void> _scanPreviouslyUploadedFiles() async {
    await fileSystemService.load();

    final channels = await discordService.getChannelsInCategory();

    for (var channel in channels) {
      final name = channel['name'] ?? 'unknown';
      final id = channel['id'] ?? '';

      debugPrint('Kanal Adı: $name - ID: $id');

      fileSystemService.createFile([], name, id);
    }
    await fileSystemService.save();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Dosyalar Tarandı.')),
    );

    selectedIndex = 0;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DiscordStorageLobi()),
    );
  }


  void _selectIndex(int index) {
    setState(() {
      selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DiscordStorageLobi()),
      );
    }
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
        title: const Text('Ayarlar'),
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
                      label: 'Bot Token',
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
                      label: 'Guild ID',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _categoryIdController,
                      label: 'Kategori ID',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Kaydet'),
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
                        onPressed: _scanPreviouslyUploadedFiles,
                        icon: Icon(Icons.search),
                        label: Text('Discord\'a yüklenmiş dosyaları tara'),
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
                        const Text('Debug Mod', style: TextStyle(fontSize: 16)),
                        Switch(
                          value: debugMode,
                          onChanged: (val) {
                            setState(() {
                              debugMode = val;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Açıldığı zaman indirilenler kısmında gonderimlog dosyası oluşur, dosyayı birine atarsanız verilerinizin güvenliği tehlikeye girebilir.', style: TextStyle(fontSize: 16))
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xff6200ee),
        unselectedItemColor: const Color(0xff757575),
        onTap: _selectIndex,
        items: [
          SalomonBottomBarItem(
            icon: Icon(Icons.home),
            title: Text("Ana Sayfa"),
            selectedColor: Colors.purple,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.settings),
            title: Text("Ayarlar"),
            selectedColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}
