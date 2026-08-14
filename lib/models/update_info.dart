/// 更新类型枚举
enum UpdateType {
  patch,
  minor,
  major,
}

/// 版本信息模型
class VersionInfo {
  final String versionName;
  final int versionCode;
  final UpdateType updateType;
  final bool isForced;
  final String apkUrl;
  final String apkSize;
  final String? apkMd5;
  final String? apkSha256;
  final String changelog;

  const VersionInfo({
    required this.versionName,
    required this.versionCode,
    required this.updateType,
    this.isForced = false,
    required this.apkUrl,
    required this.apkSize,
    this.apkMd5,
    this.apkSha256,
    this.changelog = '',
  });

  factory VersionInfo.fromMap(Map<String, dynamic> map) {
    return VersionInfo(
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      updateType: _parseUpdateType(map['updateType'] as String?),
      isForced: map['isForced'] as bool? ?? false,
      apkUrl: map['apkUrl'] as String? ?? '',
      apkSize: _parseString(map['apkSize']),
      apkMd5: _parseNullableString(map['apkMd5']),
      apkSha256: _parseNullableString(map['apkSha256'] ?? map['sha256']),
      changelog: _parseChangelog(map['changelog']),
    );
  }

  static UpdateType _parseUpdateType(String? type) {
    switch (type?.toLowerCase()) {
      case 'major':
        return UpdateType.major;
      case 'minor':
        return UpdateType.minor;
      default:
        return UpdateType.patch;
    }
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static String _parseChangelog(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      return value
          .whereType<String>()
          .toList()
          .asMap()
          .entries
          .map((e) => '${e.key + 1}. ${e.value}')
          .join('\n');
    }
    return value.toString();
  }

  String get updateTypeLabel {
    switch (updateType) {
      case UpdateType.major:
        return '大版本更新';
      case UpdateType.minor:
        return '中版本更新';
      case UpdateType.patch:
        return '小版本更新';
    }
  }

  VersionInfo copyWithForceFlag(bool force) {
    return VersionInfo(
      versionName: versionName,
      versionCode: versionCode,
      updateType: updateType,
      isForced: force,
      apkUrl: apkUrl,
      apkSize: apkSize,
      apkMd5: apkMd5,
      apkSha256: apkSha256,
      changelog: changelog,
    );
  }
}

/// 服务器更新配置模型
class UpdateConfig {
  final String appId;
  final VersionInfo latestVersion;
  final VersionInfo minSupportedVersion;
  final List<VersionHistoryItem> versionHistory;
  final String? updateServerName;
  final String? updateServerContact;

  const UpdateConfig({
    required this.appId,
    required this.latestVersion,
    required this.minSupportedVersion,
    this.versionHistory = const [],
    this.updateServerName,
    this.updateServerContact,
  });

  factory UpdateConfig.fromMap(Map<String, dynamic> map) {
    final latest = map['latestVersion'];
    final minimum = map['minSupportedVersion'];
    final history = map['versionHistory'];
    return UpdateConfig(
      appId: map['appId'] as String? ?? '',
      latestVersion: VersionInfo.fromMap(
        latest is Map ? Map<String, dynamic>.from(latest) : {},
      ),
      minSupportedVersion: VersionInfo.fromMap(
        minimum is Map ? Map<String, dynamic>.from(minimum) : {},
      ),
      versionHistory: history is List
          ? history
              .whereType<Map>()
              .map((e) =>
                  VersionHistoryItem.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      updateServerName: (map['updateServerInfo'] is Map)
          ? (map['updateServerInfo'] as Map)['name'] as String?
          : null,
      updateServerContact: (map['updateServerInfo'] is Map)
          ? (map['updateServerInfo'] as Map)['contact'] as String?
          : null,
    );
  }
}

/// 版本历史记录项
class VersionHistoryItem {
  final String versionName;
  final int versionCode;
  final UpdateType updateType;
  final String releaseDate;
  final String? apkUrl;
  final String? apkSize;
  final String? changelog;

  const VersionHistoryItem({
    required this.versionName,
    required this.versionCode,
    required this.updateType,
    required this.releaseDate,
    this.apkUrl,
    this.apkSize,
    this.changelog,
  });

  factory VersionHistoryItem.fromMap(Map<String, dynamic> map) {
    return VersionHistoryItem(
      versionName: map['versionName'] as String? ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      updateType: VersionInfo._parseUpdateType(map['updateType'] as String?),
      releaseDate: map['releaseDate'] as String? ?? '',
      apkUrl: map['apkUrl'] as String?,
      apkSize: VersionInfo._parseNullableString(map['apkSize']),
      changelog: VersionInfo._parseChangelog(map['changelog']),
    );
  }
}

/// 更新检查结果
class UpdateCheckResult {
  final bool hasUpdate;
  final VersionInfo? newVersion;
  final String? errorMessage;

  const UpdateCheckResult({
    this.hasUpdate = false,
    this.newVersion,
    this.errorMessage,
  });

  factory UpdateCheckResult.noUpdate() => const UpdateCheckResult();

  factory UpdateCheckResult.hasUpdate(VersionInfo version) =>
      UpdateCheckResult(hasUpdate: true, newVersion: version);

  factory UpdateCheckResult.error(String message) =>
      UpdateCheckResult(errorMessage: message);
}

class UpdateCheckAttempt {
  final String url;
  final bool success;
  final int? statusCode;
  final String contentType;
  final int? responseBytes;
  final Duration elapsed;
  final String detail;

  const UpdateCheckAttempt({
    required this.url,
    required this.success,
    required this.statusCode,
    required this.contentType,
    required this.responseBytes,
    required this.elapsed,
    required this.detail,
  });

  const UpdateCheckAttempt.success({
    required this.url,
    required this.statusCode,
    required this.contentType,
    required this.responseBytes,
    required this.elapsed,
    required this.detail,
  }) : success = true;

  const UpdateCheckAttempt.failure({
    required this.url,
    required this.elapsed,
    required this.detail,
  })  : success = false,
        statusCode = null,
        contentType = '',
        responseBytes = null;
}

class UpdateCheckReport {
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<UpdateCheckAttempt> attempts;
  final bool success;

  const UpdateCheckReport({
    required this.startedAt,
    required this.finishedAt,
    required this.attempts,
    required this.success,
  });

  Duration get elapsed => finishedAt.difference(startedAt);
}
