import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/update_info.dart';

/// 更新检测和 APK 下载服务。
class UpdateService {
  /// 主更新地址：VPS IP 直连 HTTP，绕过 CDN/备案/域名封锁。
  static const String defaultUpdateUrl =
      'http://103.236.70.249:8766/update-config.json';

  /// 备用更新地址列表（按优先级排序，全部失败才报错）。
  static const List<String> fallbackUrls = [
    'https://dreamart.de5.net/update-config.json',
    'https://image-ai.ota8a.cn/update-config.json',
  ];

  final String updateUrl;
  UpdateConfig? _cachedConfig;
  PackageInfo? _packageInfo;
  http.Client _client = http.Client();
  bool _cancelDownloadRequested = false;
  UpdateCheckReport? _lastCheckReport;

  UpdateService({this.updateUrl = defaultUpdateUrl});

  UpdateCheckReport? get lastCheckReport => _lastCheckReport;

  Future<PackageInfo> get packageInfo async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  Future<int> get currentVersionCode async {
    final info = await packageInfo;
    return int.tryParse(info.buildNumber) ?? 1;
  }

  Future<String> get currentVersionName async {
    final info = await packageInfo;
    return info.version;
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final config = await _fetchUpdateConfig();
      if (config == null) return UpdateCheckResult.error('无法连接到更新服务器');

      final currentCode = await currentVersionCode;
      final latestVersion = config.latestVersion;
      final minVersion = config.minSupportedVersion;

      if (currentCode < minVersion.versionCode ||
          (currentCode < latestVersion.versionCode &&
              latestVersion.updateType == UpdateType.major)) {
        return UpdateCheckResult.hasUpdate(
          latestVersion.copyWithForceFlag(true),
        );
      }
      if (currentCode < latestVersion.versionCode) {
        return UpdateCheckResult.hasUpdate(latestVersion);
      }
      return UpdateCheckResult.noUpdate();
    } catch (e) {
      return UpdateCheckResult.error('更新检查失败: $e');
    }
  }

  Future<UpdateConfig?> _fetchUpdateConfig() async {
    final urls = <String>[
      updateUrl,
      ...fallbackUrls,
    ].toSet();
    final attempts = <UpdateCheckAttempt>[];
    final startedAt = DateTime.now();
    Object? lastError;

    for (final url in urls) {
      final attemptStartedAt = DateTime.now();
      try {
        final uri = Uri.parse(url).replace(
          queryParameters: {
            ...Uri.parse(url).queryParameters,
            '_t':
                '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
          },
        );
        final response = await _client.get(
          uri,
          headers: {
            'User-Agent': 'AI-Image-Generator/${await currentVersionName}',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 12));
        final elapsed = DateTime.now().difference(attemptStartedAt);
        final contentType = response.headers['content-type'] ?? '';
        final bodyPreview =
            response.body.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (response.statusCode != 200) {
          throw Exception(
            'HTTP ${response.statusCode}，Content-Type: $contentType，响应: ${bodyPreview.substring(0, min(bodyPreview.length, 240))}',
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic> ||
            !decoded.containsKey('latestVersion')) {
          throw const FormatException(
            '响应不是包含 latestVersion 的 JSON object',
          );
        }

        final map = decoded;
        _cachedConfig = UpdateConfig.fromMap(map);
        attempts.add(
          UpdateCheckAttempt.success(
            url: url,
            statusCode: response.statusCode,
            contentType: contentType,
            responseBytes: response.bodyBytes.length,
            elapsed: elapsed,
            detail:
                '解析成功，latestVersion=${_cachedConfig!.latestVersion.versionName}, versionCode=${_cachedConfig!.latestVersion.versionCode}',
          ),
        );
        _lastCheckReport = UpdateCheckReport(
          startedAt: startedAt,
          finishedAt: DateTime.now(),
          attempts: attempts,
          success: true,
        );
        return _cachedConfig;
      } catch (e) {
        final elapsed = DateTime.now().difference(attemptStartedAt);
        lastError = e;
        attempts.add(
          UpdateCheckAttempt.failure(
            url: url,
            elapsed: elapsed,
            detail: '$e',
          ),
        );
      }
    }

    _lastCheckReport = UpdateCheckReport(
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      attempts: attempts,
      success: false,
    );
    if (lastError != null) {
      throw Exception('所有更新地址均请求失败，最后一次失败原因: $lastError');
    }
    return null;
  }

  /// 下载 APK 到应用专属缓存目录，并校验 SHA-256。
  /// 采用分段 Range 下载和失败重试，避免大文件在单次连接中超时。
  Future<File> downloadApk(
    VersionInfo version, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (version.apkUrl.isEmpty) throw Exception('更新包地址为空');

    _cancelDownloadRequested = false;
    final directory = await getTemporaryDirectory();
    final apkFile =
        File('${directory.path}/ai_image_generator_${version.versionName}.apk');
    final tempFile = File('${apkFile.path}.download');
    final chunkSize = 1024 * 1024;
    final maxAttempts = 5;
    var received = await tempFile.exists() ? await tempFile.length() : 0;
    var total = 0;

    try {
      while (true) {
        if (_cancelDownloadRequested) {
          throw const UpdateDownloadCancelledException();
        }

        var completed = false;
        Object? lastError;
        for (var attempt = 1; attempt <= maxAttempts && !completed; attempt++) {
          http.Client? requestClient;
          try {
            requestClient = http.Client();
            final end = received + chunkSize - 1;
            final request = http.Request('GET', Uri.parse(version.apkUrl));
            request.headers['Range'] = 'bytes=$received-$end';
            request.headers['Accept-Encoding'] = 'identity';
            final response = await requestClient.send(request).timeout(
                  const Duration(seconds: 45),
                );

            if (response.statusCode != 206 &&
                !(response.statusCode == 200 && received == 0)) {
              throw Exception('APK 分段下载失败，HTTP ${response.statusCode}');
            }

            final contentRange = response.headers['content-range'];
            if (received > 0 &&
                (response.statusCode != 206 || contentRange == null)) {
              throw Exception('服务器不支持断点续传');
            }
            if (contentRange != null) {
              final match = RegExp(r'/([0-9]+)').firstMatch(contentRange);
              if (match != null) total = int.parse(match.group(1)!);
            }
            total =
                total > 0 ? total : (response.contentLength ?? 0) + received;

            final sink = tempFile.openWrite(
              mode: received == 0 ? FileMode.write : FileMode.append,
            );
            try {
              await for (final chunk in response.stream.timeout(
                const Duration(seconds: 45),
              )) {
                if (_cancelDownloadRequested) {
                  throw const UpdateDownloadCancelledException();
                }
                sink.add(chunk);
                received += chunk.length;
                onProgress?.call(received, total);
              }
            } finally {
              await sink.close();
            }
            completed = true;
          } catch (e) {
            lastError = e;
            if (e is UpdateDownloadCancelledException) rethrow;
            await Future<void>.delayed(Duration(seconds: attempt));
          } finally {
            requestClient?.close();
          }
        }

        if (!completed) {
          throw Exception('APK 下载失败，已重试 $maxAttempts 次: $lastError');
        }
        if (total > 0 && received >= total) break;
        if (total == 0) break;
      }

      if (!await tempFile.exists() || received == 0) {
        throw Exception('APK 下载结果为空');
      }
      final expected = (version.apkSha256 ?? '').trim().toLowerCase();
      if (expected.isNotEmpty) {
        final actual =
            (await sha256.bind(tempFile.openRead()).first).toString();
        if (actual != expected) {
          throw Exception('APK 校验失败，文件可能已损坏或被篡改');
        }
      }
      if (await apkFile.exists()) await apkFile.delete();
      await tempFile.rename(apkFile.path);
      return apkFile;
    } catch (_) {
      rethrow;
    }
  }

  void cancelDownload() {
    _cancelDownloadRequested = true;
    _client.close();
    _client = http.Client();
  }

  Future<void> deleteDownloadedApk(File apk) async {
    if (await apk.exists()) await apk.delete();
  }

  UpdateConfig? get cachedConfig => _cachedConfig;
}

class UpdateDownloadCancelledException implements Exception {
  const UpdateDownloadCancelledException();

  @override
  String toString() => '用户已取消 APK 下载';
}
