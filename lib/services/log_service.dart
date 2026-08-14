import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import 'storage_service.dart';

/// 统一应用日志服务，不记录 API Key 或 Authorization 内容。
class LogService {
  final StorageService storage;

  LogService(this.storage);

  Future<void> debug(String tag, String message, {String? details}) =>
      _write(LogLevel.debug, tag, message, details: details);

  Future<void> info(String tag, String message, {String? details}) =>
      _write(LogLevel.info, tag, message, details: details);

  Future<void> warning(String tag, String message, {String? details}) =>
      _write(LogLevel.warning, tag, message, details: details);

  Future<void> error(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      _write(
        LogLevel.error,
        tag,
        message,
        details: _formatDetails(error, stackTrace),
      );

  Future<void> _write(String level, String tag, String message,
      {String? details}) async {
    final safeDetails = _truncate(details);
    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      details: safeDetails,
      createdAt: DateTime.now(),
    );
    if (kDebugMode) entry.debugPrintLine();
    await storage.insertLog(entry);
  }

  String? _formatDetails(Object? error, StackTrace? stackTrace) {
    if (error == null && stackTrace == null) return null;
    final buffer = StringBuffer();
    if (error != null) buffer.writeln(error);
    if (stackTrace != null) buffer.write(stackTrace);
    return buffer.toString().trim();
  }

  String? _truncate(String? value) {
    if (value == null || value.isEmpty) return null;
    const maxLength = 4000;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}\n[日志已截断]';
  }
}
