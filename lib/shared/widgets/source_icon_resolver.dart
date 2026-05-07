import 'package:flutter/material.dart';

SourceIconSpec resolveSourceIcon(String name) {
  final lower = name.toLowerCase().trim();

  if (_hasGlyph(lower)) {
    return SourceIconSpec.glyph(lower);
  }

  if (lower == 'tiktok') {
    return const SourceIconSpec(Icons.music_note_outlined, 'Platform');
  }
  if (lower == 'facebook') {
    return const SourceIconSpec(Icons.people_outline, 'Platform');
  }
  if (lower == 'threads') {
    return const SourceIconSpec(Icons.format_quote_outlined, 'Platform');
  }
  if (lower == 'snapchat') {
    return const SourceIconSpec(Icons.auto_fix_high_outlined, 'Platform');
  }
  if (lower == 'tumblr') {
    return const SourceIconSpec(Icons.auto_stories_outlined, 'Platform');
  }

  // Dev / Tech
  if (lower == 'git') {
    return const SourceIconSpec(Icons.terminal_outlined, 'Dev');
  }
  if (lower == 'gitlab') {
    return const SourceIconSpec(Icons.code_outlined, 'Dev');
  }
  if (lower == 'stackoverflow') {
    return const SourceIconSpec(Icons.question_answer_outlined, 'Dev');
  }
  if (lower == 'npm' || lower == 'pub.dev') {
    return const SourceIconSpec(Icons.folder_zip_outlined, 'Dev');
  }
  if (lower == 'dev') {
    return const SourceIconSpec(Icons.article_outlined, 'Dev');
  }

  // AI
  if (lower == 'chatgpt' || lower == 'openai') {
    return const SourceIconSpec(Icons.smart_toy_outlined, 'AI');
  }
  if (lower == 'claude') {
    return const SourceIconSpec(Icons.psychology_outlined, 'AI');
  }
  if (lower == 'gemini') {
    return const SourceIconSpec(Icons.auto_awesome_outlined, 'AI');
  }
  if (lower == 'perplexity') {
    return const SourceIconSpec(Icons.travel_explore_outlined, 'AI');
  }
  if (lower == 'hugging face' || lower == 'replicate') {
    return const SourceIconSpec(Icons.model_training_outlined, 'AI');
  }
  if (lower == 'copilot' || lower == 'bing') {
    return const SourceIconSpec(Icons.keyboard_command_key_outlined, 'AI');
  }

  // Productivity / Tools
  if (lower == 'notion' || lower == 'obsidian') {
    return const SourceIconSpec(Icons.edit_note_outlined, 'Tool');
  }
  if (lower == 'trello' || lower == 'linear' || lower == 'airtable') {
    return const SourceIconSpec(Icons.view_kanban_outlined, 'Tool');
  }
  if (lower == 'google docs') {
    return const SourceIconSpec(Icons.description_outlined, 'Tool');
  }

  // Design / Creative
  if (lower == 'dribbble' || lower == 'behance') {
    return const SourceIconSpec(Icons.palette_outlined, 'Design');
  }
  if (lower == 'figma') {
    return const SourceIconSpec(Icons.design_services_outlined, 'Design');
  }

  // Media / Entertainment
  if (lower == 'netflix' || lower == 'twitch' || lower == 'soundcloud') {
    return const SourceIconSpec(Icons.theaters_outlined, 'Media');
  }

  // Shopping / Commerce
  if (lower == 'amazon' || lower == 'ebay' || lower == 'flipkart') {
    return const SourceIconSpec(Icons.shopping_bag_outlined, 'Shop');
  }

  // Finance
  if (lower == 'coinmarketcap' || lower == 'binance') {
    return const SourceIconSpec(Icons.trending_up_outlined, 'Finance');
  }

  // Knowledge / Reference
  if (lower == 'wikipedia') {
    return const SourceIconSpec(Icons.menu_book_outlined, 'Knowledge');
  }
  if (lower == 'hacker news') {
    return const SourceIconSpec(Icons.newspaper_outlined, 'Knowledge');
  }
  if (lower == 'google maps') {
    return const SourceIconSpec(Icons.map_outlined, 'Knowledge');
  }
  if (lower == 'google') {
    return const SourceIconSpec(Icons.search_outlined, 'Knowledge');
  }

  // Topic categories (semantic)
  if (lower.contains('tech') || lower.contains('programming') || lower.contains('software')) {
    return const SourceIconSpec(Icons.computer_outlined, 'Topic');
  }
  if (lower.contains('design') || lower.contains('ui') || lower.contains('ux')) {
    return const SourceIconSpec(Icons.brush_outlined, 'Topic');
  }
  if (lower.contains('ai') || lower.contains('machine learning') || lower.contains('ml')) {
    return const SourceIconSpec(Icons.network_check_outlined, 'Topic');
  }
  if (lower.contains('business') || lower.contains('startup') || lower.contains('entrepreneur')) {
    return const SourceIconSpec(Icons.rocket_launch_outlined, 'Topic');
  }
  if (lower.contains('science') || lower.contains('research')) {
    return const SourceIconSpec(Icons.science_outlined, 'Topic');
  }
  if (lower.contains('philosophy') || lower.contains('psychology')) {
    return const SourceIconSpec(Icons.lightbulb_outline, 'Topic');
  }
  if (lower.contains('art') || lower.contains('creative')) {
    return const SourceIconSpec(Icons.color_lens_outlined, 'Topic');
  }
  if (lower.contains('health') || lower.contains('fitness') || lower.contains('wellness')) {
    return const SourceIconSpec(Icons.favorite_border_outlined, 'Topic');
  }
  if (lower.contains('finance') || lower.contains('money') || lower.contains('invest')) {
    return const SourceIconSpec(Icons.account_balance_outlined, 'Topic');
  }
  if (lower.contains('news') || lower.contains('politic')) {
    return const SourceIconSpec(Icons.language_outlined, 'Topic');
  }
  if (lower.contains('education') || lower.contains('learn')) {
    return const SourceIconSpec(Icons.school_outlined, 'Topic');
  }
  if (lower.contains('travel') || lower.contains('adventure')) {
    return const SourceIconSpec(Icons.flight_takeoff_outlined, 'Topic');
  }
  if (lower.contains('food') || lower.contains('cooking') || lower.contains('recipe')) {
    return const SourceIconSpec(Icons.restaurant_outlined, 'Topic');
  }
  if (lower.contains('music') || lower.contains('audio')) {
    return const SourceIconSpec(Icons.headphones_outlined, 'Topic');
  }
  if (lower.contains('video') || lower.contains('film') || lower.contains('movie')) {
    return const SourceIconSpec(Icons.videocam_outlined, 'Topic');
  }
  if (lower.contains('book') || lower.contains('read') || lower.contains('literature')) {
    return const SourceIconSpec(Icons.book_outlined, 'Topic');
  }
  if (lower.contains('game') || lower.contains('gaming')) {
    return const SourceIconSpec(Icons.sports_esports_outlined, 'Topic');
  }
  if (lower.contains('sport') || lower.contains('athletic')) {
    return const SourceIconSpec(Icons.sports_outlined, 'Topic');
  }
  if (lower.contains('photo') || lower.contains('image') || lower.contains('camera')) {
    return const SourceIconSpec(Icons.photo_camera_outlined, 'Topic');
  }
  if (lower.contains('marketing') || lower.contains('growth') || lower.contains('seo')) {
    return const SourceIconSpec(Icons.campaign_outlined, 'Topic');
  }
  if (lower.contains('productivity') || lower.contains('efficiency')) {
    return const SourceIconSpec(Icons.check_circle_outline, 'Topic');
  }
  if (lower.contains('writing') || lower.contains('essay') || lower.contains('blog')) {
    return const SourceIconSpec(Icons.create_outlined, 'Topic');
  }
  if (lower.contains('history') || lower.contains('culture')) {
    return const SourceIconSpec(Icons.account_balance_outlined, 'Topic');
  }
  if (lower.contains('nature') || lower.contains('environment') || lower.contains('climate')) {
    return const SourceIconSpec(Icons.forest_outlined, 'Topic');
  }
  if (lower.contains('fashion') || lower.contains('style')) {
    return const SourceIconSpec(Icons.checkroom_outlined, 'Topic');
  }
  if (lower.contains('architecture') || lower.contains('interior')) {
    return const SourceIconSpec(Icons.architecture_outlined, 'Topic');
  }

  return const SourceIconSpec(Icons.folder_outlined, 'General');
}

const _glyphPlatforms = <String>{
  'x', 'twitter', 'reddit', 'github', 'youtube',
  'spotify', 'pinterest', 'instagram', 'linkedin',
  'medium', 'substack',
};

bool _hasGlyph(String lower) {
  return _glyphPlatforms.contains(lower);
}

class SourceIconSpec {
  final IconData? icon;
  final String? glyphPlatform;
  final String family;

  const SourceIconSpec(this.icon, this.family)
      : glyphPlatform = null;

  const SourceIconSpec.glyph(this.glyphPlatform)
      : icon = null,
        family = 'Platform';

  bool get isGlyph => glyphPlatform != null;
}