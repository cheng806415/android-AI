import 'package:flutter/material.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';

/// 更新状态
enum UpdateCheckStatus {
  idle, // 初始状态
  checking, // 正在检查
  noUpdate, // 无更新
  hasUpdate, // 有更新
  error, // 检查失败
}

/// 更新检测状态管理
class UpdateProvider extends ChangeNotifier {
  final UpdateService _service;

  UpdateProvider(this._service);

  UpdateCheckStatus _status = UpdateCheckStatus.idle;
  UpdateCheckStatus get status => _status;

  UpdateCheckResult? _checkResult;
  UpdateCheckResult? get checkResult => _checkResult;

  VersionInfo? get newVersion => _checkResult?.newVersion;
  bool get hasUpdate => _checkResult?.hasUpdate ?? false;
  bool get isForced => _checkResult?.newVersion?.isForced ?? false;
  UpdateType? get updateType => _checkResult?.newVersion?.updateType;
  String? get errorMessage => _checkResult?.errorMessage;
  UpdateCheckReport? get checkReport => _service.lastCheckReport;

  /// 更新弹窗是否已显示过（本次会话）
  bool _dialogShown = false;
  bool get dialogShown => _dialogShown;

  /// 检查更新
  Future<void> checkForUpdate() async {
    _status = UpdateCheckStatus.checking;
    notifyListeners();

    _checkResult = await _service.checkForUpdate();

    if (_checkResult == null) {
      _status = UpdateCheckStatus.error;
    } else if (_checkResult!.hasUpdate) {
      _status = UpdateCheckStatus.hasUpdate;
    } else if (_checkResult!.errorMessage != null) {
      _status = UpdateCheckStatus.error;
    } else {
      _status = UpdateCheckStatus.noUpdate;
    }

    notifyListeners();
  }

  /// 标记弹窗已显示
  void markDialogShown() {
    _dialogShown = true;
    notifyListeners();
  }

  /// 重置状态
  void reset() {
    _status = UpdateCheckStatus.idle;
    _checkResult = null;
    _dialogShown = false;
    notifyListeners();
  }
}
