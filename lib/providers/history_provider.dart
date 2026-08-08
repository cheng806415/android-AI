import 'package:flutter/material.dart';
import '../models/image_model.dart';
import '../services/storage_service.dart';

/// 历史记录状态管理
class HistoryProvider extends ChangeNotifier {
  final StorageService _storageService;

  HistoryProvider(this._storageService);

  List<GeneratedImage> _records = [];
  List<GeneratedImage> get records => _records;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  int _storageBytes = 0;
  int get storageBytes => _storageBytes;

  String get storageSizeDisplay {
    if (_storageBytes < 1024) return '$_storageBytes B';
    if (_storageBytes < 1024 * 1024) {
      return '${(_storageBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (_storageBytes < 1024 * 1024 * 1024) {
      return '${(_storageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(_storageBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 加载所有历史记录
  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _records = await _storageService.getAllRecords();
      _totalCount = _records.length;
      _storageBytes = await _storageService.getStorageSize();
    } catch (e) {
      _records = [];
      _totalCount = 0;
      _storageBytes = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 删除单条记录
  Future<void> deleteRecord(String id) async {
    await _storageService.deleteRecord(id);
    _records.removeWhere((r) => r.id == id);
    _totalCount = _records.length;
    _storageBytes = await _storageService.getStorageSize();
    notifyListeners();
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    await _storageService.clearAllRecords();
    _records = [];
    _totalCount = 0;
    _storageBytes = 0;
    notifyListeners();
  }

  /// 搜索记录
  Future<void> search(String keyword) async {
    if (keyword.isEmpty) {
      await loadHistory();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _records = await _storageService.searchRecords(keyword);
      _totalCount = _records.length;
    } catch (e) {
      _records = [];
      _totalCount = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 刷新存储大小
  Future<void> refreshStorageSize() async {
    _storageBytes = await _storageService.getStorageSize();
    notifyListeners();
  }
}
