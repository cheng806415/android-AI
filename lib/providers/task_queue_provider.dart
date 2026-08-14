import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/generation_config.dart';
import '../models/generation_task.dart';
import '../providers/generation_provider.dart';
import '../services/log_service.dart';
import '../services/storage_service.dart';

/// 单并发、可持久化的图片生成任务调度器。
class TaskQueueProvider extends ChangeNotifier {
  final StorageService _storage;
  final GenerationProvider _generation;
  final LogService _logService;
  final _uuid = const Uuid();
  final List<GenerationTask> _tasks = [];
  bool _isProcessing = false;
  Timer? _retryTimer;

  TaskQueueProvider(this._storage, this._generation, this._logService) {
    restore();
  }

  List<GenerationTask> get tasks => List.unmodifiable(_tasks.reversed);
  bool get isProcessing => _isProcessing;
  int get pendingCount => _tasks.where((task) => !task.isFinished).length;

  Future<void> restore() async {
    final restored = await _storage.getTasks();
    final now = DateTime.now();
    _tasks
      ..clear()
      ..addAll(restored.map((task) {
        if (task.status == TaskStatus.running) {
          return task.copyWith(status: TaskStatus.queued, updatedAt: now);
        }
        return task;
      }));
    for (final task
        in _tasks.where((task) => task.status == TaskStatus.queued)) {
      await _storage.saveTask(task);
    }
    notifyListeners();
    _scheduleProcessing();
  }

  Future<String> enqueue(GenerationConfig config, {String? providerId}) async {
    final now = DateTime.now();
    final task = GenerationTask(
      id: _uuid.v4(),
      config: config,
      providerId: providerId,
      createdAt: now,
      updatedAt: now,
    );
    _tasks.add(task);
    await _storage.saveTask(task);
    await _logService.info('TaskQueue', '任务已加入队列',
        details: 'taskId=${task.id}');
    notifyListeners();
    _scheduleProcessing();
    return task.id;
  }

  Future<void> cancel(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    final task = _tasks[index];
    if (task.status == TaskStatus.running) _generation.cancelGeneration();
    final updated = task.copyWith(
      status: TaskStatus.cancelled,
      updatedAt: DateTime.now(),
      clearRetry: true,
    );
    _tasks[index] = updated;
    await _storage.saveTask(updated);
    notifyListeners();
  }

  Future<void> retry(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    final updated = _tasks[index].copyWith(
      status: TaskStatus.queued,
      updatedAt: DateTime.now(),
      clearError: true,
      clearRetry: true,
    );
    _tasks[index] = updated;
    await _storage.saveTask(updated);
    notifyListeners();
    _scheduleProcessing();
  }

  Future<void> clearFinished() async {
    _tasks.removeWhere((task) => task.isFinished);
    await _storage.clearFinishedTasks();
    notifyListeners();
  }

  void _scheduleProcessing() {
    if (_isProcessing) return;
    _retryTimer?.cancel();
    final next = _tasks
        .where((task) => task.status == TaskStatus.retryWaiting)
        .fold<DateTime?>(
          null,
          (earliest, task) =>
              earliest == null || task.nextRetryAt!.isBefore(earliest)
                  ? task.nextRetryAt
                  : earliest,
        );
    if (_tasks.any((task) => task.status == TaskStatus.queued)) {
      unawaited(_processNext());
    } else if (next != null) {
      _retryTimer = Timer(
          next.difference(DateTime.now()).isNegative
              ? Duration.zero
              : next.difference(DateTime.now()),
          _promoteRetries);
    }
  }

  Future<void> _promoteRetries() async {
    final now = DateTime.now();
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status == TaskStatus.retryWaiting &&
          !task.nextRetryAt!.isAfter(now)) {
        _tasks[i] = task.copyWith(
            status: TaskStatus.queued, updatedAt: now, clearRetry: true);
        await _storage.saveTask(_tasks[i]);
      }
    }
    notifyListeners();
    _scheduleProcessing();
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    final index = _tasks.indexWhere((task) => task.status == TaskStatus.queued);
    if (index < 0) return;
    _isProcessing = true;
    var task = _tasks[index].copyWith(
        status: TaskStatus.running,
        updatedAt: DateTime.now(),
        clearError: true);
    _tasks[index] = task;
    await _storage.saveTask(task);
    notifyListeners();

    try {
      await _generation.generateImage(task.config);
      if (_tasks[index].status == TaskStatus.cancelled) {
        return;
      }

      if (_generation.status == GenerationStatus.success) {
        task = task.copyWith(
          status: TaskStatus.succeeded,
          resultPaths: _generation.lastGeneratedImages
              .map((image) => image.localPath)
              .toList(),
          updatedAt: DateTime.now(),
          clearError: true,
        );
      } else {
        final message = _generation.errorMessage ?? '未知错误';
        final attempt = task.attempt + 1;
        if (_isRetryable(message) && attempt < task.maxAttempts) {
          final delay = const [
            Duration(seconds: 2),
            Duration(seconds: 5),
            Duration(seconds: 15)
          ][attempt - 1];
          task = task.copyWith(
            status: TaskStatus.retryWaiting,
            attempt: attempt,
            errorMessage: message,
            errorCode: 'retryable',
            nextRetryAt: DateTime.now().add(delay),
            updatedAt: DateTime.now(),
          );
        } else {
          task = task.copyWith(
            status: TaskStatus.failed,
            attempt: attempt,
            errorMessage: message,
            errorCode: 'generation_failed',
            updatedAt: DateTime.now(),
          );
        }
      }
      _tasks[index] = task;
      await _storage.saveTask(task);
    } catch (error) {
      final message = error.toString();
      task = task.copyWith(
        status: TaskStatus.failed,
        attempt: task.attempt + 1,
        errorMessage: message,
        errorCode: 'generation_exception',
        updatedAt: DateTime.now(),
      );
      _tasks[index] = task;
      await _storage.saveTask(task);
      await _logService.error('TaskQueue', '任务执行异常', error: message);
    } finally {
      _isProcessing = false;
      notifyListeners();
      _scheduleProcessing();
    }
  }

  bool _isRetryable(String message) {
    final value = message.toLowerCase();
    return [
      'timeout',
      'timed out',
      'socket',
      'connection',
      'network',
      'http 408',
      'http 429',
      'http 500',
      'http 502',
      'http 503',
      'http 504',
      '超时',
      '网络'
    ].any(value.contains);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
