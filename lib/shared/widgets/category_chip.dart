import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Brand accent colours for known platforms.
const _platformColors = <String, Color>{
  'YouTube': Color(0xFFFF0000),
  'Instagram': Color(0xFFC13584),
  'X': Color(0xFF536471),
  'Reddit': Color(0xFFFF4500),
  'Facebook': Color(0xFF1877F2),
  'LinkedIn': Color(0xFF0A66C2),
  'TikTok': Color(0xFFEE1D52),
  'Pinterest': Color(0xFFE60023),
  'Threads': Color(0xFF536471),
  'Snapchat': Color(0xFFFFFC00),
  'Tumblr': Color(0xFF35465C),
  'GitHub': Color(0xFF8B949E),
  'GitLab': Color(0xFFFC6D26),
  'Stack Overflow': Color(0xFFF48024),
  'Medium': Color(0xFF8B949E),
  'DEV': Color(0xFF8B949E),
  'npm': Color(0xFFCB3837),
  'pub.dev': Color(0xFF01579B),
  'crates.io': Color(0xFFDEA584),
  'PyPI': Color(0xFF3775A9),
  'Google Docs': Color(0xFF4285F4),
  'Notion': Color(0xFF8B949E),
  'Amazon': Color(0xFFFF9900),
  'eBay': Color(0xFFE53238),
  'Flipkart': Color(0xFF2874F0),
  'Netflix': Color(0xFFE50914),
  'Spotify': Color(0xFF1DB954),
  'Twitch': Color(0xFF9146FF),
  'SoundCloud': Color(0xFFFF5500),
  'Wikipedia': Color(0xFF636466),
  'Hacker News': Color(0xFFFF6600),
  'Google Maps': Color(0xFF34A853),
  'Google': Color(0xFF4285F4),
  'Dribbble': Color(0xFFEA4C89),
  'Figma': Color(0xFFA259FF),
  'Behance': Color(0xFF1769FF),
  // AI
  'ChatGPT': Color(0xFF10A37F),
  'Claude': Color(0xFFD97706),
  'Gemini': Color(0xFF4285F4),
  'Perplexity': Color(0xFF20B2AA),
  'Copilot': Color(0xFF0078D4),
  'Bing': Color(0xFF0078D4),
  'Hugging Face': Color(0xFFFFD21E),
  'Replicate': Color(0xFF393F46),
  'OpenAI': Color(0xFF10A37F),
  'Mistral': Color(0xFFFF7000),
  // Productivity
  'Obsidian': Color(0xFF7C3AED),
  'Trello': Color(0xFF0052CC),
  'Linear': Color(0xFF5E6AD2),
  'Airtable': Color(0xFF2D7FF9),
  'Substack': Color(0xFFFF6719),
  // Finance
  'CoinMarketCap': Color(0xFF3861FB),
  'Binance': Color(0xFFF0B90B),
  'Web': Color(0xFF607D8B),
};

/// Maps category names to their official website domain for favicon lookup.
const platformDomains = <String, String>{
  'YouTube': 'youtube.com',
  'Instagram': 'instagram.com',
  'X': 'x.com',
  'Reddit': 'reddit.com',
  'Facebook': 'facebook.com',
  'LinkedIn': 'linkedin.com',
  'TikTok': 'tiktok.com',
  'Pinterest': 'pinterest.com',
  'Threads': 'threads.net',
  'Snapchat': 'snapchat.com',
  'Tumblr': 'tumblr.com',
  'GitHub': 'github.com',
  'GitLab': 'gitlab.com',
  'Stack Overflow': 'stackoverflow.com',
  'Medium': 'medium.com',
  'DEV': 'dev.to',
  'npm': 'npmjs.com',
  'pub.dev': 'pub.dev',
  'crates.io': 'crates.io',
  'PyPI': 'pypi.org',
  'Google Docs': 'docs.google.com',
  'Notion': 'notion.so',
  'Amazon': 'amazon.com',
  'eBay': 'ebay.com',
  'Flipkart': 'flipkart.com',
  'Netflix': 'netflix.com',
  'Spotify': 'spotify.com',
  'Twitch': 'twitch.tv',
  'SoundCloud': 'soundcloud.com',
  'Wikipedia': 'wikipedia.org',
  'Hacker News': 'news.ycombinator.com',
  'Google Maps': 'maps.google.com',
  'Google': 'google.com',
  'Dribbble': 'dribbble.com',
  'Figma': 'figma.com',
  'Behance': 'behance.net',
  'ChatGPT': 'chatgpt.com',
  'Claude': 'claude.ai',
  'Gemini': 'gemini.google.com',
  'Perplexity': 'perplexity.ai',
  'Copilot': 'copilot.microsoft.com',
  'Bing': 'bing.com',
  'Hugging Face': 'huggingface.co',
  'Replicate': 'replicate.com',
  'OpenAI': 'openai.com',
  'Mistral': 'mistral.ai',
  'Obsidian': 'obsidian.md',
  'Trello': 'trello.com',
  'Linear': 'linear.app',
  'Airtable': 'airtable.com',
  'Substack': 'substack.com',
  'CoinMarketCap': 'coinmarketcap.com',
  'Binance': 'binance.com',
};

/// Returns the official favicon URL for a given category.
String? faviconUrl(String category) {
  final domain = platformDomains[category];
  if (domain == null) return null;
  return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
}

/// Ensures a colour has enough luminance to be readable on a dark surface.
Color _ensureReadable(Color c, bool isDark) {
  if (!isDark) return c;
  final hsl = HSLColor.fromColor(c);
  if (hsl.lightness < 0.5) {
    return hsl.withLightness(0.65).toColor();
  }
  return c;
}

/// Minimal badge-style category tag matching the URL card tag style.
class CategoryChip extends StatelessWidget {
  final String category;
  final String emoji;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.emoji,
    this.count = 0,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rawColor = _platformColors[category] ?? theme.colorScheme.primary;
    final brandColor = _ensureReadable(rawColor, isDark);
    final favicon = faviconUrl(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: brandColor.withValues(alpha: isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (favicon != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: CachedNetworkImage(
                  imageUrl: favicon,
                  width: 12,
                  height: 12,
                  errorWidget: (_, _, _) =>
                      Text(emoji, style: const TextStyle(fontSize: 10)),
                ),
              )
            else
              Text(emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            Text(
              category,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: brandColor,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
