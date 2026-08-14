import 'package:flutter/material.dart';
import '../models/image_model.dart';
import '../services/storage_service.dart';

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

  String? _categoryFilter;
  String? get categoryFilter => _categoryFilter;

  String? _tagFilter;
  String? get tagFilter => _tagFilter;

  List<String> _categories = [];
  List<String> get categories => _categories;

  List<String> _tags = [];
  List<String> get tags => _tags;

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

  Future<void> _loadFilters() async {
    _categories = await _storageService.getCategories();
    _tags = await _storageService.getTags();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return;
    final updated = !_records[index].isFavorite;
    await _storageService.toggleFavorite(id, updated);
    _records[index] = _records[index].copyWith(isFavorite: updated);
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();
    try {
      _records = await _storageService.getFavoriteRecords();
      _totalCount = _records.length;
    } catch (_) {
      _records = [];
      _totalCount = 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _records = await _storageService.getAllRecords();
      _totalCount = _records.length;
      _storageBytes = await _storageService.getStorageSize();
      await _loadFilters();
    } catch (_) {
      _records = [];
      _totalCount = 0;
      _storageBytes = 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> applyFilters({String? category, String? tag}) async {
    _categoryFilter = category;
    _tagFilter = tag;
    _isLoading = true;
    notifyListeners();
    try {
      _records =
          await _storageService.filterRecords(category: category, tag: tag);
      _totalCount = _records.length;
    } catch (_) {
      _records = [];
      _totalCount = 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateMetadata(
    GeneratedImage image, {
    required String title,
    required String category,
    required List<String> tags,
    required String notes,
  }) async {
    await _storageService.updateMetadata(
      id: image.id,
      title: title,
      category: category,
      tags: tags,
      notes: notes,
    );
    final index = _records.indexWhere((record) => record.id == image.id);
    if (index >= 0) {
      _records[index] = image.copyWith(
        title: title,
        category: category,
        tags: tags,
        notes: notes,
      );
      notifyListeners();
    }
    await _loadFilters();
  }

  Future<void> deleteRecord(String id) async {
    await _storageService.deleteRecord(id);
    _records.removeWhere((r) => r.id == id);
    _totalCount = _records.length;
    _storageBytes = await _storageService.getStorageSize();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _storageService.clearAllRecords();
    _records = [];
    _totalCount = 0;
    _storageBytes = 0;
    await _loadFilters();
    notifyListeners();
  }

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
    } catch (_) {
      _records = [];
      _totalCount = 0;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshStorageSize() async {
    _storageBytes = await _storageService.getStorageSize();
    notifyListeners();
  }
}
