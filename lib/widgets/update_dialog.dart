import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';

/// 更新弹窗，负责下载、校验并调用系统安装 APK。
class UpdateDialog extends StatefulWidget {
  final VersionInfo versionInfo;

  const UpdateDialog({super.key, required this.versionInfo});

  static Future<bool?> show(BuildContext context, VersionInfo versionInfo) {
    return showDialog<bool>(
      context: context,
      barrierDismissible:
          versionInfo.updateType != UpdateType.major && !versionInfo.isForced,
      builder: (_) => UpdateDialog(versionInfo: versionInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();
  double? _progress;
  String _status = '';
  bool _downloading = false;
  File? _downloadedApk;

  VersionInfo get versionInfo => widget.versionInfo;
  bool get _isForced =>
      versionInfo.updateType == UpdateType.major || versionInfo.isForced;

  @override
  void dispose() {
    if (_downloading) _updateService.cancelDownload();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_isForced && !_downloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: _buildHeader(theme),
        content: _buildContent(theme),
        actions: _buildActions(theme),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final config = _updateConfig;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Icon(config.icon, color: config.color, size: 44),
          const SizedBox(height: 12),
          Text('发现新版本',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('v${versionInfo.versionName}  ${config.label}',
              style: theme.textTheme.labelLarge?.copyWith(color: config.color)),
          if (versionInfo.apkSize.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('安装包大小: ${versionInfo.apkSize}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('更新内容',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Text(
              versionInfo.changelog.isEmpty ? '无更新日志' : versionInfo.changelog,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ),
        if (_downloading || _status.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (_progress != null) LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text(_status, style: theme.textTheme.bodySmall),
        ],
        if (_isForced) ...[
          const SizedBox(height: 12),
          Text(
            '此版本必须更新后才能继续使用。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(ThemeData theme) {
    if (_downloading) {
      return [
        TextButton(
          onPressed: _cancelDownload,
          child: const Text('取消下载'),
        ),
      ];
    }

    return [
      if (!_isForced)
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
              versionInfo.updateType == UpdateType.minor ? '稍后更新' : '暂不更新'),
        ),
      FilledButton.icon(
        onPressed: _startDownload,
        icon: Icon(_downloadedApk == null
            ? Icons.download_rounded
            : Icons.install_mobile),
        label: Text(_downloadedApk == null ? '下载并安装' : '立即安装'),
        style: FilledButton.styleFrom(
          backgroundColor: _updateConfig.color,
          foregroundColor: Colors.white,
        ),
      ),
    ];
  }

  Future<void> _startDownload() async {
    if (_downloadedApk != null) {
      await _installApk(_downloadedApk!);
      return;
    }

    setState(() {
      _downloading = true;
      _progress = null;
      _status = '正在下载更新包...';
    });

    try {
      final apk = await _updateService.downloadApk(
        versionInfo,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : null;
            _status = total > 0
                ? '正在下载 ${(received / 1024 / 1024).toStringAsFixed(1)} / ${(total / 1024 / 1024).toStringAsFixed(1)} MB'
                : '正在下载 ${(received / 1024 / 1024).toStringAsFixed(1)} MB';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadedApk = apk;
        _progress = 1;
        _status = '下载完成，SHA-256 校验通过';
      });
      await _installApk(apk);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _installApk(File apk) async {
    try {
      await const MethodChannel('com.example.ai_image_generator/dcim')
          .invokeMethod(
        'installApk',
        {'apkPath': apk.path},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '无法启动安装: ${e.toString()}');
    }
  }

  void _cancelDownload() {
    _updateService.cancelDownload();
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _progress = null;
      _status = '已取消下载';
    });
  }

  _UpdateTypeConfig get _updateConfig {
    switch (versionInfo.updateType) {
      case UpdateType.major:
        return const _UpdateTypeConfig(
            Colors.red, Icons.system_update, '大版本更新');
      case UpdateType.minor:
        return const _UpdateTypeConfig(
            Colors.orange, Icons.new_releases, '中版本更新');
      case UpdateType.patch:
        return const _UpdateTypeConfig(
            Colors.blue, Icons.auto_fix_high, '小版本更新');
    }
  }
}

class _UpdateTypeConfig {
  final Color color;
  final IconData icon;
  final String label;

  const _UpdateTypeConfig(this.color, this.icon, this.label);
}

extension UpdateDialogExtension on BuildContext {
  Future<bool?> showUpdateDialog(VersionInfo versionInfo) =>
      UpdateDialog.show(this, versionInfo);
}
