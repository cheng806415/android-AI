import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/generation_config.dart';
import '../models/image_model.dart';
import '../services/api_service.dart';
import '../services/log_service.dart';
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
  final LogService _logService;
  final _uuid = const Uuid();

  GenerationProvider(this._apiService, this._storageService, this._logService);

  // ========== 状态 ==========
  GenerationStatus _status = GenerationStatus.idle;
  GenerationStatus get status => _status;

  String _progressMessage = '';
  String get progressMessage => _progressMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  GeneratedImage? _lastGeneratedImage;
  GeneratedImage? get lastGeneratedImage => _lastGeneratedImage;

  /// 多图生成结果
  List<GeneratedImage> _lastGeneratedImages = [];
  List<GeneratedImage> get lastGeneratedImages => _lastGeneratedImages;

  Uint8List? _currentImageData;
  Uint8List? get currentImageData => _currentImageData;

  List<Uint8List> _currentImageDatas = [];
  List<Uint8List> get currentImageDatas => _currentImageDatas;

  int _generationTimeMs = 0;
  int get generationTimeMs => _generationTimeMs;

  bool get isGenerating =>
      _status == GenerationStatus.preparing ||
      _status == GenerationStatus.generating ||
      _status == GenerationStatus.saving;

  /// 是否生成了多张图片
  bool get hasMultipleImages => _lastGeneratedImages.length > 1;

  /// 取消当前生成任务
  void cancelGeneration() {
    if (!isGenerating) return;
    _apiService.cancelCurrentRequests();
    _status = GenerationStatus.error;
    _errorMessage = '已取消生成';
    _progressMessage = '';
    notifyListeners();
  }

  // ========== 生成图片 ==========
  Future<void> generateImage(GenerationConfig config) async {
    await _logService.info(
      'Generation',
      '开始生成图片',
      details:
          'model=${config.model}, size=${config.size}, count=${config.count}',
    );
    _setStatus(GenerationStatus.preparing);
    _progressMessage = '正在准备生成...';
    _errorMessage = null;
    _currentImageData = null;
    _currentImageDatas = [];
    _lastGeneratedImage = null;
    _lastGeneratedImages = [];

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

      if (result.error == '用户已取消生成' || _apiService.isCancelRequested) {
        _setStatus(GenerationStatus.error);
        _errorMessage = '已取消生成';
        return;
      }

      if (!result.isSuccess) {
        await _logService.error(
          'Generation',
          'API 生成失败',
          error: result.error,
        );
        _setStatus(GenerationStatus.error);
        _errorMessage = result.error ?? '未知错误';
        return;
      }

      await _logService.info(
        'Generation',
        'API 返回结果',
        details:
            'imageCount=${result.imageCount}, urls=${result.allImageUrls.length}, b64s=${result.allBase64Datas.length}',
      );

      // 获取所有图片数据（每张独立处理，单张失败不影响其他）
      final imageDatas = <Uint8List>[];
      int decodeFailed = 0;

      // 从 base64 获取
      for (int i = 0; i < result.allBase64Datas.length; i++) {
        try {
          imageDatas
              .add(ApiService.decodeBase64Image(result.allBase64Datas[i]));
        } catch (e) {
          decodeFailed++;
          await _logService.error(
            'Generation',
            'Base64 解码失败 (第${i + 1}张)',
            error: e,
          );
        }
      }
      // 从 URL 下载
      for (int i = 0; i < result.allImageUrls.length; i++) {
        try {
          _progressMessage =
              '正在下载图片 ${imageDatas.length + 1}/${result.imageCount}...';
          notifyListeners();
          imageDatas
              .add(await _apiService.downloadImage(result.allImageUrls[i]));
        } catch (e) {
          decodeFailed++;
          await _logService.error(
            'Generation',
            '图片下载失败 (第${i + 1}张)',
            error: e,
          );
        }
      }

      await _logService.info(
        'Generation',
        '图片解码完成',
        details: '成功=${imageDatas.length}, 失败=$decodeFailed',
      );

      if (imageDatas.isEmpty) {
        _setStatus(GenerationStatus.error);
        _errorMessage = '无法获取图片数据';
        return;
      }

      _currentImageData = imageDatas.first;
      _currentImageDatas = imageDatas;

      // 保存到本地（每张独立保存）
      _setStatus(GenerationStatus.saving);
      _progressMessage = '正在保存图片...';
      notifyListeners();

      final records = <GeneratedImage>[];
      int saveFailed = 0;
      for (int i = 0; i < imageDatas.length; i++) {
        try {
          _progressMessage = '正在保存图片 ${i + 1}/${imageDatas.length}...';
          notifyListeners();
          final localPath =
              await _storageService.saveImageLocally(imageDatas[i]);
          final record = GeneratedImage(
            id: _uuid.v4(),
            prompt: result.revisedPrompt ?? config.prompt,
            model: config.model,
            size: config.size,
            quality: config.quality,
            group: result.providerName ?? '',
            localPath: localPath,
            createdAt: DateTime.now(),
            generationTimeMs: stopwatch.elapsedMilliseconds,
            count: config.count,
            outputFormat: config.outputFormat,
            referenceImagePath: config.referenceImagePath,
            referenceImagePaths: config.referenceImagePaths,
            schemaVersion: 2,
          );
          await _storageService.saveGenerationRecord(record);
          records.add(record);
        } catch (e) {
          saveFailed++;
          await _logService.error(
            'Generation',
            '保存图片失败 (第${i + 1}张)',
            error: e,
          );
        }
      }

      stopwatch.stop();
      _generationTimeMs = stopwatch.elapsedMilliseconds;

      _lastGeneratedImage = records.isNotEmpty ? records.first : null;
      _lastGeneratedImages = records;

      await _logService.info(
        'Generation',
        '图片生成完成',
        details:
            '生成=${records.length}张, 解码失败=$decodeFailed, 保存失败=$saveFailed, provider=${result.providerName ?? "unknown"}',
      );

      if (records.isEmpty) {
        _setStatus(GenerationStatus.error);
        _errorMessage = '所有图片保存失败';
        return;
      }

      _setStatus(GenerationStatus.success);
    } catch (e, stackTrace) {
      await _logService.error(
        'Generation',
        '生成图片异常',
        error: e,
        stackTrace: stackTrace,
      );
      stopwatch.stop();
      _setStatus(GenerationStatus.error);
      _errorMessage = '生成失败: ${e.toString()}';
    }
  }

  // ========== 图片编辑（多图支持） ==========
  /// 编辑图片 - 支持多张参考图片
  Future<void> editImages(
      GenerationConfig config, List<Uint8List> referenceImages) async {
    if (referenceImages.isEmpty) {
      await generateImage(config);
      return;
    }

    if (referenceImages.length == 1) {
      await editImage(config, referenceImages.first);
      return;
    }

    await _logService.info('Generation', '开始多图编辑',
        details:
            'model=${config.model}, size=${config.size}, referenceCount=${referenceImages.length}');
    _setStatus(GenerationStatus.preparing);
    _progressMessage = '正在准备多图编辑...';
    _errorMessage = null;
    _currentImageData = null;
    _currentImageDatas = [];
    _lastGeneratedImage = null;
    _lastGeneratedImages = [];

    final stopwatch = Stopwatch()..start();

    try {
      _setStatus(GenerationStatus.generating);

      // 保存所有参考图片到临时位置
      final refPaths = <String>[];
      for (int i = 0; i < referenceImages.length; i++) {
        final path = await _storageService.saveImageLocally(referenceImages[i],
            extension: 'png');
        refPaths.add(path);
      }

      final editConfig = config.copyWith(
        referenceImagePath: refPaths.first,
        referenceImagePaths: refPaths.length > 1 ? refPaths.sublist(1) : [],
      );

      final result = await _apiService.generateImage(
        editConfig,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
      );

      if (!result.isSuccess) {
        await _logService.error(
          'Generation',
          'API 多图编辑失败',
          error: result.error,
        );
        _setStatus(GenerationStatus.error);
        _errorMessage = result.error ?? '未知错误';
        return;
      }

      await _processAndSaveResults(result, config, stopwatch);
    } catch (e, stackTrace) {
      await _logService.error(
        'Generation',
        '多图编辑异常',
        error: e,
        stackTrace: stackTrace,
      );
      stopwatch.stop();
      _setStatus(GenerationStatus.error);
      _errorMessage = '编辑失败: ${e.toString()}';
    }
  }

  /// 处理并保存 API 返回结果（editImage 和 editImages 共用）
  Future<void> _processAndSaveResults(
    dynamic result,
    GenerationConfig config,
    Stopwatch stopwatch,
  ) async {
    // 获取所有图片数据（每张独立处理）
    final imageDatas = <Uint8List>[];
    int decodeFailed = 0;
    for (int i = 0; i < result.allBase64Datas.length; i++) {
      try {
        imageDatas.add(ApiService.decodeBase64Image(result.allBase64Datas[i]));
      } catch (e) {
        decodeFailed++;
        await _logService.error('Generation', 'Base64 解码失败 (第${i + 1}张)',
            error: e);
      }
    }
    for (int i = 0; i < result.allImageUrls.length; i++) {
      try {
        imageDatas.add(await _apiService.downloadImage(result.allImageUrls[i]));
      } catch (e) {
        decodeFailed++;
        await _logService.error('Generation', '图片下载失败 (第${i + 1}张)', error: e);
      }
    }

    if (imageDatas.isEmpty) {
      _setStatus(GenerationStatus.error);
      _errorMessage = '无法获取图片数据';
      return;
    }

    _currentImageData = imageDatas.first;
    _currentImageDatas = imageDatas;

    _setStatus(GenerationStatus.saving);

    final records = <GeneratedImage>[];
    int saveFailed = 0;
    for (int i = 0; i < imageDatas.length; i++) {
      try {
        final localPath = await _storageService.saveImageLocally(imageDatas[i]);
        final record = GeneratedImage(
          id: _uuid.v4(),
          prompt: result.revisedPrompt ?? config.prompt,
          model: config.model,
          size: config.size,
          quality: config.quality,
          group: result.providerName ?? '',
          localPath: localPath,
          createdAt: DateTime.now(),
          generationTimeMs: stopwatch.elapsedMilliseconds,
          count: config.count,
          outputFormat: config.outputFormat,
          referenceImagePath: config.referenceImagePath,
          referenceImagePaths: config.referenceImagePaths,
          schemaVersion: 2,
        );
        await _storageService.saveGenerationRecord(record);
        records.add(record);
      } catch (e) {
        saveFailed++;
        await _logService.error('Generation', '保存图片失败 (第${i + 1}张)', error: e);
      }
    }

    stopwatch.stop();
    _generationTimeMs = stopwatch.elapsedMilliseconds;

    _lastGeneratedImage = records.isNotEmpty ? records.first : null;
    _lastGeneratedImages = records;

    await _logService.info(
      'Generation',
      '图片编辑完成',
      details:
          '生成=${records.length}张, 解码失败=$decodeFailed, 保存失败=$saveFailed, provider=${result.providerName ?? "unknown"}',
    );

    if (records.isEmpty) {
      _setStatus(GenerationStatus.error);
      _errorMessage = '所有图片保存失败';
      return;
    }

    _setStatus(GenerationStatus.success);
  }

  // ========== 图片编辑 ==========
  Future<void> editImage(
      GenerationConfig config, Uint8List referenceImage) async {
    await _logService.info('Generation', '开始编辑图片',
        details: 'model=${config.model}, size=${config.size}');
    _setStatus(GenerationStatus.preparing);
    _progressMessage = '正在准备图片编辑...';
    _errorMessage = null;
    _currentImageData = null;
    _currentImageDatas = [];
    _lastGeneratedImage = null;
    _lastGeneratedImages = [];

    final stopwatch = Stopwatch()..start();

    try {
      _setStatus(GenerationStatus.generating);

      // 先保存参考图片到临时位置
      final refPath = await _storageService.saveImageLocally(referenceImage,
          extension: 'png');

      final editConfig = config.copyWith(referenceImagePath: refPath);

      final result = await _apiService.generateImage(
        editConfig,
        onProgress: (msg) {
          _progressMessage = msg;
          notifyListeners();
        },
      );

      if (!result.isSuccess) {
        await _logService.error(
          'Generation',
          'API 图片编辑失败',
          error: result.error,
        );
        _setStatus(GenerationStatus.error);
        _errorMessage = result.error ?? '未知错误';
        return;
      }

      await _processAndSaveResults(result, config, stopwatch);
    } catch (e, stackTrace) {
      await _logService.error(
        'Generation',
        '图片编辑异常',
        error: e,
        stackTrace: stackTrace,
      );
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
    _currentImageDatas = [];
    notifyListeners();
  }
}
