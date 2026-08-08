import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/generation_config.dart';
import '../models/image_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// 生成状态枚举
enum GenerationStatus {
  idle,
  preparing,
  generating,
  saving,
  success,
  error,
}

/// 图片生成状态管理
class GenerationProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  final _uuid = const Uuid();

  GenerationProvider(this._apiService, this._storageService);

  // ========== 状态 ==========
  GenerationStatus _status = GenerationStatus.idle;
  GenerationStatus get status => _status;

  String _progressMessage = '';
  String get progressMessage => _progressMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  GeneratedImage? _lastGeneratedImage;
  GeneratedImage? get lastGeneratedImage => _lastGeneratedImage;

  Uint8List? _currentImageData;
  Uint8List? get currentImageData => _currentImageData;

  int _generationTimeMs = 0;
  int get generationTimeMs => _generationTimeMs;

  bool get isGenerating =>
      _status == GenerationStatus.preparing ||
      _status == GenerationStatus.generating ||
      _status == GenerationStatus.saving;

  // ========== 生成图片 ==========
  Future<void> generateImage(GenerationConfig config) async {
    _setStatus(GenerationStatus.preparing);
    _progressMessage = '正在准备生成...';
    _errorMessage = null;
    _currentImageData = null;
    _lastGeneratedImage = null;

    final stopwatch = Stopwatch()..start();

    try {
      _setStatus(GenerationStatus.generating);

      // 调用 API 生成图片
      final result = await _apiService.generateImage(
        config,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
      );

      if (!result.isSuccess) {
        _setStatus(GenerationStatus.error);
        _errorMessage = result.error ?? '未知错误';
        return;
      }

      // 获取图片数据
      Uint8List imageData;
      if (result.hasBase64) {
        imageData = ApiService.decodeBase64Image(result.base64Data!);
      } else if (result.hasUrl) {
        imageData = await _apiService.downloadImage(result.imageUrl!);
      } else {
        _setStatus(GenerationStatus.error);
        _errorMessage = '无法获取图片数据';
        return;
      }

      _currentImageData = imageData;

      // 保存到本地
      _setStatus(GenerationStatus.saving);
      _progressMessage = '正在保存图片...';
      notifyListeners();

      final localPath = await _storageService.saveImageLocally(imageData);

      stopwatch.stop();
      _generationTimeMs = stopwatch.elapsedMilliseconds;

      // 保存记录
      final record = GeneratedImage(
        id: _uuid.v4(),
        prompt: result.revisedPrompt ?? config.prompt,
        model: config.model,
        size: config.size,
        quality: config.quality,
        group: '', // 由 API 服务内部决定
        localPath: localPath,
        createdAt: DateTime.now(),
        generationTimeMs: _generationTimeMs,
      );

      await _storageService.saveGenerationRecord(record);

      _lastGeneratedImage = record;
      _setStatus(GenerationStatus.success);
    } catch (e) {
      stopwatch.stop();
      _setStatus(GenerationStatus.error);
      _errorMessage = '生成失败: ${e.toString()}';
    }
  }

  // ========== 图片编辑 ==========
  Future<void> editImage(
      GenerationConfig config, Uint8List referenceImage) async {
    _setStatus(GenerationStatus.preparing);
    _progressMessage = '正在准备图片编辑...';
    _errorMessage = null;
    _currentImageData = null;
    _lastGeneratedImage = null;

    final stopwatch = Stopwatch()..start();

    try {
      _setStatus(GenerationStatus.generating);

      // 先保存参考图片到临时位置
      final refPath =
          await _storageService.saveImageLocally(referenceImage, extension: 'png');

      final editConfig = config.copyWith(referenceImagePath: refPath);

      final result = await _apiService.generateImage(
        editConfig,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
      );

      if (!result.isSuccess) {
        _setStatus(GenerationStatus.error);
        _errorMessage = result.error ?? '未知错误';
        return;
      }

      Uint8List imageData;
      if (result.hasBase64) {
        imageData = ApiService.decodeBase64Image(result.base64Data!);
      } else if (result.hasUrl) {
        imageData = await _apiService.downloadImage(result.imageUrl!);
      } else {
        _setStatus(GenerationStatus.error);
        _errorMessage = '无法获取图片数据';
        return;
      }

      _currentImageData = imageData;

      _setStatus(GenerationStatus.saving);
      final localPath = await _storageService.saveImageLocally(imageData);

      stopwatch.stop();
      _generationTimeMs = stopwatch.elapsedMilliseconds;

      final record = GeneratedImage(
        id: _uuid.v4(),
        prompt: result.revisedPrompt ?? config.prompt,
        model: config.model,
        size: config.size,
        quality: config.quality,
        group: '',
        localPath: localPath,
        createdAt: DateTime.now(),
        generationTimeMs: _generationTimeMs,
      );

      await _storageService.saveGenerationRecord(record);
      _lastGeneratedImage = record;
      _setStatus(GenerationStatus.success);
    } catch (e) {
      stopwatch.stop();
      _setStatus(GenerationStatus.error);
      _errorMessage = '编辑失败: ${e.toString()}';
    }
  }

  // ========== 状态管理 ==========
  void _setStatus(GenerationStatus status) {
    _status = status;
    notifyListeners();
  }

  void reset() {
    _status = GenerationStatus.idle;
    _progressMessage = '';
    _errorMessage = null;
    _currentImageData = null;
    notifyListeners();
  }
}
