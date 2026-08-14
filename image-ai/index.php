<?php
require_once __DIR__ . '/api/common.php';
$settings = read_json('settings.json') ?? [];
$announcements = read_json('announcements.json') ?? [];
$announcements = array_values(array_filter($announcements, fn($a) => empty($a['enabled']) || $a['enabled'] !== false));
usort($announcements, function($a, $b) {
    return ($b['pinned'] ?? false) <=> ($a['pinned'] ?? false);
});
$config = read_update_config();
$latest = $config['latestVersion'] ?? [];
$history = $config['versionHistory'] ?? [];
$githubReleaseUrl = 'https://github.com/cheng806415/android-AI/releases/latest';
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';
if (preg_match('/android/i', $userAgent)) {
    $detectedPlatform = 'android';
} elseif (preg_match('/windows/i', $userAgent)) {
    $detectedPlatform = 'windows';
} elseif (preg_match('/macintosh|mac os x/i', $userAgent)) {
    $detectedPlatform = 'macos';
} elseif (preg_match('/linux/i', $userAgent)) {
    $detectedPlatform = 'linux';
} else {
    $detectedPlatform = 'other';
}
?>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= htmlspecialchars($settings['site_title'] ?? 'AI 图片生成器') ?></title>
<meta name="description" content="<?= htmlspecialchars($settings['site_description'] ?? '') ?>">
<style>
:root {
  --bg: #f6f7fb;
  --bg2: rgba(255,255,255,0.85);
  --ink: #1a1a2e;
  --muted: #6c6c8a;
  --rule: #e2e4ee;
  --accent: #6c5ce7;
  --accent2: #00cec9;
  --radius: 12px;
  --max-w: 1000px;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  font-family: -apple-system, "PingFang SC", "Microsoft YaHei", "Noto Sans SC", sans-serif;
  background: var(--bg);
  background-image:
    radial-gradient(ellipse 60% 40% at 10% 20%, rgba(108,92,231,0.06) 0%, transparent 60%),
    radial-gradient(ellipse 50% 35% at 90% 30%, rgba(0,206,201,0.05) 0%, transparent 60%),
    radial-gradient(ellipse 40% 30% at 50% 80%, rgba(108,92,231,0.04) 0%, transparent 50%);
  color: var(--ink);
  line-height: 1.6;
  min-height: 100vh;
}
.container { max-width: var(--max-w); margin: 0 auto; padding: 0 24px; }

nav {
  position: sticky; top: 0; z-index: 100;
  background: rgba(255,255,255,0.9);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--rule);
}
nav .container {
  display: flex; justify-content: space-between; align-items: center;
  height: 64px;
}
.logo {
  font-size: 20px; font-weight: 700;
  background: linear-gradient(135deg, var(--accent), var(--accent2));
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
}
.nav-links { display: flex; gap: 28px; list-style: none; }
.nav-links a {
  color: var(--muted); text-decoration: none; font-size: 14px;
  transition: color .2s;
}
.nav-links a:hover { color: var(--accent); }
.admin-link {
  padding: 6px 14px; border: 1px solid var(--rule); border-radius: 20px;
  font-size: 13px; color: var(--muted); text-decoration: none;
  transition: all .2s;
}
.admin-link:hover { border-color: var(--accent); color: var(--accent); }

.hero {
  padding: 80px 0 60px; text-align: center;
}
.hero-badge {
  display: inline-flex; align-items: center; gap: 6px;
  background: linear-gradient(135deg, rgba(108,92,231,.1), rgba(0,206,201,.1));
  color: var(--accent);
  padding: 6px 16px; border-radius: 20px;
  font-size: 13px; font-weight: 500;
  margin-bottom: 24px;
}
.hero h1 {
  font-size: 48px; font-weight: 800; line-height: 1.15;
  margin-bottom: 16px;
  background: linear-gradient(135deg, #1a1a2e 0%, #6c5ce7 50%, #00cec9 100%);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
}
.hero p {
  font-size: 18px; color: var(--muted); max-width: 600px;
  margin: 0 auto 32px;
}
.hero-version {
  display: inline-flex; align-items: center; gap: 8px;
  background: #1a1a2e; color: #fff;
  padding: 10px 24px; border-radius: 24px;
  font-size: 15px; font-weight: 600;
}
.hero-version .dot {
  width: 8px; height: 8px; background: #00cec9; border-radius: 50%;
  animation: pulse 2s infinite;
}
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: .5; }
}

