import 'package:flutter/material.dart';
import 'package:DiscordStorage/services/logger_service.dart'; // Logger sınıfın
import 'package:DiscordStorage/services/localization_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<String> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      isLoading = true;
    });
    final loadedLogs = await Logger.readLogs();
    setState(() {
      logs = loadedLogs;
      isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    await Logger.clearLogs();
    await _loadLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Language.get('logsCleared'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Language.get('logs')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: Language.get('clearLogs'),
            onPressed: logs.isEmpty ? null : () {
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
                      child: Text(Language.get('confirm')),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : logs.isEmpty
            ? Center(child: Text(Language.get('noLogs')))
            : ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final isError = log.contains('[ERROR]');

            return Card(
              color: isError ? Colors.red[50] : Theme.of(context).cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  log,
                  style: TextStyle(
                    color: isError ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
