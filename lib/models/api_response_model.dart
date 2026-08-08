/// API 响应解析模型

/// 图片生成结果
class ImageGenerationResult {
  final String? imageUrl;
  final String? base64Data;
  final String? revisedPrompt;
  final String? error;
  final String? providerName;

  const ImageGenerationResult({
    this.imageUrl,
    this.base64Data,
    this.revisedPrompt,
    this.error,
    this.providerName,
  });

  bool get isSuccess => error == null && (imageUrl != null || base64Data != null);
  bool get hasUrl => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasBase64 => base64Data != null && base64Data!.isNotEmpty;

  factory ImageGenerationResult.fromError(String error, {String? providerName}) {
    return ImageGenerationResult(error: error, providerName: providerName);
  }
}

/// 支持的端点类型
enum EndpointType {
  /// /v1/images/generations - OpenAI Images 兼容
  imagesGenerations,

  /// /v1/responses - Responses 流式生图
  responses,

  /// /v1/chat/completions - Chat 格式生图
  chatCompletions,
}

/// API 商家/提供者
class ApiProvider {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final int priority;
  final List<EndpointType> supportedEndpoints;

  const ApiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.priority,
    this.supportedEndpoints = const [EndpointType.imagesGenerations],
  });

  bool get isValid => apiKey.isNotEmpty && apiKey.startsWith('sk-');

  /// 获取最优端点
  EndpointType get bestEndpoint {
    if (supportedEndpoints.contains(EndpointType.imagesGenerations)) {
      return EndpointType.imagesGenerations;
    }
    if (supportedEndpoints.contains(EndpointType.responses)) {
      return EndpointType.responses;
    }
    if (supportedEndpoints.contains(EndpointType.chatCompletions)) {
      return EndpointType.chatCompletions;
    }
    return EndpointType.imagesGenerations;
  }

  ApiProvider copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    int? priority,
    List<EndpointType>? supportedEndpoints,
  }) {
    return ApiProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      priority: priority ?? this.priority,
      supportedEndpoints: supportedEndpoints ?? this.supportedEndpoints,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'priority': priority,
      'endpoints': supportedEndpoints.map((e) => e.name).toList(),
    };
  }

  factory ApiProvider.fromMap(Map<String, dynamic> map) {
    final endpointNames = (map['endpoints'] as List?)?.cast<String>() ?? [];
    final endpoints = endpointNames
        .map((n) => EndpointType.values.firstWhere(
              (e) => e.name == n,
              orElse: () => EndpointType.imagesGenerations,
            ))
        .toList();

    return ApiProvider(
      id: map['id'] as String,
      name: map['name'] as String,
      baseUrl: map['baseUrl'] as String,
      apiKey: map['apiKey'] as String,
      priority: (map['priority'] as int?) ?? 0,
      supportedEndpoints: endpoints.isEmpty
          ? [EndpointType.imagesGenerations]
          : endpoints,
    );
  }
}

/// 预定义的商家
class ProviderDefaults {
  // ========== 第一个商家: cn.meta-api.vip ==========
  static const String metaPremiumId = 'meta_premium';
  static const String metaRichId = 'meta_rich';
  static const String metaEnterpriseId = 'meta_enterprise';

  static const String metaPremiumName = 'MetaAPI - 优质分组';
  static const String metaRichName = 'MetaAPI - 土豪组';
  static const String metaEnterpriseName = 'MetaAPI - 企业分组';

  static const String metaBaseUrl = 'https://cn.meta-api.vip';

  // ========== 第二个商家: linksapi.cn ==========
  static const String linksId = 'linksapi';
  static const String linksName = 'LinksAPI';
  static const String linksBaseUrl = 'https://linksapi.cn';

  /// 自动模式下的商家优先级
  static const List<String> autoModePriority = [
    metaPremiumId,
    metaRichId,
    metaEnterpriseId,
    linksId,
  ];

  /// 创建默认商家列表
  static List<ApiProvider> createDefaults() {
    return [
      ApiProvider(
        id: metaPremiumId,
        name: metaPremiumName,
        baseUrl: metaBaseUrl,
        apiKey: '',
        priority: 1,
        supportedEndpoints: [
          EndpointType.imagesGenerations,
          EndpointType.responses,
        ],
      ),
      ApiProvider(
        id: metaRichId,
        name: metaRichName,
        baseUrl: metaBaseUrl,
        apiKey: '',
        priority: 2,
        supportedEndpoints: [
          EndpointType.imagesGenerations,
          EndpointType.responses,
        ],
      ),
      ApiProvider(
        id: metaEnterpriseId,
        name: metaEnterpriseName,
        baseUrl: metaBaseUrl,
        apiKey: '',
        priority: 3,
        supportedEndpoints: [
          EndpointType.imagesGenerations,
          EndpointType.responses,
        ],
      ),
      ApiProvider(
        id: linksId,
        name: linksName,
        baseUrl: linksBaseUrl,
        apiKey: '',
        priority: 4,
        supportedEndpoints: [EndpointType.chatCompletions],
      ),
    ];
  }
}

/// 余额信息
class BalanceInfo {
  final double totalBalance;
  final double usedBalance;
  final double remainingBalance;
  final String currency;

  const BalanceInfo({
    required this.totalBalance,
    required this.usedBalance,
    required this.remainingBalance,
    this.currency = 'USD',
  });

  bool get isEmpty =>
      totalBalance == 0 && usedBalance == 0 && remainingBalance == 0;

  factory BalanceInfo.empty() {
    return const BalanceInfo(
      totalBalance: 0,
      usedBalance: 0,
      remainingBalance: 0,
    );
  }
}
