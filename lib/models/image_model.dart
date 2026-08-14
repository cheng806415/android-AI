import 'dart:convert';

import 'generation_config.dart';

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
  final bool isFavorite;
  final int count;
  final String outputFormat;
  final String? referenceImagePath;
  final List<String> referenceImagePaths;
  final String? providerId;
  final int schemaVersion;
  final String? parentRecordId;
  final String title;
  final String category;
  final List<String> tags;
  final String notes;

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
    this.isFavorite = false,
    this.count = 1,
    this.outputFormat = 'png',
    this.referenceImagePath,
    this.referenceImagePaths = const [],
    this.providerId,
    this.schemaVersion = 1,
    this.parentRecordId,
    this.title = '',
    this.category = '',
    this.tags = const [],
    this.notes = '',
  });

  GenerationConfig get generationConfig => GenerationConfig(
        prompt: prompt,
        model: model,
        size: size,
        quality: quality,
        count: count,
        outputFormat: outputFormat,
        referenceImagePath: referenceImagePath,
        referenceImagePaths: referenceImagePaths,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt': prompt,
        'model': model,
        'size': size,
        'quality': quality,
        'group': group,
        'localPath': localPath,
        'createdAt': createdAt.toIso8601String(),
        'generationTimeMs': generationTimeMs,
        'isFavorite': isFavorite ? 1 : 0,
        'count': count,
        'outputFormat': outputFormat,
        'referenceImagePath': referenceImagePath,
        'referenceImagePathsJson': jsonEncode(referenceImagePaths),
        'providerId': providerId,
        'schemaVersion': schemaVersion,
        'parentRecordId': parentRecordId,
        'title': title,
        'category': category,
        'tagsJson': jsonEncode(tags),
        'notes': notes,
      };

  factory GeneratedImage.fromMap(Map<String, dynamic> map) {
    final rawPaths = map['referenceImagePathsJson'];
    final paths = rawPaths is String
        ? ((jsonDecode(rawPaths) as List?) ?? const [])
            .map((value) => value.toString())
            .toList()
        : const <String>[];
    final rawTags = map['tagsJson'];
    final tags = rawTags is String
        ? ((jsonDecode(rawTags) as List?) ?? const [])
            .map((value) => value.toString())
            .toList()
        : const <String>[];
    return GeneratedImage(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      model: map['model'] as String,
      size: map['size'] as String,
      quality: map['quality'] as String,
      group: (map['group'] as String?) ?? '',
      localPath: map['localPath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      generationTimeMs: (map['generationTimeMs'] as num?)?.toInt() ?? 0,
      isFavorite: ((map['isFavorite'] as num?)?.toInt() ?? 0) == 1,
      count: (map['count'] as num?)?.toInt() ?? 1,
      outputFormat: (map['outputFormat'] as String?) ?? 'png',
      referenceImagePath: map['referenceImagePath'] as String?,
      referenceImagePaths: paths,
      providerId: map['providerId'] as String?,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      parentRecordId: map['parentRecordId'] as String?,
      title: (map['title'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      tags: tags,
      notes: (map['notes'] as String?) ?? '',
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
    bool? isFavorite,
    int? count,
    String? outputFormat,
    String? referenceImagePath,
    List<String>? referenceImagePaths,
    String? providerId,
    int? schemaVersion,
    String? parentRecordId,
    String? title,
    String? category,
    List<String>? tags,
    String? notes,
  }) =>
      GeneratedImage(
        id: id ?? this.id,
        prompt: prompt ?? this.prompt,
        model: model ?? this.model,
        size: size ?? this.size,
        quality: quality ?? this.quality,
        group: group ?? this.group,
        localPath: localPath ?? this.localPath,
        createdAt: createdAt ?? this.createdAt,
        generationTimeMs: generationTimeMs ?? this.generationTimeMs,
        isFavorite: isFavorite ?? this.isFavorite,
        count: count ?? this.count,
        outputFormat: outputFormat ?? this.outputFormat,
        referenceImagePath: referenceImagePath ?? this.referenceImagePath,
        referenceImagePaths: referenceImagePaths ?? this.referenceImagePaths,
        providerId: providerId ?? this.providerId,
        schemaVersion: schemaVersion ?? this.schemaVersion,
        parentRecordId: parentRecordId ?? this.parentRecordId,
        title: title ?? this.title,
        category: category ?? this.category,
        tags: tags ?? this.tags,
        notes: notes ?? this.notes,
      );
}
