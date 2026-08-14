import 'dart:convert';

/// 图片生成配置模型
class GenerationConfig {
  final String prompt;
  final String model;
  final String size;
  final String quality;
  final int count;
  final String outputFormat;
  final String? referenceImagePath;
  final List<String> referenceImagePaths;

  const GenerationConfig({
    required this.prompt,
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.quality = 'high',
    this.count = 1,
    this.outputFormat = 'png',
    this.referenceImagePath,
    this.referenceImagePaths = const [],
  });

  bool get hasReferenceImage =>
      (referenceImagePath != null && referenceImagePath!.isNotEmpty) ||
      referenceImagePaths.isNotEmpty;

  int get referenceImageCount {
    var count = 0;
    if (referenceImagePath != null && referenceImagePath!.isNotEmpty) count++;
    count += referenceImagePaths.length;
    return count;
  }

  Map<String, dynamic> toMap() => {
        'prompt': prompt,
        'model': model,
        'size': size,
        'quality': quality,
        'count': count,
        'outputFormat': outputFormat,
        'referenceImagePath': referenceImagePath,
        'referenceImagePaths': referenceImagePaths,
      };

  String toJson() => jsonEncode(toMap());

  factory GenerationConfig.fromMap(Map<String, dynamic> map) {
    final paths = (map['referenceImagePaths'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];
    return GenerationConfig(
      prompt: (map['prompt'] as String?) ?? '',
      model: (map['model'] as String?) ?? 'gpt-image-2',
      size: (map['size'] as String?) ?? '1024x1024',
      quality: (map['quality'] as String?) ?? 'high',
      count: (map['count'] as num?)?.toInt() ?? 1,
      outputFormat: (map['outputFormat'] as String?) ?? 'png',
      referenceImagePath: map['referenceImagePath'] as String?,
      referenceImagePaths: paths,
    );
  }

  factory GenerationConfig.fromJson(String value) => GenerationConfig.fromMap(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );

  static const List<String> availableModels = [
    'gpt-image-2',
    'gpt-image-1.5',
    'imagen-3.0-generate-002',
    'grok-imagine-image',
  ];

  static const List<String> availableSizes = [
    '256x256',
    '512x512',
    '768x768',
    '1024x1024',
    '1280x720',
    '1920x1080',
    '720x1280',
    '1080x1920',
    '1536x1024',
    '1024x1536',
    'auto',
  ];

  static const Map<String, List<String>> sizesByRatio = {
    'auto': ['auto'],
    'custom': ['custom'],
    '1:1': ['256x256', '512x512', '768x768', '1024x1024'],
    '3:2': ['1536x1024'],
    '2:3': ['1024x1536'],
    '16:9': ['1280x720', '1920x1080'],
    '9:16': ['720x1280', '1080x1920'],
  };

  static const List<String> aspectRatios = [
    'auto',
    'custom',
    '1:1',
    '3:2',
    '2:3',
    '16:9',
    '9:16'
  ];

  static String ratioForSize(String size) {
    if (size == 'auto') return 'auto';
    for (final entry in sizesByRatio.entries) {
      if (entry.key == 'auto' || entry.key == 'custom') continue;
      if (entry.value.contains(size)) return entry.key;
    }
    return 'custom';
  }

  static String defaultSizeForRatio(String ratio) {
    switch (ratio) {
      case 'auto':
        return 'auto';
      case 'custom':
        return 'custom';
    }
    final sizes = sizesByRatio[ratio];
    return sizes != null && sizes.isNotEmpty ? sizes.last : '1024x1024';
  }

  static const List<String> availableQualities = [
    'high',
    'medium',
    'low',
    'auto'
  ];

  static String modelDisplayName(String model) {
    switch (model) {
      case 'gpt-image-2':
        return 'GPT Image 2';
      case 'gpt-image-1.5':
        return 'GPT Image 1.5';
      case 'imagen-3.0-generate-002':
        return 'Imagen 3.0';
      case 'grok-imagine-image':
        return 'Grok Imagine';
      default:
        return model;
    }
  }

  static String sizeDisplayName(String size) {
    switch (size) {
      case '256x256':
        return '256x256 (小方形)';
      case '512x512':
        return '512x512 (中方型)';
      case '768x768':
        return '768x768 (大方型)';
      case '1024x1024':
        return '1024x1024 (正方形)';
      case '1280x720':
        return '1280x720 (HD 横屏)';
      case '1920x1080':
        return '1920x1080 (FHD 横屏)';
      case '720x1280':
        return '720x1280 (HD 竖屏)';
      case '1080x1920':
        return '1080x1920 (FHD 竖屏)';
      case '1536x1024':
        return '1536x1024 (宽幅 3:2)';
      case '1024x1536':
        return '1024x1536 (高幅 2:3)';
      case 'auto':
        return '自动';
      default:
        return size;
    }
  }

  static String qualityDisplayName(String quality) {
    switch (quality) {
      case 'high':
        return '高质量';
      case 'medium':
        return '中等';
      case 'low':
        return '低质量';
      case 'auto':
        return '自动';
      default:
        return quality;
    }
  }

  GenerationConfig copyWith({
    String? prompt,
    String? model,
    String? size,
    String? quality,
    int? count,
    String? outputFormat,
    String? referenceImagePath,
    List<String>? referenceImagePaths,
  }) {
    return GenerationConfig(
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      count: count ?? this.count,
      outputFormat: outputFormat ?? this.outputFormat,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      referenceImagePaths: referenceImagePaths ?? this.referenceImagePaths,
    );
  }
}
