import 'package:discordstorage/util.dart';

int selectedIndex=0;
String channelId = '';
String messageId = '';
bool isEnglish=false;
final List<String> diller = ['Türkçe','English'];
String diltercihi = '';
String secilenDil='', apiserver = "https://keremkk.glitch.me/discordstorage";
List<SalomonBottomBarItem> navBarItems = [
  SalomonBottomBarItem(
    icon: const Icon(Icons.home),
    selectedColor: Colors.purple,
    title: const Text('Ana Sayfa'),
  ),
  SalomonBottomBarItem(
    icon: const Icon(Icons.settings),
    selectedColor: Colors.orange,
    title: const Text('Ayarlar'),
  ),
];

jsonWrite(int partNo, String channelId, String messageId) {
  // Gerçek jsonWrite implementasyonunuzu buraya ekleyin
  return '{"partNo": $partNo, "channelId": "$channelId", "messageId": "$messageId"}';
}
Map<String, String> idBul(String responseData) {
  // Gerçek idBul implementasyonunuzu buraya ekleyin
  // Örnek olarak boş bir map döndürüyorum
  // Genellikle burada JSON ayrıştırma yapmanız gerekir
  try {
    var decoded = jsonDecode(responseData);
    return {
      'channelId': decoded['channel_id']?.toString() ?? '', // Discord API'sine göre örnek
      'messageId': decoded['id']?.toString() ?? ''         // Discord API'sine göre örnek
    };
  } catch (e) {
    print('Error parsing JSON in idBul: $e');
    return {'channelId': '', 'messageId': ''};
  }
}