.announcements {
  padding: 0 0 40px;
}
.section-title {
  font-size: 14px; color: var(--muted); font-weight: 600;
  text-transform: uppercase; letter-spacing: 1px;
  margin-bottom: 16px; display: flex; align-items: center; gap: 8px;
}
.announcement-card {
  background: var(--bg2);
  backdrop-filter: blur(20px);
  border: 1px solid var(--rule);
  border-radius: var(--radius);
  padding: 20px 24px;
  margin-bottom: 12px;
  display: flex; gap: 16px;
  transition: box-shadow .2s;
}
.announcement-card:hover { box-shadow: 0 4px 20px rgba(0,0,0,.06); }
.announcement-card .icon {
  flex-shrink: 0;
  width: 36px; height: 36px; border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 18px;
}
.announcement-card.info .icon { background: rgba(108,92,231,.1); }
.announcement-card.success .icon { background: rgba(0,206,201,.1); }
.announcement-card.warning .icon { background: rgba(255,159,67,.1); }
.announcement-card .body { flex: 1; }
.announcement-card h4 { font-size: 15px; margin-bottom: 4px; }
.announcement-card p { font-size: 13px; color: var(--muted); line-height: 1.5; }
.announcement-card .badge {
  display: inline-block; font-size: 11px; padding: 2px 8px;
  border-radius: 10px; background: rgba(108,92,231,.1); color: var(--accent);
  margin-left: 8px; vertical-align: middle;
}
.announcement-card time {
  font-size: 12px; color: var(--muted);
}

.features {
  padding: 40px 0;
}
.features-grid {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px;
}
.feature-card {
  background: var(--bg2);
  backdrop-filter: blur(20px);
  border: 1px solid var(--rule);
  border-radius: var(--radius);
  padding: 24px;
  text-align: center;
}
.feature-card .f-icon {
  width: 48px; height: 48px; margin: 0 auto 12px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 24px;
  background: linear-gradient(135deg, rgba(108,92,231,.1), rgba(0,206,201,.1));
}
.feature-card h3 { font-size: 15px; margin-bottom: 6px; }
.feature-card p { font-size: 13px; color: var(--muted); }

