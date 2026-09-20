import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:theme_mode_builder/theme_mode_builder.dart';
import 'package:discord_storage/services/bottom_bar_service.dart';
import 'package:discord_storage/screens/settings/screen.dart';
import 'package:discord_storage/screens/settings/service.dart';
import 'package:discord_storage/services/file_system_service.dart';
import 'package:discord_storage/services/download_service.dart';
import 'package:discord_storage/services/file_spliter.dart';
import 'package:discord_storage/services/file_merger.dart';
import 'package:discord_storage/services/discord_service.dart';
import 'package:discord_storage/services/path_service.dart';
import 'package:discord_storage/services/logger_service.dart';
import 'package:discord_storage/services/localization_service.dart';
import 'package:discord_storage/services/developer_info.dart';
import 'package:discord_storage/services/update_checker_service.dart';
import 'package:discord_storage/services/link_generator.dart';
import 'package:discord_storage/services/telemetry_service.dart';
import 'package:path/path.dart' as path;

class DiscordStorageLobi extends StatefulWidget {
  final String? initialMessageId;
  const DiscordStorageLobi({super.key, this.initialMessageId});

  @override
  State<DiscordStorageLobi> createState() => _DiscordStorageLobiState();
}

class _DiscordStorageLobiState extends State<DiscordStorageLobi> {
  List<String> currentPath = [];
  late final Filespliter filespliter = Filespliter();
  final FileSystemService fileSystemService = FileSystemService();
  late final DiscordService discordService = DiscordService();
  late final FileDownloader fileDownloader = FileDownloader();
  late final PathHelper pathHelper = PathHelper();
  late final FileMerger fileMerger = FileMerger();
  late final LinkGenerator _linkGenerator = LinkGenerator();
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await fileSystemService.load();
    if (!mounted) return;
    setState(() {});

    UpdateChecker(
      context: context,
      repoOwner: 'KeremKuyucu',
      repoName: 'DiscordStorage',
    ).checkForUpdate();

