import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:discord_storage/services/logger_service.dart';
import 'package:discord_storage/services/localization_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> with SingleTickerProviderStateMixin {
  List<LogEntry> _allLogs = [];
  List<LogEntry> _filteredLogs = [];
  bool _isLoading = true;
  LogLevel? _selectedLevel;
  String _searchQuery = '';
  bool _isAutoRefresh = false;
  bool _isCompactView = true;
  Timer? _refreshTimer;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _loadLogs();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleAutoRefresh(bool enable) {
    setState(() {
      _isAutoRefresh = enable;
    });
    _refreshTimer?.cancel();
    if (enable) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _loadLogs(isSilent: true);
      });
      _showToast('Canlı log akışı başlatıldı (3 sn)', isSuccess: true);
    } else {
      _showToast('Canlı akış duraklatıldı');
    }
  }

  Future<void> _loadLogs({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final loadedLogs = await Logger.readLogs(limit: 2000);

      if (mounted) {
        setState(() {
          _allLogs = loadedLogs;
          _applyFilters();
          _isLoading = false;
        });
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allLogs = [];
          _filteredLogs = [];
          _isLoading = false;
        });
        if (!isSilent) {
          _showToast('Log yükleme hatası: $e', isError: true);
        }
      }
    }
  }

  void _applyFilters() {
    List<LogEntry> result = _allLogs;

    if (_selectedLevel != null) {
      result = result.where((log) => log.level == _selectedLevel).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((log) {
        return log.message.toLowerCase().contains(q) ||
            log.callerInfo.toLowerCase().contains(q);
      }).toList();
    }

    setState(() {
      _filteredLogs = result;
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(Language.get('clearLogs')),
          ],
        ),
        content: Text(Language.get('confirmClearLogs')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Language.get('cancel')),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.15),
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Language.get('confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Logger.clearLogs();
      await _loadLogs();
      _showToast(Language.get('logsCleared'), isSuccess: true);
    }
  }

  Future<void> _copyAllLogs() async {
    if (_filteredLogs.isEmpty) return;
    final text = _filteredLogs.map((e) => e.toFormattedString()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _showToast('${_filteredLogs.length} log panoya kopyalandı', isSuccess: true);
  }

  Future<void> _openLogFileInNotepad() async {
    final path = await Logger.getLogFilePath();
    if (path == null || !File(path).existsSync()) {
      _showToast('Log dosyası henüz oluşmamış.', isError: true);
      return;
    }

    try {
      if (Platform.isWindows) {
        await Process.run('notepad.exe', [path]);
      }
    } catch (e) {
      _showToast('Dosya açılamadı: $e', isError: true);
    }
  }

  Future<void> _openLogFolderInExplorer() async {
    final path = await Logger.getLogFilePath();
    if (path == null) return;
    try {
      if (Platform.isWindows) {
        final dir = File(path).parent;
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final cleanPath = dir.path.replaceAll('/', '\\');
        await Process.run('explorer.exe', [cleanPath]);
      }
    } catch (e) {
      _showToast('Klasör açılamadı: $e', isError: true);
    }
  }

  void _copyLog(LogEntry log) {
    Clipboard.setData(ClipboardData(text: log.toFormattedString()));
    _showToast('Log satırı kopyalandı', isSuccess: true);
  }

  void _showLogDetails(LogEntry log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getLogLevelColor(log.level);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getLogLevelIcon(log.level), size: 16, color: color),
                          const SizedBox(width: 6),
                          Text(
                            log.level.name.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatFullDateTime(log.timestamp),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: Language.get('close'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Caller location
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.code_rounded, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Konum: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          log.callerInfo,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Log İçeriği:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Monospace message block
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1117) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.transparent,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        log.message,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Footer actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Metni Kopyala'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: log.message));
                        _showToast('Mesaj kopyalandı', isSuccess: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.content_copy, size: 16),
                      label: const Text('Tüm Kaydı Kopyala'),
                      onPressed: () {
                        _copyLog(log);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(String message, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : isSuccess
            ? const Color(0xFF059669)
            : const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getLogLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return const Color(0xFFEF4444);
      case LogLevel.warning:
        return const Color(0xFFF59E0B);
      case LogLevel.debug:
        return const Color(0xFF3B82F6);
      case LogLevel.info:
        return const Color(0xFF10B981);
    }
  }

  IconData _getLogLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Icons.cancel_rounded;
      case LogLevel.warning:
        return Icons.warning_rounded;
      case LogLevel.debug:
        return Icons.pest_control_rounded;
      case LogLevel.info:
        return Icons.check_circle_rounded;
    }
  }

  String _formatTimeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _formatFullDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d ${_formatTimeOnly(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final errorCount = _allLogs.where((l) => l.level == LogLevel.error).length;
    final warnCount = _allLogs.where((l) => l.level == LogLevel.warning).length;
    final infoCount = _allLogs.where((l) => l.level == LogLevel.info).length;
    final debugCount = _allLogs.where((l) => l.level == LogLevel.debug).length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.terminal_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              Language.get('logs'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filteredLogs.length} / ${_allLogs.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: surfaceColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
        actions: [
          // Auto-refresh toggle
          IconButton(
            icon: Icon(
              _isAutoRefresh ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: _isAutoRefresh ? Colors.green : Colors.grey,
            ),
            tooltip: _isAutoRefresh ? 'Canlı Akışı Duraklat' : 'Canlı Akışı Başlat (3s)',
            onPressed: () => _toggleAutoRefresh(!_isAutoRefresh),
          ),
          // View Mode Toggle
          IconButton(
            icon: Icon(_isCompactView ? Icons.view_agenda_outlined : Icons.view_headline_rounded),
            tooltip: _isCompactView ? 'Genişletilmiş Kart Görünümü' : 'Kompakt Konsol Görünümü',
            onPressed: () {
              setState(() => _isCompactView = !_isCompactView);
            },
          ),
          // Copy All
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Görüntülenen Logları Kopyala',
            onPressed: _copyAllLogs,
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => _loadLogs(),
          ),
          // Desktop Notepad / Explorer options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Daha Fazla Seçenek',
            onSelected: (val) {
              switch (val) {
                case 'notepad':
                  _openLogFileInNotepad();
                  break;
                case 'explorer':
                  _openLogFolderInExplorer();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'notepad',
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Not Defterinde Aç (.jsonl)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'explorer',
                child: Row(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Dosya Konumunu Göster'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Tüm Logları Temizle', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Mesaj veya dosya adında ara...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              },
                            )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _applyFilters();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Level filter tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildLevelFilterTab(
                        label: 'Tümü',
                        count: _allLogs.length,
                        isSelected: _selectedLevel == null,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () {
                          setState(() => _selectedLevel = null);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildLevelFilterTab(
                        label: 'Hata',
                        count: errorCount,
                        isSelected: _selectedLevel == LogLevel.error,
                        color: _getLogLevelColor(LogLevel.error),
                        onTap: () {
                          setState(() => _selectedLevel = LogLevel.error);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildLevelFilterTab(
                        label: 'Uyarı',
                        count: warnCount,
                        isSelected: _selectedLevel == LogLevel.warning,
                        color: _getLogLevelColor(LogLevel.warning),
                        onTap: () {
                          setState(() => _selectedLevel = LogLevel.warning);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildLevelFilterTab(
                        label: 'Bilgi',
                        count: infoCount,
                        isSelected: _selectedLevel == LogLevel.info,
                        color: _getLogLevelColor(LogLevel.info),
                        onTap: () {
                          setState(() => _selectedLevel = LogLevel.info);
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildLevelFilterTab(
                        label: 'Debug',
                        count: debugCount,
                        isSelected: _selectedLevel == LogLevel.debug,
                        color: _getLogLevelColor(LogLevel.debug),
                        onTap: () {
                          setState(() => _selectedLevel = LogLevel.debug);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Logs Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                ? _buildEmptyState(isDark)
                : _isCompactView
                ? _buildTerminalView(isDark, borderColor)
                : _buildCardView(isDark, borderColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelFilterTab({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.25) : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPACT TERMINAL VIEW ---
  Widget _buildTerminalView(bool isDark, Color borderColor) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _filteredLogs.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: borderColor.withValues(alpha: 0.4),
        ),
        itemBuilder: (context, index) {
          final log = _filteredLogs[index];
          final color = _getLogLevelColor(log.level);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showLogDetails(log),
              onLongPress: () => _copyLog(log),
              hoverColor: color.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timestamp
                    Text(
                      _formatTimeOnly(log.timestamp),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Level badge
                    Container(
                      width: 54,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Text(
                        log.level.name.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Caller info pill
                    if (log.callerInfo.isNotEmpty && log.callerInfo != 'unknown')
                      Container(
                        constraints: const BoxConstraints(maxWidth: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.callerInfo.split('(').first.trim(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(width: 10),
                    // Log Message
                    Expanded(
                      child: Text(
                        log.message,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.35,
                          color: log.level == LogLevel.error
                              ? Colors.redAccent
                              : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Inline Copy Action
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: 'Kopyala',
                      color: Colors.grey,
                      onPressed: () => _copyLog(log),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- EXPANDED CARD VIEW ---
  Widget _buildCardView(bool isDark, Color borderColor) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredLogs.length,
        itemBuilder: (context, index) {
          final log = _filteredLogs[index];
          final color = _getLogLevelColor(log.level);
          final icon = _getLogLevelIcon(log.level);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: color.withValues(alpha: 0.25), width: 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showLogDetails(log),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: color),
                              const SizedBox(width: 4),
                              Text(
                                log.level.name.toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatFullDateTime(log.timestamp),
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          log.callerInfo.split('(').first.trim(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.blueAccent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      log.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 56,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            _allLogs.isEmpty ? Language.get('noLogs') : 'Arama kriterlerine uygun log bulunamadı.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedLevel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Filtreleri Temizle'),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedLevel = null;
                  _searchController.clear();
                  _applyFilters();
                });
              },
            ),
          ],
        ],
      ),
    );
  }
}
