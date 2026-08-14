import 'package:flutter/material.dart';

/// 错误类别
enum ErrorCategory {
  auth,
  quota,
  model,
  network,
  timeout,
  server,
  format,
  cancel,
  unknown,
}

/// 分类后的错误信息
class ClassifiedError {
  final ErrorCategory category;
  final String title;
  final String message;
  final String? suggestion;

  const ClassifiedError({
    required this.category,
    required this.title,
    required this.message,
    this.suggestion,
  });

  IconData get icon {
    switch (category) {
      case ErrorCategory.auth:
        return Icons.vpn_key_off;
      case ErrorCategory.quota:
        return Icons.credit_card_off;
      case ErrorCategory.model:
        return Icons.model_training;
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.timeout:
        return Icons.timer_off;
      case ErrorCategory.server:
        return Icons.cloud_off;
      case ErrorCategory.format:
        return Icons.broken_image;
      case ErrorCategory.cancel:
        return Icons.cancel;
      case ErrorCategory.unknown:
        return Icons.error_outline;
    }
  }

  Color get color {
    switch (category) {
      case ErrorCategory.auth:
      case ErrorCategory.quota:
        return Colors.orange;
      case ErrorCategory.network:
      case ErrorCategory.timeout:
        return Colors.blueGrey;
      case ErrorCategory.cancel:
        return Colors.grey;
      default:
        return Colors.red;
    }
  }
}

/// 错误分类器 - 将 API 错误信息转为用户友好的提示
class ErrorClassifier {
  /// 分类错误信息
  static ClassifiedError classify(String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return const ClassifiedError(
        category: ErrorCategory.unknown,
        title: '未知错误',
        message: '发生了未知错误，请重试',
        suggestion: '如果问题持续出现，请查看运行日志获取详细信息',
      );
    }

    final lower = errorMessage.toLowerCase();

    // 用户取消
    if (lower.contains('已取消') || lower.contains('cancel')) {
      return const ClassifiedError(
        category: ErrorCategory.cancel,
        title: '已取消生成',
        message: '您已取消当前图片生成任务',
      );
    }

    // 认证/API Key 错误
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid api key') ||
        lower.contains('authentication') ||
        lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('auth')) {
      return const ClassifiedError(
        category: ErrorCategory.auth,
        title: 'API Key 无效',
        message: '当前的 API Key 无效或已过期',
        suggestion: '请前往设置页面检查并重新配置 API Key',
      );
    }

    // 配额不足
    if (lower.contains('402') ||
        lower.contains('insufficient') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('429') ||
        lower.contains('too many requests') ||
        lower.contains('exceeded') ||
        lower.contains('credit') ||
        lower.contains('余额') ||
        lower.contains('扣费') ||
        lower.contains('over quota')) {
      return const ClassifiedError(
        category: ErrorCategory.quota,
        title: '配额不足',
        message: '当前 API Key 的配额已用尽或请求过于频繁',
        suggestion: '请检查 API 账户余额，或稍后再试',
      );
    }

    // 模型不支持
    if (lower.contains('unsupported') ||
        lower.contains('not support') ||
        lower.contains('does not exist') ||
        lower.contains('model')) {
      return const ClassifiedError(
        category: ErrorCategory.model,
        title: '模型不支持',
        message: '当前模型不支持该操作或模型名称不正确',
        suggestion: '请尝试切换其他模型或商家',
      );
    }

    // 网络连接问题
    if (lower.contains('failed host lookup') ||
        lower.contains('dns') ||
        lower.contains('resolve') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('no route') ||
        lower.contains('socket') ||
        lower.contains('网络') ||
        lower.contains('connect') ||
        lower.contains('handshake') ||
        lower.contains('certificate') ||
        lower.contains('unreachable')) {
      return const ClassifiedError(
        category: ErrorCategory.network,
        title: '网络连接失败',
        message: '无法连接到 API 服务器，请检查网络连接',
        suggestion: '请检查网络是否正常，或尝试切换其他商家',
      );
    }

    // 超时
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('time out')) {
      return const ClassifiedError(
        category: ErrorCategory.timeout,
        title: '请求超时',
        message: 'API 请求超时，服务器响应过慢',
        suggestion: '图片生成较慢，请稍后重试，或切换到响应更快的商家',
      );
    }

    // 服务器错误
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('server error') ||
        lower.contains('internal server') ||
        lower.contains('service unavailable') ||
        lower.contains('bad gateway') ||
        lower.contains('gateway timeout')) {
      return const ClassifiedError(
        category: ErrorCategory.server,
        title: '服务器错误',
        message: 'API 服务器暂时出现问题',
        suggestion: '请稍后重试，或切换到其他商家',
      );
    }

    // 格式/参数错误
    if (lower.contains('400') ||
        lower.contains('bad request') ||
        lower.contains('invalid') ||
        lower.contains('format') ||
        lower.contains('parse') ||
        lower.contains('parameter') ||
        lower.contains('argument')) {
      return const ClassifiedError(
        category: ErrorCategory.format,
        title: '请求参数错误',
        message: '发送的请求参数有误',
        suggestion: '请检查生成参数设置，或尝试更换尺寸/模型',
      );
    }

    // 所有商家均失败
    if (lower.contains('所有商家均失败')) {
      return ClassifiedError(
        category: ErrorCategory.server,
        title: '所有商家均失败',
        message: errorMessage,
        suggestion: '请检查各商家的 API Key 是否有效，或稍后重试',
      );
    }

    // 默认
    return ClassifiedError(
      category: ErrorCategory.unknown,
      title: '生成失败',
      message: errorMessage,
      suggestion: '如果问题持续出现，请查看运行日志获取详细信息',
    );
  }
}
