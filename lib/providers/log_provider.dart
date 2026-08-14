import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/storage_service.dart';

class LogProvider extends ChangeNotifier {
  final StorageService _storage;

  LogProvider(this._storage);

  List<LogEntry> _logs = [];
  bool _isLoading = false;

  List<LogEntry> get logs => _logs;
  bool get isLoading => _isLoading;

  Future<void> loadLogs() async {
    _isLoading = true;
    notifyListeners();
    try {
      _logs = await _storage.getLogs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearLogs() async {
    await _storage.clearLogs();
    _logs = [];
    notifyListeners();
  }
}