.download-section {
  padding: 60px 0;
}
.download-card {
  background: linear-gradient(135deg, #1a1a2e 0%, #2d2d5e 100%);
  border-radius: 20px;
  padding: 48px;
  color: #fff;
  display: flex; align-items: center; gap: 48px;
  flex-wrap: wrap;
}
.download-info { flex: 1; min-width: 260px; }
.download-info h2 { font-size: 28px; margin-bottom: 8px; }
.download-info .version-tag {
  display: inline-block; background: rgba(0,206,201,.2); color: #00cec9;
  padding: 4px 12px; border-radius: 12px; font-size: 13px; font-weight: 600;
  margin-bottom: 16px;
}
.download-info p { color: rgba(255,255,255,.7); font-size: 15px; }
.download-actions { display: flex; gap: 12px; flex-wrap: wrap; }
.btn {
  display: inline-flex; align-items: center; gap: 8px;
  padding: 12px 24px; border-radius: 12px; font-weight: 600;
  text-decoration: none; font-size: 14px;
  transition: transform .2s, box-shadow .2s;
  cursor: pointer; border: none;
}
.btn:active { transform: scale(0.96); }
.btn-primary {
  background: linear-gradient(135deg, #6c5ce7, #00cec9);
  color: #fff;
}
.btn-primary:hover { box-shadow: 0 4px 20px rgba(108,92,231,.4); }
.btn-ghost {
  background: rgba(255,255,255,.1); color: #fff;
  border: 1px solid rgba(255,255,255,.2);
}
.btn-ghost:hover { background: rgba(255,255,255,.15); }
.download-meta {
  display: flex; gap: 24px; margin-top: 20px;
  font-size: 13px; color: rgba(255,255,255,.6);
}
.download-meta span strong { color: #fff; }
.platform-grid {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px;
  margin-top: 24px;
}
.platform-card {
  padding: 18px; border: 1px solid var(--rule); border-radius: 14px;
  background: var(--bg2); text-decoration: none; color: inherit;
}
.platform-card.active { border-color: var(--accent); box-shadow: 0 0 0 2px rgba(108,92,231,.12); }
.platform-card h3 { font-size: 15px; margin-bottom: 5px; }
.platform-card p { font-size: 12px; color: var(--muted); margin-bottom: 12px; }
.platform-card .platform-link { color: var(--accent); font-size: 13px; font-weight: 600; }
@media (max-width: 760px) { .platform-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 420px) { .platform-grid { grid-template-columns: 1fr; } }

.changelog {
  padding: 40px 0;
}
.changelog-list {
  position: relative;
  padding-left: 32px;
}
.changelog-list::before {
  content: ''; position: absolute; left: 8px; top: 8px; bottom: 8px;
  width: 2px; background: var(--rule);
}
.changelog-entry {
  position: relative; margin-bottom: 28px;
}
.changelog-entry::before {
  content: ''; position: absolute; left: -28px; top: 6px;
  width: 12px; height: 12px; border-radius: 50%;
  background: var(--accent);
}
.changelog-entry .version {
  font-size: 15px; font-weight: 700; margin-right: 8px;
}
.changelog-entry .tag {
  display: inline-block; font-size: 11px; padding: 2px 8px;
  border-radius: 10px; font-weight: 600; margin-right: 8px;
}
.tag-patch { background: rgba(0,206,201,.15); color: #00cec9; }
.tag-minor { background: rgba(108,92,231,.15); color: var(--accent); }
.tag-major { background: rgba(255,159,67,.15); color: #ff9f43; }
.changelog-entry .date { font-size: 13px; color: var(--muted); }
.changelog-entry h4 { font-size: 14px; margin: 12px 0 6px; }
.changelog-entry ul { padding-left: 18px; }
.changelog-entry li {
  font-size: 14px; color: var(--muted); margin-bottom: 4px;
}
.changelog-entry li strong { color: var(--ink); }

footer {
  padding: 40px 0; text-align: center;
  border-top: 1px solid var(--rule);
  margin-top: 40px;
}
footer p { font-size: 13px; color: var(--muted); }

@media (max-width: 640px) {
  .hero { padding: 40px 0; }
  .hero h1 { font-size: 32px; }
  .download-card { padding: 32px 24px; }
  .download-actions { width: 100%; }
  .btn { flex: 1; justify-content: center; }
  .nav-links { display: none; }
}
</style>
</head>
<body>

<nav>
  <div class="container">
    <div class="logo"><?= htmlspecialchars($settings['logo_text'] ?? 'DreamArt') ?></div>
    <ul class="nav-links">
      <li><a href="#announcements">公告</a></li>
      <li><a href="#features">功能</a></li>
      <li><a href="/docs.php">文档中心</a></li>
      <li><a href="/prompts.php">提示词库</a></li>
      <li><a href="#download">下载</a></li>
      <li><a href="#changelog">更新日志</a></li>
    </ul>
    <a href="/admin/login.php" class="admin-link">管理后台</a>
  </div>
</nav>

<section class="hero">
  <div class="container">
    <div class="hero-badge">
      <span>AI Powered</span>
    </div>
    <h1><?= htmlspecialchars($settings['site_title'] ?? 'AI 图片生成器') ?></h1>
    <p><?= htmlspecialchars($settings['site_description'] ?? '') ?></p>
    <div class="hero-version">
      <span class="dot"></span>
      v<?= htmlspecialchars($latest['versionName'] ?? '1.3.1') ?> 已发布
    </div>
  </div>
</section>

<?php if (!empty($announcements)): ?>
<section class="announcements" id="announcements">
  <div class="container">
    <div class="section-title">最新公告</div>
    <?php foreach ($announcements as $ann): ?>
    <div class="announcement-card <?= htmlspecialchars($ann['type'] ?? 'info') ?>">
      <div class="icon"><?= $ann['type'] === 'success' ? '&#10003;' : ($ann['type'] === 'warning' ? '!' : 'i') ?></div>
      <div class="body">
        <h4>
          <?= htmlspecialchars($ann['title']) ?>
          <?php if (!empty($ann['pinned'])): ?><span class="badge">置顶</span><?php endif; ?>
        </h4>
        <p><?= htmlspecialchars($ann['content']) ?></p>
        <time><?= htmlspecialchars($ann['created_at'] ?? '') ?></time>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</section>
<?php endif; ?>

<section class="features" id="features" aria-label="核心功能">
  <div class="container">
    <div class="section-title">核心功能</div>
    <div class="features-grid">
      <div class="feature-card">
        <div class="f-icon">AI</div>
        <h3>多模型支持</h3>
        <p>集成主流 AI 模型，满足不同创作需求</p>
      </div>
      <div class="feature-card">
        <div class="f-icon">&#9733;</div>
        <h3>收藏管理</h3>
        <p>收藏喜爱的作品，随时回顾与分享</p>
      </div>
      <div class="feature-card">
        <div class="f-icon">&#8862;</div>
        <h3>多图并行</h3>
        <p>同时生成多张图片，效率翻倍</p>
      </div>
      <div class="feature-card">
        <div class="f-icon">&#9881;</div>
        <h3>提示词模板</h3>
        <p>内置专业提示词，新手也能出好图</p>
      </div>
    </div>
  </div>
</section>

<?php if (!empty($docs)): ?>
<section class="features" id="docs">
  <div class="container">
    <div class="section-title">文档中心 <a href="/docs.php" style="margin-left:auto;color:var(--accent);text-decoration:none;font-size:12px;">查看全部</a></div>
    <div class="features-grid">
      <?php foreach ($docs as $doc): ?>
      <a class="feature-card" href="/docs.php?id=<?= urlencode($doc['id']) ?>" style="text-decoration:none;color:inherit;text-align:left;">
        <div style="font-size:12px;color:var(--accent);margin-bottom:8px;"><?= htmlspecialchars($doc['category'] ?? '') ?></div>
        <h3><?= htmlspecialchars($doc['title'] ?? '') ?></h3>
        <p><?= htmlspecialchars($doc['summary'] ?? '') ?></p>
      </a>
      <?php endforeach; ?>
    </div>
  </div>
</section>
<?php endif; ?>

<section class="features" id="prompt-library">
  <div class="container">
    <div class="section-title">服务器提示词库</div>
    <div class="feature-card" style="text-align:left;display:flex;align-items:center;justify-content:space-between;gap:20px;flex-wrap:wrap;">
      <div><h3>按行业获取可直接使用的中文提示词</h3><p>覆盖商业、电商、餐饮、建筑、教育、医疗、科技、图片修复等场景。提示词库由服务器持续更新，可在线浏览或下载最新 JSON。</p></div>
      <a href="/prompts.php" class="btn btn-primary">浏览提示词库</a>
    </div>
  </div>
</section>

<section class="download-section" id="download">
  <div class="container">
    <div class="download-card">
      <div class="download-info">
        <span class="version-tag">v<?= htmlspecialchars($latest['versionName'] ?? '1.5.0') ?> (Build <?= $latest['versionCode'] ?? 11 ?>)</span>
        <h2><?= !empty($config['updateServerInfo']['pendingApk']) ? 'APK 准备中' : '立即下载体验' ?></h2>
        <p><?= !empty($config['updateServerInfo']['pendingApk']) ? '最新 APK 尚未生成并完成校验，当前不会把旧 APK 当作新版本提供下载。' : '最新版本包含设置页面重构、更新诊断和生成流程优化，更新更加稳定可靠。' ?></p>
        <div class="download-meta">
          <?php if (!empty($config['updateServerInfo']['pendingApk'])): ?><span>状态: <strong>等待 APK 校验</strong></span><?php else: ?><span>大小: <strong><?= number_format($latest['apkSize'] ?? 0) ?> 字节</strong></span><?php endif; ?>
          <span>类型: <strong><?= strtoupper($latest['updateType'] ?? 'PATCH') ?></strong></span>
        </div>
      </div>
      <div class="download-actions">
        <?php if ($detectedPlatform === 'android'): ?>
        <a href="/download.php" class="btn btn-primary">
          &#8681; 下载 Android APK
        </a>
        <?php elseif ($detectedPlatform === 'linux'): ?>
        <span class="btn btn-ghost">Linux 暂不开发</span>
        <?php else: ?>
        <a href="<?= htmlspecialchars($githubReleaseUrl) ?>" class="btn btn-primary" target="_blank" rel="noopener">
          &#8681; 前往 GitHub Releases
        </a>
        <?php endif; ?>
        <a href="#changelog" class="btn btn-ghost">查看更新日志</a>
      </div>
    </div>
    <div class="platform-grid">
      <div class="platform-card <?= $detectedPlatform === 'android' ? 'active' : '' ?>">
        <h3>Android</h3>
        <p>保持本地部署，正式 APK 从服务器更新。</p>
        <a class="platform-link" href="/download.php">下载 APK</a>
      </div>
      <a class="platform-card <?= $detectedPlatform === 'windows' ? 'active' : '' ?>" href="<?= htmlspecialchars($githubReleaseUrl) ?>" target="_blank" rel="noopener">
        <h3>Windows</h3>
        <p>x86-64（AMD64）已发布；ARM64（Windows on ARM）适配中。</p>
        <span class="platform-link">GitHub Releases</span>
      </a>
      <a class="platform-card <?= $detectedPlatform === 'macos' ? 'active' : '' ?>" href="<?= htmlspecialchars($githubReleaseUrl) ?>" target="_blank" rel="noopener">
        <h3>macOS</h3>
        <p>ARM64（Apple Silicon）和 x86-64（Intel）。</p>
        <span class="platform-link">GitHub Releases</span>
      </a>
      <div class="platform-card <?= $detectedPlatform === 'linux' ? 'active' : '' ?>">
        <h3>Linux</h3>
        <p>当前不在开发计划内。</p>
        <span class="platform-link">暂不开发</span>
      </div>
    </div>
  </div>
</section>

<section class="changelog" id="changelog">
  <div class="container">
    <div class="section-title">更新日志</div>
    <div class="changelog-list">
      <?php foreach ($history as $ver): ?>
      <div class="changelog-entry">
        <span class="version">v<?= htmlspecialchars($ver['versionName'] ?? '') ?></span>
        <span class="tag tag-<?= htmlspecialchars($ver['updateType'] ?? 'patch') ?>"><?= strtoupper($ver['updateType'] ?? 'PATCH') ?></span>
        <span class="date"><?= htmlspecialchars($ver['releaseDate'] ?? '') ?></span>
        <h4>更新内容</h4>
        <ul>
          <?php
          $lines = preg_split('/[\n]/', $ver['changelog'] ?? '');
          foreach ($lines as $line) {
              $line = trim($line);
              if ($line !== '') {
                  $cleaned = preg_replace('/^\d+\.\s*/', '', $line);
                  echo '<li>' . htmlspecialchars($cleaned) . '</li>';
              }
          }
          ?>
        </ul>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</section>

<footer>
  <div class="container">
    <p><?= htmlspecialchars($settings['footer_text'] ?? '2026 DreamArt. All rights reserved.') ?></p>
  </div>
</footer>

</body>
</html>
