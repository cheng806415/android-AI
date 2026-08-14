import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../providers/log_provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogProvider>().loadLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('运行日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Consumer<LogProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.logs.isEmpty) {
            return const Center(child: Text('暂无运行日志'));
          }
          return RefreshIndicator(
            onRefresh: provider.loadLogs,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _buildLogCard(provider.logs[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(LogEntry entry) {
    final color = _levelColor(entry.level);
    return Card(
      child: ExpansionTile(
        leading: Icon(_levelIcon(entry.level), color: color),
        title: Text(entry.message),
        subtitle: Text(
          '${entry.displayLevel} · ${entry.tag} · ${_formatTime(entry.createdAt)}',
          style: TextStyle(color: color, fontSize: 12),
        ),
        children: [
          if (entry.details != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                entry.details!,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.debug:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warning:
        return Icons.warning_amber_outlined;
      case LogLevel.debug:
        return Icons.bug_report_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  Future<void> _clearLogs() async {
    final provider = context.read<LogProvider>();
    await provider.clearLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日志已清空')),
      );
    }
  }
}
