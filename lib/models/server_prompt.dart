class ServerPrompt {
  final String id;
  final String category;
  final String title;
  final String description;
  final String prompt;
  final String negativePrompt;
  final List<String> variables;
  final List<String> tags;
  final int sort;
  final String updatedAt;

  const ServerPrompt({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.prompt,
    required this.negativePrompt,
    required this.variables,
    required this.tags,
    required this.sort,
    required this.updatedAt,
  });

  factory ServerPrompt.fromMap(Map<String, dynamic> map) {
    return ServerPrompt(
      id: map['id'] as String? ?? '',
      category: map['category'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      negativePrompt: map['negativePrompt'] as String? ?? '',
      variables: _stringList(map['variables']),
      tags: _stringList(map['tags']),
      sort: (map['sort'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] as String? ?? '',
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}

class PromptLibraryResult {
  final List<ServerPrompt> items;
  final List<String> categories;
  final String libraryVersion;
  final String updatedAt;

  const PromptLibraryResult({
    required this.items,
    required this.categories,
    required this.libraryVersion,
    required this.updatedAt,
  });
}
