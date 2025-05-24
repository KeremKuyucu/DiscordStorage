import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:DiscordStorage/services/logger_service.dart';

class FileSystemService {
  Map<String, dynamic> fileSystem = {
    'type': 'folder',
    'children': {},
  };

  Map<String, dynamic>? getNodeAt(List<String> path) {
    Map<String, dynamic> current = fileSystem;
    for (final segment in path) {
      if (current['type'] != 'folder' ||
          !(current['children'] as Map).containsKey(segment)) {
        Logger.error('Node not found: $segment');
        return null;
      }
      current = current['children'][segment];
    }
    return current;
  }

  void createFolder(List<String> path, String name) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Folder creation failed. Invalid path.');
      return;
    }
    node['children'][name] = {
      'type': 'folder',
      'children': <String, dynamic>{},
    };
    Logger.log('Folder created: $name');
  }

  void renameItem(List<String> path, String oldName, String newName) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Rename failed. Invalid path.');
      return;
    }

    final children = node['children'] as Map<String, dynamic>;

    if (!children.containsKey(oldName)) {
      Logger.error('Item to rename not found: $oldName');
      return;
    }

    if (children.containsKey(newName)) {
      Logger.error('New name already in use: $newName');
      return;
    }

    final item = children.remove(oldName)!;
    children[newName] = item;

    // If it's a file, update the internal name as well (optional)
    if (item['type'] == 'file') {
      item['name'] = newName;
    }

    Logger.log('Item renamed: $oldName -> $newName');
  }

  List<String> listItemNames(List<String> path) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Listing failed. Invalid path.');
      return [];
    }
    final children = node['children'] as Map;
    return children.keys.map((e) => e.toString()).toList();
  }

  bool idExistsInTree(Map<String, dynamic> node, String id) {
    if (node['type'] == 'file' && node['id'] == id) {
      return true;
    } else if (node['type'] == 'folder' && node.containsKey('children')) {
      final children = node['children'] as Map<String, dynamic>;
      for (final child in children.values) {
        if (idExistsInTree(child, id)) {
          return true;
        }
      }
    }
    return false;
  }

  void createFile(List<String> path, String name, String id) {
    if (idExistsInTree(fileSystem, id)) {
      Logger.error('A file with the same id already exists, file not created.');
      return;
    }

    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('File creation failed. Invalid path.');
      return;
    }

    final children = node['children'] as Map<String, dynamic>;
    if (children.containsKey(name)) {
      Logger.error('A file or folder with the same name already exists.');
      return;
    }

    node['children'][name] = {
      'type': 'file',
      'id': id,
      'name': name,
    };

    Logger.log('File created: $name');
  }

  void deleteItem(List<String> path, String name) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') {
      Logger.error('Delete operation failed. Invalid path.');
      return;
    }
    node['children'].remove(name);
    Logger.log('Item deleted: $name');
  }

  void moveItem(List<String> fromPath, String name, List<String> toPath) {
    final fromNode = getNodeAt(fromPath);
    final toNode = getNodeAt(toPath);
    if (fromNode == null || toNode == null) {
      Logger.error('Move operation failed. Invalid path.');
      return;
    }
    final item = fromNode['children'].remove(name);
    if (item != null) {
      toNode['children'][name] = item;
      Logger.log('Item moved: $name');
    } else {
      Logger.error('Item to move not found: $name');
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(fileSystem);
    await prefs.setString('fileSystem', jsonString);
    Logger.log('File system saved.');
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('fileSystem');
    if (jsonString != null) {
      fileSystem = jsonDecode(jsonString);
      Logger.log('File system loaded.');
    } else {
      Logger.error('No saved file system found.');
    }
  }
}
