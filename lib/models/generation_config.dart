/// 图片生成配置模型
class GenerationConfig {
  final String prompt;
  final String model;
  final String size;
  final String quality;
  final int count;
  final String outputFormat;
  final String? referenceImagePath;

  const GenerationConfig({
    required this.prompt,
    this.model = 'gpt-image-2',
    this.size = '1024x1024',
    this.quality = 'high',
    this.count = 1,
    this.outputFormat = 'png',
    this.referenceImagePath,
  });

  /// 是否有参考图片（图片编辑模式）
  bool get hasReferenceImage =>
      referenceImagePath != null && referenceImagePath!.isNotEmpty;

  /// 可用的模型列表
  static const List<String> availableModels = [
    'gpt-image-2',
    'gpt-image-1.5',
    'imagen-3.0-generate-002',
    'grok-imagine-image',
  ];

  /// 可用的尺寸列表
  static const List<String> availableSizes = [
    '1024x1024',
    '1536x1024',
    '1024x1536',
    'auto',
  ];

  /// 可用的质量等级
  static const List<String> availableQualities = [
    'high',
    'medium',
    'low',
    'auto',
  ];

  /// 模型显示名称
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

  GenerationConfig copyWith({
    String? prompt,
    String? model,
    String? size,
    String? quality,
    int? count,
    String? outputFormat,
    String? referenceImagePath,
  }) {
    return GenerationConfig(
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      count: count ?? this.count,
      outputFormat: outputFormat ?? this.outputFormat,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
    );
  }
}
