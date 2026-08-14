import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/generation_task.dart';
import '../providers/task_queue_provider.dart';

/// 查看生成任务的状态、重试时间与错误信息。
class TaskQueueScreen extends StatelessWidget {
  const TaskQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskQueueProvider>(
      builder: (context, queue, _) {
        final tasks = queue.tasks;
        return Scaffold(
          appBar: AppBar(
            title: const Text('任务队列'),
            actions: [
              if (tasks.any((task) => task.isFinished))
                IconButton(
                  tooltip: '清除已完成任务',
                  onPressed: queue.clearFinished,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: tasks.isEmpty
              ? const _EmptyTasks()
              : Column(
                  children: [
                    _QueueSummary(
                      pendingCount: queue.pendingCount,
                      isProcessing: queue.isProcessing,
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _TaskCard(
                          task: tasks[index],
                          onCancel: () => queue.cancel(tasks[index].id),
                          onRetry: () => queue.retry(tasks[index].id),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('暂无生成任务', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '在首页提交生成后，可在这里查看处理状态。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
}

class _QueueSummary extends StatelessWidget {
  final int pendingCount;
  final bool isProcessing;

  const _QueueSummary({required this.pendingCount, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isProcessing ? Icons.sync : Icons.queue_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isProcessing
                  ? '正在处理任务，剩余 $pendingCount 项'
                  : '待处理任务 $pendingCount 项',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final GenerationTask task;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  const _TaskCard({
    required this.task,
    required this.onCancel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _statusVisual(task.status, theme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(visual.icon, size: 20, color: visual.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visual.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: visual.color),
                  ),
                ),
                Text(
                  '${task.config.model} · ${task.config.size}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.config.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _TaskDetail(task: task),
            if (task.errorMessage?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(
                task.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_canCancel(task.status) ||
                task.status == TaskStatus.failed) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_canCancel(task.status))
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('取消'),
                      ),
                    if (task.status == TaskStatus.failed)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重新尝试'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskDetail extends StatelessWidget {
  final GenerationTask task;

  const _TaskDetail({required this.task});

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      '尝试 ${task.attempt}/${task.maxAttempts}',
      '数量 ${task.config.count}',
      if (task.status == TaskStatus.retryWaiting && task.nextRetryAt != null)
        '将在 ${_time(task.nextRetryAt!)} 重试',
      if (task.resultPaths.isNotEmpty) '已保存 ${task.resultPaths.length} 张图片',
    ];
    return Text(
      values.join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

bool _canCancel(TaskStatus status) =>
    status == TaskStatus.queued ||
    status == TaskStatus.running ||
    status == TaskStatus.retryWaiting;

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

_StatusVisual _statusVisual(TaskStatus status, ThemeData theme) {
  switch (status) {
    case TaskStatus.queued:
      return _StatusVisual(
          Icons.schedule_outlined, '排队中', theme.colorScheme.primary);
    case TaskStatus.running:
      return _StatusVisual(Icons.sync, '生成中', theme.colorScheme.primary);
    case TaskStatus.retryWaiting:
      return _StatusVisual(
          Icons.timer_outlined, '等待重试', theme.colorScheme.tertiary);
    case TaskStatus.succeeded:
      return const _StatusVisual(
          Icons.check_circle_outline, '已完成', Colors.green);
    case TaskStatus.failed:
      return _StatusVisual(
          Icons.error_outline, '生成失败', theme.colorScheme.error);
    case TaskStatus.cancelled:
      return _StatusVisual(
          Icons.cancel_outlined, '已取消', theme.colorScheme.outline);
  }
}

class _StatusVisual {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusVisual(this.icon, this.label, this.color);
}
