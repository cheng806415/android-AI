/// 生成的图片记录模型
class GeneratedImage {
  final String id;
  final String prompt;
  final String model;
  final String size;
  final String quality;
  final String group;
  final String localPath;
  final DateTime createdAt;
  final int generationTimeMs;

  const GeneratedImage({
    required this.id,
    required this.prompt,
    required this.model,
    required this.size,
    required this.quality,
    required this.group,
    required this.localPath,
    required this.createdAt,
    this.generationTimeMs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'model': model,
      'size': size,
      'quality': quality,
      'group': group,
      'localPath': localPath,
      'createdAt': createdAt.toIso8601String(),
      'generationTimeMs': generationTimeMs,
    };
  }

  factory GeneratedImage.fromMap(Map<String, dynamic> map) {
    return GeneratedImage(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      model: map['model'] as String,
      size: map['size'] as String,
      quality: map['quality'] as String,
      group: map['group'] as String,
      localPath: map['localPath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      generationTimeMs: (map['generationTimeMs'] as int?) ?? 0,
    );
  }

  GeneratedImage copyWith({
    String? id,
    String? prompt,
    String? model,
    String? size,
    String? quality,
    String? group,
    String? localPath,
    DateTime? createdAt,
    int? generationTimeMs,
  }) {
    return GeneratedImage(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      model: model ?? this.model,
      size: size ?? this.size,
      quality: quality ?? this.quality,
      group: group ?? this.group,
      localPath: localPath ?? this.localPath,
      createdAt: createdAt ?? this.createdAt,
      generationTimeMs: generationTimeMs ?? this.generationTimeMs,
    );
  }
}
