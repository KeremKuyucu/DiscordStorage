import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:share_plus/share_plus.dart'; // Optional, comment out if not available
import 'package:DiscordStorage/services/logger_service.dart';
import 'package:DiscordStorage/services/localization_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> with TickerProviderStateMixin {
  List<LogEntry> logs = [];
  List<LogEntry> filteredLogs = [];
  bool isLoading = true;
  LogLevel? selectedLevel;
  DateTime? fromDate;
  DateTime? toDate;
  String searchQuery = '';
  bool isAutoRefresh = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadLogs();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    print('_loadLogs called');
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      print('Attempting to read logs...');

      // First ensure logger is initialized
      await Logger.init();
      print('Logger initialized');

      // Try the new method first
      List<LogEntry> loadedLogs = [];
      try {
        loadedLogs = await Logger.readLogs(
          filterLevel: selectedLevel,
          fromDate: fromDate,
          toDate: toDate,
          limit: 1000,
        );
        print('New method: Loaded ${loadedLogs.length} logs');
      } catch (e) {
        print('New method failed: $e, trying legacy method...');

        // Fallback to legacy method
        final legacyLogs = await Logger.readLogsAsStrings();
        print('Legacy method: Found ${legacyLogs.length} log strings');

        // Convert to LogEntry objects
        for (final logString in legacyLogs) {
          final entry = LogEntry.fromLegacyString(logString);
          if (entry != null) {
            // Apply filters
            if (selectedLevel != null && entry.level != selectedLevel) continue;
            loadedLogs.add(entry);
          }
        }

        // Sort by timestamp (newest first)
        loadedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Apply limit
        if (loadedLogs.length > 1000) {
          loadedLogs = loadedLogs.take(1000).toList();
        }

        print('Fallback method: Processed ${loadedLogs.length} logs');
      }

      if (mounted) {
        setState(() {
          logs = loadedLogs;
          _applySearchFilter();
          isLoading = false;
        });
        print('State updated, isLoading: false, showing ${filteredLogs.length} filtered logs');
      }
    } catch (e) {
      print('Complete error loading logs: $e');
      if (mounted) {
        setState(() {
          logs = []; // Set empty list on error
          filteredLogs = [];
          isLoading = false;
        });
        _showErrorSnackBar('Log yükleme hatası: $e');
      }
    }
  }

  void _applySearchFilter() {
    if (searchQuery.isEmpty) {
      filteredLogs = logs;
    } else {
      filteredLogs = logs.where((log) {
        return log.message.toLowerCase().contains(searchQuery.toLowerCase()) ||
            log.callerInfo.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> _clearLogs() async {
    try {
      await Logger.clearLogs();
      await _loadLogs();
      _showSuccessSnackBar(Language.get('logsCleared'));
    } catch (e) {
      _showErrorSnackBar('Log temizleme hatası: $e');
    }
  }

  Future<void> _shareLogs() async {
    if (filteredLogs.isEmpty) return;

    final content = filteredLogs
        .map((log) => log.toFormattedString())
        .join('\n');

    try {
      // If share_plus is not available, copy to clipboard instead
      await Clipboard.setData(ClipboardData(text: content));
      _showSuccessSnackBar('Loglar panoya kopyalandı');

      // Uncomment below if share_plus is available
      // await Share.share(
      //   content,
      //   subject: 'DiscordStorage Logs',
      // );
    } catch (e) {
      _showErrorSnackBar('Log paylaşma hatası: $e');
    }
  }

  void _copyLogToClipboard(LogEntry log) {
    Clipboard.setData(ClipboardData(text: log.toFormattedString()));
    _showSuccessSnackBar('Log panoya kopyalandı');
  }

  void _showLogDetails(LogEntry log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${log.level.name} Log Detayı'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Zaman', log.timestamp.toLocal().toString()),
              _buildDetailRow('Seviye', log.level.name),
              _buildDetailRow('Çağıran', log.callerInfo),
              const SizedBox(height: 12),
              const Text('Mesaj:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(log.message),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyLogToClipboard(log),
            child: const Text('Kopyala'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Language.get('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Color _getLogLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.debug:
        return Colors.blue;
      case LogLevel.info:
      default:
        return Colors.green;
    }
  }

  IconData _getLogLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
      default:
        return Icons.info;
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Language.get('logs')),
        elevation: 0,
        actions: [
          if (filteredLogs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Logları Paylaş',
              onPressed: _shareLogs,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'clear':
                    _showClearDialog();
                    break;
                  case 'refresh':
                    _loadLogs();
                    break;
                  case 'export':
                    _shareLogs();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Yenile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Dışa Aktar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Temizle', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Filters and Search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Loglarda ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchQuery = '';
                            _applySearchFilter();
                          });
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _applySearchFilter();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('Tümü (${logs.length})'),
                          selected: selectedLevel == null,
                          onSelected: (selected) {
                            setState(() {
                              selectedLevel = null;
                            });
                            _loadLogs();
                          },
                        ),
                        const SizedBox(width: 8),
                        ...LogLevel.values.map((level) {
                          final count = logs.where((log) => log.level == level).length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: Icon(
                                _getLogLevelIcon(level),
                                size: 16,
                                color: selectedLevel == level
                                    ? Colors.white
                                    : _getLogLevelColor(level),
                              ),
                              label: Text('${level.name} ($count)'),
                              selected: selectedLevel == level,
                              selectedColor: _getLogLevelColor(level),
                              onSelected: (selected) {
                                setState(() {
                                  selectedLevel = selected ? level : null;
                                });
                                _loadLogs();
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Log List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredLogs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _loadLogs,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    return _buildLogCard(log, index);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            logs.isEmpty ? Language.get('noLogs') : 'Arama kriterlerine uygun log bulunamadı',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (searchQuery.isNotEmpty || selectedLevel != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  searchQuery = '';
                  selectedLevel = null;
                  _searchController.clear();
                });
                _loadLogs();
              },
              child: const Text('Filtreleri Temizle'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogCard(LogEntry log, int index) {
    final color = _getLogLevelColor(log.level);
    final icon = _getLogLevelIcon(log.level);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLogDetails(log),
        onLongPress: () => _copyLogToClipboard(log),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          log.level.name,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimestamp(log.timestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                log.message,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.code, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.callerInfo,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}g önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk önce';
    } else {
      return 'Az önce';
    }
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Language.get('clearLogs')),
        content: Text(Language.get('confirmClearLogs')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Language.get('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearLogs();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(Language.get('confirm')),
          ),
        ],
      ),
    );
  }
}