import 'package:flutter/material.dart';

import '../models/update_info.dart';

class UpdateDiagnosticsScreen extends StatelessWidget {
  final UpdateCheckReport? report;
  final String? errorMessage;

  const UpdateDiagnosticsScreen({
    super.key,
    required this.report,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentReport = report;
    return Scaffold(
      appBar: AppBar(title: const Text('更新检查详情')),
      body: currentReport == null
          ? Center(child: Text(errorMessage ?? '暂时没有检查记录'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentReport.success ? '检查完成' : '检查失败',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('总耗时：${currentReport.elapsed.inMilliseconds} ms'),
                        Text('开始时间：${currentReport.startedAt.toLocal()}'),
                        Text('结束时间：${currentReport.finishedAt.toLocal()}'),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('访问记录', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...currentReport.attempts.asMap().entries.map(
                      (entry) =>
                          _buildAttemptCard(theme, entry.key + 1, entry.value),
                    ),
              ],
            ),
    );
  }

  Widget _buildAttemptCard(
    ThemeData theme,
    int index,
    UpdateCheckAttempt attempt,
  ) {
    final color = attempt.success ? Colors.green : theme.colorScheme.error;
    return Card(
      child: ExpansionTile(
        leading: Icon(
          attempt.success ? Icons.check_circle : Icons.error,
          color: color,
        ),
        title: Text('第 $index 个地址'),
        subtitle: Text(
          '${attempt.url}\n${attempt.success ? '成功' : '失败'} · ${attempt.elapsed.inMilliseconds} ms',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detailRow('网址', attempt.url),
          _detailRow('HTTP 状态码', '${attempt.statusCode ?? '未收到响应'}'),
          _detailRow(
            'Content-Type',
            attempt.contentType.isEmpty ? '未收到响应头' : attempt.contentType,
          ),
          _detailRow(
            '响应大小',
            attempt.responseBytes == null
                ? '未知'
                : '${attempt.responseBytes} 字节',
          ),
          _detailRow('耗时', '${attempt.elapsed.inMilliseconds} ms'),
          _detailRow('详细结果', attempt.detail),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SelectableText('$label：$value'),
    );
  }
}
