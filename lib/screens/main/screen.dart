import 'dart:convert';
import 'package:DiscordStorage/utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:DiscordStorage/screens/settings/settings.dart';
import 'package:DiscordStorage/services/file_system_service.dart';
import 'package:DiscordStorage/services/update_checker_service.dart';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:DiscordStorage/services/file_spliter.dart';
import 'package:DiscordStorage/services/file_merger.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'dart:io';

class DiscordStorageLobi extends StatefulWidget {
  @override
  _DiscordStorageLobiState createState() => _DiscordStorageLobiState();
}

class _DiscordStorageLobiState extends State<DiscordStorageLobi> {
  late FileSystemService fileSystemService;
  List<String> currentPath = [];

  late Filespliter filespliter;
  final DiscordService discordService = DiscordService();
  final FileDownloader fileDownloader = FileDownloader();
  final FileMerger fileMerger = FileMerger();

  @override
  void initState() {
    super.initState();
    fileSystemService = FileSystemService();
    fileSystemService.load().then((_) {
      fileSystemService.save();
      setState(() {});
    });
    filespliter = Filespliter(context);
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
    discordService.init();
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

  void _deleteItem(String name,String id){
    fileSystemService.deleteItem(currentPath, name);
    discordService.deleteDiscordChannel(channelId: id);
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
      onPressed: _pickAndStartUpload,
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
    final item = fileSystemService.getNodeAt([...currentPath, name]);
    final channelId = item?['id'] ?? '';
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
                _downloadFile(name,channelId);
              },
            ),

          // Silme butonu
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            tooltip: 'Sil',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('$name silinsin mi?'),
                  content: Text('Dosya Discord\'dan da kalıcı olarak silinir.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        _deleteItem(name,channelId);
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

  void _downloadFile(String fileName,String channelId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName indiriliyor...')),
    );
    final messages = await discordService.getMessages(channelId, 1);

    final lastMessageContent = messages.first;
    final Map<String, dynamic> data = jsonDecode(lastMessageContent);

    final messageId = data['messageId'];
    final fileNameFromMessage = data['fileName'] + 'temp.txt';
    final channelIdFromMessage = data['channelId'];

    final url = await discordService.getFileUrl(channelIdFromMessage, messageId);
    await fileDownloader.fileDownload(url, fileNameFromMessage);

    await fileMerger.mergeFiles(fileNameFromMessage);

    final file = File(fileNameFromMessage);
    if (await file.exists()) {
      await file.delete();
      debugPrint('$fileNameFromMessage silindi');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('İndirme tamamlandı')),
    );
  }
  Future<void> _pickAndStartUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      // Yanına _links.txt dosya yolu:
      String linksPath = '${filePath}_links.txt';
      await filespliter.splitFileAndUpload(filePath, linksPath);
      final linkFile = File(linksPath);
      if (await linkFile.exists()) {
        await linkFile.delete();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilmedi')),
      );
    }
  }
}

