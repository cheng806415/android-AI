/// 内置提示词模板
class PromptTemplate {
  final String id;
  final String name;
  final String description;
  final String prompt;

  const PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.prompt,
  });

  static const List<PromptTemplate> builtIn = [
    PromptTemplate(
      id: 'anime_couple',
      name: '动漫情头',
      description: '生成情侣头像或配套角色图',
      prompt: '动漫风格情侣头像，两位角色关系亲密，构图适合社交头像，统一画风，柔和光线，精致细节，干净背景',
    ),
    PromptTemplate(
      id: 'avatar',
      name: '社交头像',
      description: '生成个性化社交平台头像',
      prompt: '高质量社交头像，人物半身近景，表情自然，构图居中，背景简洁，柔和光线，精致细节，适合圆形头像裁剪',
    ),
    PromptTemplate(
      id: 'wallpaper',
      name: '手机壁纸',
      description: '生成适合手机屏幕的壁纸',
      prompt: '高质量手机壁纸，竖屏构图，主体清晰，画面有层次，顶部和底部预留适合放置系统图标的留白，电影感光线，细节丰富',
    ),
    PromptTemplate(
      id: 'poster',
      name: '宣传海报',
      description: '生成活动或产品宣传视觉',
      prompt: '现代商业宣传海报，主体突出，层次清晰，配色协调，预留标题和副标题区域，视觉冲击力强，高质量平面设计',
    ),
    PromptTemplate(
      id: 'product',
      name: '商品展示',
      description: '生成商品宣传和电商主图',
      prompt: '高质量商品展示图，商品作为画面主体，干净背景，专业棚拍光线，真实材质，细节清晰，适合电商宣传',
    ),
    PromptTemplate(
      id: 'portrait',
      name: '写实人像',
      description: '生成自然、细腻的人物肖像',
      prompt: '写实风格人物肖像，面部自然，皮肤纹理细腻，眼神有神，构图平衡，柔和环境光，摄影棚级画质，高细节',
    ),
  ];
}
