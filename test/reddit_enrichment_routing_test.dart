import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/core/utils/blocked_page.dart';

void main() {
  test('Reddit posts go to the enrichment worker; listings do not', () {
    for (final url in [
      'https://www.reddit.com/r/AndroidDev/comments/1abc23/best_way_to_ship/',
      'https://reddit.com/r/AndroidDev/comments/1abc23',
      'https://old.reddit.com/r/AndroidDev/comments/1abc23/x/',
      'https://www.reddit.com/r/AndroidDev/s/AbC123xYz',
      'https://www.reddit.com/user/someone/comments/9zz9zz/post/',
      'https://www.reddit.com/comments/1abc23',
      'https://redd.it/1abc23',
    ]) {
      expect(TranscriptEnrichmentService.supportsUrl(url), isTrue, reason: url);
    }
    for (final url in [
      'https://www.reddit.com/r/AndroidDev/',
      'https://www.reddit.com/user/someone/',
      'https://www.reddit.com/',
      'https://notreddit.com/r/x/comments/1abc23',
    ]) {
      expect(
        TranscriptEnrichmentService.supportsUrl(url),
        isFalse,
        reason: url,
      );
    }
  });

  test('the app and the worker recognise the same Reddit URLs', () {
    // A URL the worker sends to Apify but the app doesn't route there would
    // be summarised from Reddit's bot wall again.
    final worker = File('glimpse-enrichment-backend/src/services/shared.ts');
    if (!worker.existsSync()) return; // Worker repo not checked out here.
    final source = worker.readAsStringSync();
    for (final pattern in [
      r'^(www|old|new|np|m|i)\.',
      r'^\/[a-z0-9]+\/?$',
      r'^\/(r|u|user)\/[^/]+\/(comments\/[a-z0-9]+|s\/[a-z0-9]+)',
      r'^\/comments\/[a-z0-9]+',
    ]) {
      expect(source, contains(pattern), reason: pattern);
    }
  });

  test('bot walls and error pages are recognised, real titles are not', () {
    for (final text in [
      "You've been blocked by network security.",
      'Whoa there, pardner!',
      'Just a moment...',
      'Attention Required! | Cloudflare',
      '404 Not Found',
      'Page not found',
      'Please verify you are human to continue',
      'JavaScript is not available.',
    ]) {
      expect(BlockedPage.looksBlocked(text), isTrue, reason: text);
    }
    for (final text in [
      'Troubleshooting a 404 in Next.js app router',
      'Why I stopped using JavaScript frameworks',
      'Not found: the lost cities of the Amazon',
      'Best ramen spot in Osaka',
      '',
      null,
    ]) {
      expect(BlockedPage.looksBlocked(text), isFalse, reason: '$text');
    }
  });
}
