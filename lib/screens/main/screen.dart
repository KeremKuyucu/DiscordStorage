import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:DiscordStorage/services/utilities.dart';
import 'package:DiscordStorage/services/bottom_bar_service.dart';
import 'package:DiscordStorage/screens/settings/screen.dart';
import 'package:DiscordStorage/screens/settings/service.dart';
import 'package:DiscordStorage/services/file_system_service.dart';
import 'package:DiscordStorage/services/download_service.dart';
import 'package:DiscordStorage/services/file_spliter.dart';
import 'package:DiscordStorage/services/file_merger.dart';
import 'package:DiscordStorage/services/discord_service.dart';
import 'package:DiscordStorage/services/path_service.dart';
import 'package:DiscordStorage/services/file_share_service.dart';
import 'package:DiscordStorage/services/shared_file_merger.dart';
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class DiscordStorageLobi extends StatefulWidget {
  @override
  _DiscordStorageLobiState createState() => _DiscordStorageLobiState();
}

class _DiscordStorageLobiState extends State<DiscordStorageLobi> {
  List<String> currentPath = [];
  late Filespliter filespliter = Filespliter();
  late final FileSystemService fileSystemService = FileSystemService();
  final DiscordService discordService = DiscordService();
  final FileDownloader fileDownloader = FileDownloader();
  final FileMerger fileMerger = FileMerger();
  final PathHelper pathHelper = PathHelper();
  final FileShare fileShare = FileShare();
  final SettingsService settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    fileSystemService.load().then((_) {
      fileSystemService.save();
      setState(() {});
    });
    _initializeGame();
  }


  Future<void> _initializeGame() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
    final settings = await settingsService.loadSettings();

    setState(() {
      token = settings['token'];
      guildId = settings['guildId'];
      categoryId = settings['categoryId'];
      isDarkMode = settings['is_dark_mode'];
      languageCode = settings['language_code'];
      Language.load(languageCode);
      if (isDarkMode) {
        ThemeModeBuilderConfig.setDark();
      } else {
        ThemeModeBuilderConfig.setLight();
      }
    });
    if (token==''){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage()),
      );
    }
  }

  // ----------------- Buton Fonksiyonları -----------------

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
            title: Text(Language.get('createNewFolder')),
            content: TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: Language.get('folderNameHint')),
              onChanged: (value) {
                folderName = value;
              },
              onSubmitted: (_) => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(Language.get('cancel')),
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
                child: Text(Language.get('create')),
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

  void _moveItemUp(String name) {
    final currentDir = fileSystemService.getNodeAt(currentPath);
    if (currentDir == null) return;

    final childrenKeys = currentDir['children'].keys.toList();
    final index = childrenKeys.indexOf(name);
    if (index > 0) {
      final keys = childrenKeys;
      final temp = keys[index - 1];
      keys[index - 1] = keys[index];
      keys[index] = temp;

      final newChildren = <String, dynamic>{};
      for (var k in keys) {
        newChildren[k] = currentDir['children'][k];
      }
      currentDir['children'] = newChildren;
      fileSystemService.save();
      setState(() {});
    }
  }

  void _moveItemDown(String name) {
    final currentDir = fileSystemService.getNodeAt(currentPath);
    if (currentDir == null) return;

    final childrenKeys = currentDir['children'].keys.toList();
    final index = childrenKeys.indexOf(name);
    if (index >= 0 && index < childrenKeys.length - 1) {
      final keys = childrenKeys;
      final temp = keys[index + 1];
      keys[index + 1] = keys[index];
      keys[index] = temp;

      final newChildren = <String, dynamic>{};
      for (var k in keys) {
        newChildren[k] = currentDir['children'][k];
      }
      currentDir['children'] = newChildren;
      fileSystemService.save();
      setState(() {});
    }
  }

  Future<void> _deleteItem(String name, {required String channelId, bool deleteFromDiscord = false}) async {
    fileSystemService.deleteItem(currentPath, name);
    if (deleteFromDiscord) {
      await discordService.deleteDiscordChannel(channelId);
    }
    fileSystemService.save();
    setState(() {});
  }

  void _downloadFile(String fileName,String channelId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName ${Language.get('downloadingFile')}')),
    );
    final messages = await discordService.getMessages(channelId, 1);

    final lastMessageContent = messages.first;
    final Map<String, dynamic> data = jsonDecode(lastMessageContent);

    final messageId = data['messageId'];
    final fileNameFromMessage = data['fileName'] + 'temp.txt';
    final filePath = await pathHelper.getDownloadsDirectoryPath()+ fileNameFromMessage;
    final channelIdFromMessage = data['channelId'];

    final url = await discordService.getFileUrl(channelIdFromMessage, messageId);
    await fileDownloader.fileDownload(url,filePath);

    await fileMerger.mergeFiles(filePath);

    final file = File(fileNameFromMessage);
    if (await file.exists()) {
      await file.delete();
      Logger.log('$fileNameFromMessage deleted');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Language.get('downloadComplete'))),
    );
  }

  Future<void> _pickAndStartUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String linksPath = '${filePath}_links.txt';
      await filespliter.splitFileAndUpload(filePath, linksPath, context);
      final linkFile = File(linksPath);
      if (await linkFile.exists()) {
        await linkFile.delete();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Language.get('fileNotSelected'))),
      );
    }
  }

  void _showDownloadLinkDialog(BuildContext context) async {
    final filePicker = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (filePicker == null || filePicker.files.isEmpty) return;

    final path = filePicker.files.first.path!;
    final merger = SharedFileMerger();
    await merger.mergeFiles(path);
  }

  Future<void> _shareFile(String fileName, String channelId) async {
    final messages = await discordService.getMessages(channelId, 1);

    final lastMessageContent = messages.first;
    final Map<String, dynamic> data = jsonDecode(lastMessageContent);

    final messageId = data['messageId'];
    final fileNameFromMessage = data['fileName'] + 'temp.txt';
    final filePath = await pathHelper.getDownloadsDirectoryPath()+ fileNameFromMessage;
    final channelIdFromMessage = data['channelId'];

    final url = await discordService.getFileUrl(channelIdFromMessage, messageId);
    await fileDownloader.fileDownload(url,filePath);
    fileShare.generateLinkFileAndShare(filePath);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName ${Language.get('shareFileDownloaded')}')),
    );
  }

  void _showDeleteConfirmationDialog(String name, bool isFolder, String channelId) {
    bool deleteFromDiscord = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('$name ${Language.get('deleteFileConfirmation')}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Language.get('permanentlyDelete')),
                  SizedBox(height: 16),
                  if (!isFolder)
                    Row(
                      children: [
                        Checkbox(
                          value: deleteFromDiscord,
                          onChanged: (bool? value) {
                            setState(() {
                              deleteFromDiscord = value ?? false;
                            });
                          },
                        ),
                        Expanded(child: Text(Language.get('deleteFromDiscord'))),
                      ],
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(Language.get('cancel')),
                ),
                TextButton(
                  onPressed: () async {
                    await _deleteItem(
                      name,
                      channelId: channelId,
                      deleteFromDiscord: deleteFromDiscord,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(Language.get('deleteConfirmation')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameDialog(String oldName, bool isFolder, String channelId) {
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Language.get('rename')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: Language.get('newNameLabel')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(Language.get('cancel')),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                fileSystemService.renameItem(currentPath, oldName, newName);
                fileSystemService.save();
                if (!isFolder) {
                  discordService.renameChannel(channelId: channelId, newName: newName);
                }
                setState(() {});
              }
              Navigator.of(context).pop();
            },
            child: Text(Language.get('save')),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentDir = fileSystemService.getNodeAt(currentPath);
    if (currentDir == null || currentDir['type'] != 'folder') {
      return Scaffold(
        appBar: AppBar(title: Text(Language.get('invalidFolder'))),
        body: Center(child: Text(Language.get('noFolderFound'))),
      );
    }

    final rawChildren = currentDir['children'] as Map<dynamic, dynamic>;
    final Map<String, Map<String, dynamic>> children = rawChildren.map(
          (key, value) => MapEntry(
        key.toString(),
        Map<String, dynamic>.from(value as Map<String, dynamic>),
      ),
    );

    final items = children.keys.toList();
    final List<String> displayItems = [
      if (currentPath.isNotEmpty) '...',
      ...items,
    ];

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
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file, color: Colors.white),
                  SizedBox(width: 8),
                  Text(name, style: TextStyle(color: Colors.white)),
                ],
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
      bottomNavigationBar: BottomNavBarWidget(
        titles: [
          Language.get('files'),
          Language.get('settings'),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: Language.get('uploadFileMessage'),
              child: FloatingActionButton(
                heroTag: 'uploadBtn',
                backgroundColor: Theme.of(context).colorScheme.primary,
                onPressed: _pickAndStartUpload,
                child: Icon(Icons.upload_file, color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            SizedBox(height: 10),
            Tooltip(
              message: Language.get('createFolderMessage'),
              child: FloatingActionButton(
                heroTag: 'createFolderBtn',
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.create_new_folder, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: () => _showCreateFolderDialog(context),
              ),
            ),
            SizedBox(height: 10),
            Tooltip(
              message: Language.get('sharedFileDownloadMessage'),
              child: FloatingActionButton(
                heroTag: 'downloadSharedBtn',
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.download, color: Theme.of(context).colorScheme.onPrimary),
                onPressed: () => _showDownloadLinkDialog(context),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildListTile(String name, bool isFolder) {
    final item = fileSystemService.getNodeAt([...currentPath, name]);
    final channelId = item?['id'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isFolder ? Icons.folder : Icons.insert_drive_file,
            color: isFolder ? Colors.amber : Colors.grey,
          ),
          SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isFolder) {
                  _enterFolder(name);
                } else {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(name)));
                }
              },
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'up':
                  _moveItemUp(name);
                  break;
                case 'down':
                  _moveItemDown(name);
                  break;
                case 'download':
                  _downloadFile(name, channelId);
                  break;
                case 'share':
                  _shareFile(name, channelId);
                  break;
                case 'rename':
                  _showRenameDialog(name, isFolder, channelId);
                  break;
                case 'delete':
                  _showDeleteConfirmationDialog(name, isFolder, channelId);
                  break;
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'up',
                child: ListTile(
                  leading: Icon(Icons.arrow_upward, color: Colors.blue),
                  title: Text(Language.get('moveUp')),
                ),
              ),
              PopupMenuItem<String>(
                value: 'down',
                child: ListTile(
                  leading: Icon(Icons.arrow_downward, color: Colors.blue),
                  title: Text(Language.get('moveDown')),
                ),
              ),
              if (!isFolder)
                PopupMenuItem<String>(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download, color: Colors.green),
                    title: Text(Language.get('download')),
                  ),
                ),
              if (!isFolder)
                PopupMenuItem<String>(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share, color: Colors.deepPurple),
                    title: Text(Language.get('share')),
                  ),
                ),
              PopupMenuItem<String>(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit, color: Colors.orange),
                  title: Text(Language.get('rename')),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text(Language.get('delete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

