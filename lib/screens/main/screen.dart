import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:discordstorage/screens/settings/settings.dart';
import 'package:discordstorage/services/fileSystem.dart';
import 'package:discordstorage/services/updatechecker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class DiscordStorageLobi extends StatefulWidget {
  @override
  _DiscordStorageLobiState createState() => _DiscordStorageLobiState();
}

class _DiscordStorageLobiState extends State<DiscordStorageLobi> {
  int selectedIndex = 0;
  late FileSystemService fileSystemService;
  List<String> currentPath = [];

  @override
  @override
  void initState() {
    super.initState();
    fileSystemService = FileSystemService(); // 💥 ÖNEMLİ: önce örnekle
    fileSystemService.load().then((_) {
      fileSystemService.createFile([], 'dosy2sdfsdfa1.txt', 'uuid-12342');
      fileSystemService.save();
      setState(() {});
    });
    ThemeModeBuilderConfig.setDark();
    _initializeGame();
  }


  Future<void> _initializeGame() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker(
        context: context,
        repoOwner: 'KeremKuyucu',
        repoName: 'DiscordStorageNew',
      ).checkForUpdate();
    });
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // ----------------- Klasör Fonksiyonları -----------------

  void _goBack() {
    if (currentPath.isNotEmpty) {
      setState(() {
        currentPath.removeLast();
      });
    }
  }

  Future<void> _showCreateFolderDialog(BuildContext context) async {
    String folderName = '';
    await showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Yeni klasör oluştur'),
            content: TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: 'Klasör adı'),
              onChanged: (value) {
                folderName = value;
              },
              onSubmitted: (_) => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  if (folderName
                      .trim()
                      .isNotEmpty) {
                    fileSystemService.createFolder(
                        currentPath, folderName.trim());
                    fileSystemService.save();
                    setState(() {});
                  }
                  Navigator.pop(context);
                },
                child: Text('Oluştur'),
              ),
            ],
          ),
    );
  }

  void _enterFolder(String folderName) {
    setState(() {
      currentPath.add(folderName);
    });
  }

  void _downloadFile(String fileName) {
    // İndirme işlemini burada yapabilirsin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName indiriliyor...')),
    );
  }

  void _deleteItem(String name) {
    fileSystemService.deleteItem(currentPath, name);
    fileSystemService.save();
    setState(() {});
  }

  // ---------------------------------------------------------

  void _selectIndex(int index) {
    setState(() {
      selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage()),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final currentDir = fileSystemService.getNodeAt(currentPath);
    if (currentDir == null || currentDir['type'] != 'folder') {
      return Scaffold(
        appBar: AppBar(title: Text('Geçersiz klasör')),
        body: Center(child: Text('Klasör bulunamadı')),
      );
    }

    final rawChildren = currentDir['children'] as Map<dynamic, dynamic>;
    final Map<String, Map<String, dynamic>> children = rawChildren.map(
          (key, value) => MapEntry(
        key.toString(),
        Map<String, dynamic>.from(value as Map),
      ),
    );

    final items = children.keys.toList();
    final displayItems = currentPath.isNotEmpty ? ['...'] + items : items;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentPath.isEmpty ? 'DiscordStorage' : 'DiscordStorage / ${currentPath.join('/')}',
          style: TextStyle(color: Colors.purple),
        ),
        centerTitle: true,
        leading: currentPath.isNotEmpty ? IconButton( icon: Icon(Icons.arrow_back), onPressed: _goBack) : null,
      ),
    body: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: displayItems.length,
      separatorBuilder: (_, __) => Divider(),
      itemBuilder: (context, index) {
      final name = displayItems[index];

      if (name == '...') {
        return DragTarget<Map<String, dynamic>>(
          onWillAccept: (_) => currentPath.isNotEmpty,
          onAccept: (data) {
            fileSystemService.moveItem(
              data['path'],
              data['name'],
              currentPath.sublist(0, currentPath.length - 1),
            );
            fileSystemService.save();
            setState(() {});
          },
          builder: (context, candidateData, _) => ListTile(
            leading: Icon(Icons.arrow_upward, color: Colors.purple),
            title: Text('...'),
            onTap: _goBack,
            tileColor: candidateData.isNotEmpty
            ? Colors.purple.withOpacity(0.2) : null,
          ),
        );
      }

      final item = currentDir['children'][name];
      final isFolder = item['type'] == 'folder';

      return DragTarget<Map<String, dynamic>>(
        onWillAccept: (_) => isFolder,
        onAccept: (data) {
          fileSystemService.moveItem(
            data['path'],
            data['name'],
            [...currentPath, name],
          );
          fileSystemService.save();
          setState(() {});
        },
        builder: (context, candidateData, _) => Draggable<Map<String, dynamic>>(
        data: {
          'name': name,
          'path': List<String>.from(currentPath),
        },
        feedback: Material(
          color: Colors.transparent,
          child: Container(
          padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: _buildListTile(name, isFolder),
        ),
        child: _buildListTile(name, isFolder),
        ),
        );
        },
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: selectedIndex,
        onTap: _selectIndex,
        items: [
            SalomonBottomBarItem(
              icon: Icon(Icons.folder),
              title: Text('Depolama'),
              selectedColor: Colors.purple,
            ),
            SalomonBottomBarItem(
                icon: Icon(Icons.settings),
                title: Text('Ayarlar'),
                selectedColor: Colors.purple,
            ),
         ],
      ),
      floatingActionButton: selectedIndex == 0
      ? Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      FloatingActionButton(
      heroTag: 'uploadBtn',
      backgroundColor: Colors.purple,
      child: Icon(Icons.upload_file),
      onPressed: _pickAndUploadFile,
      ),
      SizedBox(height: 10),
      FloatingActionButton(
      heroTag: 'createFolderBtn',
      backgroundColor: Colors.purple,
      child: Icon(Icons.create_new_folder),
      onPressed: () => _showCreateFolderDialog(context),
      ),
      ],
      )
          : null,
    );
  }



  Widget _buildListTile(String name, bool isFolder) {
    return ListTile(
      leading: Icon(
        isFolder ? Icons.folder : Icons.insert_drive_file,
        color: isFolder ? Colors.amber : Colors.grey,
      ),
      title: Text(name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İndirme butonu (sadece dosya için göster)
          if (!isFolder)
            IconButton(
              icon: Icon(Icons.download, color: Colors.green),
              tooltip: 'İndir',
              onPressed: () {
                _downloadFile(name);
              },
            ),

          // Silme butonu
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            tooltip: 'Sil',
            onPressed: () {
              // Silme işlemi onayı için dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('$name silinsin mi?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        _deleteItem(name);
                        Navigator.pop(context);
                      },
                      child: Text('Sil'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      onTap: () {
        if (isFolder) {
          _enterFolder(name);
        } else {
          // Alternatif olarak dosyaya tıklayınca indirme işlemi yapabilirsin
          // Ya da sadece butona tıklama yeterli olsun diyorsan burayı boş bırakabilirsin
        }
      },
    );
  }


  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final file = File(path);


      final uri = Uri.parse(
          'https://example.com/upload'); // burayı kendi URL'inle değiştir
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya başarıyla yüklendi')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme başarısız: ${response.statusCode}')),
        );
      }
    }
  }
}

