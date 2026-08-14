import 'package:flutter/foundation.dart';

/// 应用内日志级别
class LogLevel {
  static const debug = 'debug';
  static const info = 'info';
  static const warning = 'warning';
  static const error = 'error';

  const LogLevel._();
}

/// 应用内日志记录
class LogEntry {
  final int? id;
  final String level;
  final String tag;
  final String message;
  final String? details;
  final DateTime createdAt;

  const LogEntry({
    this.id,
    required this.level,
    required this.tag,
    required this.message,
    this.details,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'level': level,
        'tag': tag,
        'message': message,
        'details': details,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LogEntry.fromMap(Map<String, dynamic> map) => LogEntry(
        id: map['id'] as int?,
        level: map['level'] as String? ?? LogLevel.info,
        tag: map['tag'] as String? ?? 'App',
        message: map['message'] as String? ?? '',
        details: map['details'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  String get displayLevel {
    switch (level) {
      case LogLevel.error:
        return '错误';
      case LogLevel.warning:
        return '警告';
      case LogLevel.debug:
        return '调试';
      default:
        return '信息';
    }
  }

  void debugPrintLine() {
    debugPrint('[$level][$tag] $message${details == null ? '' : ' $details'}');
  }
}
