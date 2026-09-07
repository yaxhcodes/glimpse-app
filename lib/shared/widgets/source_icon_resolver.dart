import 'package:flutter/material.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

SourceIconSpec resolveSourceIcon(String name) {
  final lower = name.toLowerCase().trim();

  final brandAsset = _brandAssets[lower];
  if (brandAsset != null) {
    return SourceIconSpec.asset(brandAsset);
  }

  if (_hasGlyph(lower)) {
    return SourceIconSpec.glyph(lower);
  }

  if (lower == 'tiktok') {
    return const SourceIconSpec(AppIcons.music, 'Platform');
  }
  if (lower == 'facebook') {
    return const SourceIconSpec(AppIcons.people, 'Platform');
  }
  if (lower == 'threads') {
    return const SourceIconSpec(AppIcons.quote, 'Platform');
  }
  if (lower == 'snapchat') {
    return const SourceIconSpec(AppIcons.magicWand, 'Platform');
  }
  if (lower == 'tumblr') {
    return const SourceIconSpec(AppIcons.bookOpen, 'Platform');
  }

  // Dev / Tech
  if (lower == 'git') {
    return const SourceIconSpec(AppIcons.terminal, 'Dev');
  }
  if (lower == 'gitlab') {
    return const SourceIconSpec(AppIcons.code, 'Dev');
  }
  if (lower == 'stackoverflow') {
    return const SourceIconSpec(AppIcons.conversation, 'Dev');
  }
  if (lower == 'npm' || lower == 'pub.dev') {
    return const SourceIconSpec(AppIcons.zipFile, 'Dev');
  }
  if (lower == 'dev') {
    return const SourceIconSpec(AppIcons.article, 'Dev');
  }

  // AI
  if (lower == 'chatgpt' || lower == 'openai') {
    return const SourceIconSpec(AppIcons.robot, 'AI');
  }
  if (lower == 'claude') {
    return const SourceIconSpec(AppIcons.brain, 'AI');
  }
  if (lower == 'gemini') {
    return const SourceIconSpec(AppIcons.sparkle, 'AI');
  }
  if (lower == 'perplexity') {
    return const SourceIconSpec(AppIcons.explorePlaces, 'AI');
  }
  if (lower == 'hugging face' || lower == 'replicate') {
    return const SourceIconSpec(AppIcons.learning, 'AI');
  }
  if (lower == 'copilot' || lower == 'bing') {
    return const SourceIconSpec(AppIcons.command, 'AI');
  }

  // Productivity / Tools
  if (lower == 'notion' || lower == 'obsidian') {
    return const SourceIconSpec(AppIcons.addNote, 'Tool');
  }
  if (lower == 'trello' || lower == 'linear' || lower == 'airtable') {
    return const SourceIconSpec(AppIcons.kanban, 'Tool');
  }
  if (lower == 'google docs') {
    return const SourceIconSpec(AppIcons.document, 'Tool');
  }

  // Design / Creative
  if (lower == 'dribbble' || lower == 'behance') {
    return const SourceIconSpec(AppIcons.appearance, 'Design');
  }
  if (lower == 'figma') {
    return const SourceIconSpec(AppIcons.design, 'Design');
  }

  // Media / Entertainment
  if (lower == 'netflix' || lower == 'twitch' || lower == 'soundcloud') {
    return const SourceIconSpec(AppIcons.movie, 'Media');
  }

  // Shopping / Commerce
  if (lower == 'amazon' || lower == 'ebay' || lower == 'flipkart') {
    return const SourceIconSpec(AppIcons.shoppingBag, 'Shop');
  }

  // Finance
  if (lower == 'coinmarketcap' || lower == 'binance') {
    return const SourceIconSpec(AppIcons.trendUp, 'Finance');
  }

  // Knowledge / Reference
  if (lower == 'wikipedia') {
    return const SourceIconSpec(AppIcons.bookOpen, 'Knowledge');
  }
  if (lower == 'hacker news') {
    return const SourceIconSpec(AppIcons.news, 'Knowledge');
  }
  if (lower == 'google maps') {
    return const SourceIconSpec(AppIcons.map, 'Knowledge');
  }
  if (lower == 'google') {
    return const SourceIconSpec(AppIcons.search, 'Knowledge');
  }

  // Topic categories (semantic)
  if (lower.contains('tech') ||
      lower.contains('programming') ||
      lower.contains('software')) {
    return const SourceIconSpec(AppIcons.computer, 'Topic');
  }
  if (lower.contains('design') ||
      lower.contains('ui') ||
      lower.contains('ux')) {
    return const SourceIconSpec(AppIcons.brush, 'Topic');
  }
  if (lower.contains('ai') ||
      lower.contains('machine learning') ||
      lower.contains('ml')) {
    return const SourceIconSpec(AppIcons.network, 'Topic');
  }
  if (lower.contains('business') ||
      lower.contains('startup') ||
      lower.contains('entrepreneur')) {
    return const SourceIconSpec(AppIcons.rocket, 'Topic');
  }
  if (lower.contains('science') || lower.contains('research')) {
    return const SourceIconSpec(AppIcons.science, 'Topic');
  }
  if (lower.contains('philosophy') || lower.contains('psychology')) {
    return const SourceIconSpec(AppIcons.idea, 'Topic');
  }
  if (lower.contains('art') || lower.contains('creative')) {
    return const SourceIconSpec(AppIcons.appearance, 'Topic');
  }
  if (lower.contains('health') ||
      lower.contains('fitness') ||
      lower.contains('wellness')) {
    return const SourceIconSpec(AppIcons.heart, 'Topic');
  }
  if (lower.contains('finance') ||
      lower.contains('money') ||
      lower.contains('invest')) {
    return const SourceIconSpec(AppIcons.bank, 'Topic');
  }
  if (lower.contains('news') || lower.contains('politic')) {
    return const SourceIconSpec(AppIcons.globe, 'Topic');
  }
  if (lower.contains('education') || lower.contains('learn')) {
    return const SourceIconSpec(AppIcons.education, 'Topic');
  }
  if (lower.contains('travel') || lower.contains('adventure')) {
    return const SourceIconSpec(AppIcons.takeoff, 'Topic');
  }
  if (lower.contains('food') ||
      lower.contains('cooking') ||
      lower.contains('recipe')) {
    return const SourceIconSpec(AppIcons.food, 'Topic');
  }
  if (lower.contains('music') || lower.contains('audio')) {
    return const SourceIconSpec(AppIcons.musicProvider, 'Topic');
  }
  if (lower.contains('video') ||
      lower.contains('film') ||
      lower.contains('movie')) {
    return const SourceIconSpec(AppIcons.video, 'Topic');
  }
  if (lower.contains('book') ||
      lower.contains('read') ||
      lower.contains('literature')) {
    return const SourceIconSpec(AppIcons.book, 'Topic');
  }
  if (lower.contains('game') || lower.contains('gaming')) {
    return const SourceIconSpec(AppIcons.game, 'Topic');
  }
  if (lower.contains('sport') || lower.contains('athletic')) {
    return const SourceIconSpec(AppIcons.sports, 'Topic');
  }
  if (lower.contains('photo') ||
      lower.contains('image') ||
      lower.contains('camera')) {
    return const SourceIconSpec(AppIcons.camera, 'Topic');
  }
  if (lower.contains('marketing') ||
      lower.contains('growth') ||
      lower.contains('seo')) {
    return const SourceIconSpec(AppIcons.campaign, 'Topic');
  }
  if (lower.contains('productivity') || lower.contains('efficiency')) {
    return const SourceIconSpec(AppIcons.checkCircle, 'Topic');
  }
  if (lower.contains('writing') ||
      lower.contains('essay') ||
      lower.contains('blog')) {
    return const SourceIconSpec(AppIcons.edit, 'Topic');
  }
  if (lower.contains('history') || lower.contains('culture')) {
    return const SourceIconSpec(AppIcons.bank, 'Topic');
  }
  if (lower.contains('nature') ||
      lower.contains('environment') ||
      lower.contains('climate')) {
    return const SourceIconSpec(AppIcons.forest, 'Topic');
  }
  if (lower.contains('fashion') || lower.contains('style')) {
    return const SourceIconSpec(AppIcons.clothing, 'Topic');
  }
  if (lower.contains('architecture') || lower.contains('interior')) {
    return const SourceIconSpec(AppIcons.architecture, 'Topic');
  }

  return const SourceIconSpec(AppIcons.folder, 'General');
}

const _glyphPlatforms = <String>{
  'twitter',
  'reddit',
  'github',
  'spotify',
  'linkedin',
  'medium',
  'substack',
};

const _brandAssets = <String, String>{
  'instagram': 'assets/brands/instagram.svg',
  'pinterest': 'assets/brands/pinterest.svg',
  'tiktok': 'assets/brands/tiktok.svg',
  'x': 'assets/brands/x.svg',
  'twitter': 'assets/brands/x.svg',
  'youtube': 'assets/brands/youtube.svg',
};

bool _hasGlyph(String lower) {
  return _glyphPlatforms.contains(lower);
}

class SourceIconSpec {
  final IconData? icon;
  final String? glyphPlatform;
  final String? assetPath;
  final String family;

  const SourceIconSpec(this.icon, this.family)
    : glyphPlatform = null,
      assetPath = null;

  const SourceIconSpec.glyph(this.glyphPlatform)
    : icon = null,
      assetPath = null,
      family = 'Platform';

  const SourceIconSpec.asset(this.assetPath)
    : icon = null,
      glyphPlatform = null,
      family = 'Platform';

  bool get isGlyph => glyphPlatform != null;
  bool get isAsset => assetPath != null;
}
