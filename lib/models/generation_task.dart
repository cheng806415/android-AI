import 'dart:convert';

import 'generation_config.dart';

enum TaskStatus {
  queued,
  running,
  retryWaiting,
  succeeded,
  failed,
  cancelled,
}

class GenerationTask {
  final String id;
  final GenerationConfig config;
  final TaskStatus status;
  final int attempt;
  final int maxAttempts;
  final String? providerId;
  final String? errorCode;
  final String? errorMessage;
  final List<String> resultPaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? nextRetryAt;

  const GenerationTask({
    required this.id,
    required this.config,
    this.status = TaskStatus.queued,
    this.attempt = 0,
    this.maxAttempts = 3,
    this.providerId,
    this.errorCode,
    this.errorMessage,
    this.resultPaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.nextRetryAt,
  });

  bool get isFinished =>
      status == TaskStatus.succeeded ||
      status == TaskStatus.failed ||
      status == TaskStatus.cancelled;

  Map<String, dynamic> toMap() => {
        'id': id,
        'configJson': config.toJson(),
        'status': status.name,
        'attempt': attempt,
        'maxAttempts': maxAttempts,
        'providerId': providerId,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'resultPathsJson': jsonEncode(resultPaths),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'nextRetryAt': nextRetryAt?.toIso8601String(),
      };

  factory GenerationTask.fromMap(Map<String, dynamic> map) {
    final rawPaths = map['resultPathsJson'];
    final paths = rawPaths is String
        ? ((jsonDecode(rawPaths) as List?) ?? const [])
            .map((value) => value.toString())
            .toList()
        : const <String>[];
    final statusName = map['status'] as String? ?? TaskStatus.queued.name;
    return GenerationTask(
      id: map['id'] as String,
      config: GenerationConfig.fromJson(map['configJson'] as String),
      status: TaskStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => TaskStatus.queued,
      ),
      attempt: (map['attempt'] as num?)?.toInt() ?? 0,
      maxAttempts: (map['maxAttempts'] as num?)?.toInt() ?? 3,
      providerId: map['providerId'] as String?,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
      resultPaths: paths,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      nextRetryAt: map['nextRetryAt'] == null
          ? null
          : DateTime.tryParse(map['nextRetryAt'] as String),
    );
  }

  GenerationTask copyWith({
    GenerationConfig? config,
    TaskStatus? status,
    int? attempt,
    int? maxAttempts,
    String? providerId,
    String? errorCode,
    String? errorMessage,
    List<String>? resultPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? nextRetryAt,
    bool clearError = false,
    bool clearRetry = false,
  }) {
    return GenerationTask(
      id: id,
      config: config ?? this.config,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      providerId: providerId ?? this.providerId,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resultPaths: resultPaths ?? this.resultPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: clearRetry ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }
}
