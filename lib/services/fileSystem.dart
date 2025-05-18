import 'dart:convert'; // jsonEncode ve jsonDecode için
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences için
class FileSystemService {
  Map<String, dynamic> fileSystem = {
    'type': 'folder',
    'children': {},
  };

  Map<String, dynamic>? getNodeAt(List<String> path) {
    Map<String, dynamic> current = fileSystem;
    for (final segment in path) {
      if (current['type'] != 'folder' ||
          !(current['children'] as Map).containsKey(segment)) return null;
      current = current['children'][segment];
    }
    return current;
  }

  void createFolder(List<String> path, String name) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') return;
    node['children'][name] = {
      'type': 'folder',
      'children': <String, dynamic>{},
    };
  }

  List<String> listItemNames(List<String> path) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') return [];
    final children = node['children'] as Map;
    return children.keys.map((e) => e.toString()).toList();
  }

  void createFile(List<String> path, String name, String id) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') return;

    // Aynı klasörde id'si daha önce eklenmiş dosya var mı kontrol et
    final children = node['children'] as Map<String, dynamic>;
    bool idExists = children.values.any((child) =>
    child['type'] == 'file' && child['id'] == id);

    if (idExists) {
      return;
    }

    // Yoksa dosyayı oluştur
    node['children'][name] = {
      'type': 'file',
      'id': id,
      'name': name,
    };
  }


  void deleteItem(List<String> path, String name) {
    final node = getNodeAt(path);
    if (node == null || node['type'] != 'folder') return;
    node['children'].remove(name);
  }

  void moveItem(List<String> fromPath, String name, List<String> toPath) {
    final fromNode = getNodeAt(fromPath);
    final toNode = getNodeAt(toPath);
    if (fromNode == null || toNode == null) return;
    final item = fromNode['children'].remove(name);
    if (item != null) {
      toNode['children'][name] = item;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(fileSystem);
    await prefs.setString('fileSystem', jsonString);
  }
  // Kaydedilmiş dosya sistemini yükle
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('fileSystem');
    if (jsonString != null) {
      fileSystem = jsonDecode(jsonString);
    }
  }

}