    if (SettingsService.isDarkMode) {
      ThemeModeBuilderConfig.setDark();
    } else {
      ThemeModeBuilderConfig.setLight();
    }
    if (SettingsService.token.isEmpty) {
      selectedIndex = 1;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage()),
      );
    }
    TelemetryService.sendEventOnce(
      appId: 'discordstorage',
      userId: SettingsService.storageChannelId,
      eventEndpoint: "app_opened",
    );

    if (widget.initialMessageId != null && widget.initialMessageId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSharedMessageId(widget.initialMessageId!);
      });
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
      builder:
          (context) => AlertDialog(
            title: Text(Language.get('createNewFolder')),
            content: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: Language.get('folderNameHint'),
              ),
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
                  if (folderName.trim().isNotEmpty) {
                    fileSystemService.createFolder(
                      currentPath,
                      folderName.trim(),
                    );
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

  void _showDeleteConfirmationDialog(
    String name,
    bool isFolder,
    String channelId,
  ) {
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
                        Expanded(
                          child: Text(Language.get('deleteFromDiscord')),
                        ),
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
                    fileSystemService.deleteItem(currentPath, name);
                    if (deleteFromDiscord) {
                      await discordService.deleteDiscordChannel(channelId);
                    }
                    fileSystemService.save();
                    setState(() {});
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
      builder:
          (context) => AlertDialog(
            title: Text(Language.get('rename')),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: Language.get('newNameLabel'),
              ),
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
                      discordService.renameChannel(
                        channelId: channelId,
                        newName: newName,
                      );
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

  Future<void> _shareFile(String fileName, String channelId) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$fileName ${Language.get('shareFileDownloading')}'),
      ),
    );

    final messages = await discordService.getMessages(channelId, 1);
    final lastMessageContent = messages.first;
    final Map<String, dynamic> data = jsonDecode(lastMessageContent);

    final messageId = data['messageId'];
    final fileNameFromMessage = data['fileName'] + 'temp.txt';
    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final filePath = path.join(downloadsDir, fileNameFromMessage);
    final channelIdFromMessage = data['channelId'];

    final url = await discordService.getFileUrl(
      channelIdFromMessage,
      messageId,
    );
    await fileDownloader.fileDownload(url, filePath);
    final shareUrl = await _linkGenerator.generateShareLinkFromFile(filePath);

    final linkFile = File(filePath);
    if (await linkFile.exists()) {
      await linkFile.delete();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName ${Language.get('shareFileUploaded')}')),
    );

    // İşlem bittikten sonra URL gösteren ve butonlar olan dialog
    if (shareUrl != null) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(Language.get('shareFileUploaded')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(shareUrl),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await SharePlus.instance.share(
                          ShareParams(text: shareUrl),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: Text(Language.get('share')),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(Language.get('copiedToClipboard')),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: Text(Language.get('copyUrl')),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showDownloadLinkDialog(BuildContext context) async {
    final messageId = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: Text(Language.get('enterFileId')),
          content: TextField(
            onChanged: (value) => input = value,
            decoration: InputDecoration(hintText: Language.get('messageId')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(Language.get('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, input.trim()),
              child: Text(Language.get('ok')),
            ),
          ],
        );
      },
    );

    if (messageId == null || messageId.isEmpty) return;

    await _startDownloadSharedFile(messageId);
  }

  Future<void> _handleSharedMessageId(String messageId) async {
    if (!mounted) return;
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Language.get('sharedFileDownload')),
        content: Text('ID: $messageId\n\nBu dosyayı indirmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Language.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(Language.get('ok')),
          ),
        ],
      ),
    );

    if (shouldDownload == true) {
      await _startDownloadSharedFile(messageId);
    }
  }

  Future<void> _startDownloadSharedFile(String messageId) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${Language.get('downloadingFile')} ($messageId)')),
      );

      final filePath = await fileDownloader.sharedFileDownload(messageId);

      if (filePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Language.get('fileCreationFailed'))),
        );
        return;
      }
      await fileMerger.mergeFiles(filePath, true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Language.get('sharedFileDownloaded'))),
      );
    } catch (e, stack) {
      Logger.error('Error: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Language.get('fileCreationFailed'))),
      );
    }
  }

  void _downloadFile(String fileName, String channelId) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$fileName ${Language.get('downloadingFile')}')),
    );
    final messages = await discordService.getMessages(channelId, 1);

    final lastMessageContent = messages.first;
    final Map<String, dynamic> data = jsonDecode(lastMessageContent);

    final messageId = data['messageId'];
    final fileNameFromMessage = data['fileName'] + 'temp.txt';
    final downloadsDir = await pathHelper.getDownloadsDirectoryPath();
    final filePath = path.join(downloadsDir, fileNameFromMessage);
    final channelIdFromMessage = data['channelId'];

    final url = await discordService.getFileUrl(
      channelIdFromMessage,
      messageId,
    );
    await fileDownloader.fileDownload(url, filePath);

    await fileMerger.mergeFiles(filePath, false);

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      Logger.info('$fileNameFromMessage deleted');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(Language.get('downloadComplete'))));
  }

  Future<void> _pickAndStartUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String linksPath = '${filePath}_links.txt';
      // ignore: use_build_context_synchronously
      await filespliter.splitFileAndUpload(filePath, linksPath, context);
      final linkFile = File(linksPath);
      if (await linkFile.exists()) {
        await linkFile.delete();
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Language.get('fileNotSelected'))));
    }
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
        leading:
            currentPath.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
                : IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    DeveloperInfo.show(context);
                  },
                ),
        iconTheme: const IconThemeData(size: 35.0, color: Colors.blue),
        title: Text(
          currentPath.isEmpty ? 'DiscordStorage' : currentPath.join('/'),
          style: const TextStyle(color: Colors.purple),
        ),
        centerTitle: true,
        actionsIconTheme: const IconThemeData(size: 35.0, color: Colors.blue),
        actions: [
          Tooltip(
            message: Language.get('uploadFileMessage'),
            child: IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _pickAndStartUpload,
            ),
          ),
          Tooltip(
            message: Language.get('createFolderMessage'),
            child: IconButton(
              icon: const Icon(Icons.create_new_folder),
              onPressed: () => _showCreateFolderDialog(context),
            ),
          ),
          Tooltip(
            message: Language.get('sharedFileDownloadMessage'),
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _showDownloadLinkDialog(context),
            ),
          ),
          //const SizedBox(width: 24.0),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: displayItems.length,
        separatorBuilder: (_, __) => Divider(),
        itemBuilder: (context, index) {
          final name = displayItems[index];

          if (name == '...') {
            return DragTarget<Map<String, dynamic>>(
              onWillAcceptWithDetails: (_) => currentPath.isNotEmpty,
              onAcceptWithDetails: (details) {
                fileSystemService.moveItem(
                  details.data['path'],
                  details.data['name'],
                  currentPath.sublist(0, currentPath.length - 1),
                );
                fileSystemService.save();
                setState(() {});
              },
              builder:
                  (context, candidateData, rejectedData) => ListTile(
                    leading: Icon(Icons.arrow_upward, color: Colors.purple),
                    title: Text('...'),
                    onTap: _goBack,
                    tileColor:
                        candidateData.isNotEmpty
                            ? Colors.purple.withValues(alpha: 0.2)
                            : null,
                  ),
            );
          }

          final item = children[name]!;
          final isFolder = item['type'] == 'folder';

          return DragTarget<Map<String, dynamic>>(
            onWillAcceptWithDetails: (_) => isFolder,
            onAcceptWithDetails: (details) {
              fileSystemService.moveItem(details.data['path'], details.data['name'], [
                ...currentPath,
                name,
              ]);
              fileSystemService.save();
              setState(() {});
            },
            builder:
                (
                  context,
                  candidateData,
                  rejectedData,
                ) => Draggable<Map<String, dynamic>>(
                  data: {'name': name, 'path': List<String>.from(currentPath)},
                  feedback: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFolder ? Icons.folder : Icons.insert_drive_file,
                            color: Colors.white,
                          ),
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
      bottomNavigationBar: BottomNavBarWidget(),
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
            itemBuilder:
                (context) => <PopupMenuEntry<String>>[
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
