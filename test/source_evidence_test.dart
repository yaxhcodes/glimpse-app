import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/link_preview_service.dart';

void main() {
  test('prefers JSON-LD article text and keeps safe outbound links', () {
    final evidence = LinkPreviewService.sourceEvidenceFromHtml('''
      <html><body>
        <nav>Navigation noise <a href="/account">Account</a></nav>
        <script type="application/ld+json">
          {"@type":"Article","articleBody":"The complete readable article body."}
        </script>
        <main><p>Short fallback.</p>
          <a href="/guide">Guide</a>
          <a href="javascript:alert(1)">Unsafe</a>
        </main>
      </body></html>
      ''', pageUrl: 'https://example.com/article');

    expect(evidence.readableText, 'The complete readable article body.');
    expect(evidence.outboundLinks.single.url, 'https://example.com/guide');
  });

  test('semantic fallback removes chrome and bounds readable evidence', () {
    final evidence = LinkPreviewService.sourceEvidenceFromHtml(
      '<main><header>Menu</header><article>${List.filled(6000, 'word').join(' ')}</article></main>',
      pageUrl: 'https://example.com',
    );

    expect(evidence.readableText, isNot(contains('Menu')));
    expect(evidence.readableText.length, lessThanOrEqualTo(20000));
    expect(evidence.readableText, contains('remaining text was not captured'));
  });

  test('keeps short headings and recommendation names beside longer prose', () {
    final evidence = LinkPreviewService.sourceEvidenceFromHtml('''
      <main><h2>Tools</h2>
        <p>Use these tools to build and publish the project.</p>
        <ul><li>Expo</li><li>Supabase</li><li>SQLite</li></ul>
        <h2>注意点</h2><p>無料枠には制限があります。</p>
      </main>
    ''', pageUrl: 'https://example.com/tools');
    for (final text in [
      'Tools',
      'Expo',
      'Supabase',
      'SQLite',
      '注意点',
      '無料枠には制限があります。',
    ]) {
      expect(evidence.readableText, contains(text));
    }
  });

  test('X evidence preserves expanded outbound URL entities', () {
    final evidence = LinkPreviewService.sourceEvidenceFromXJson({
      'text': 'Read this https://t.co/short',
      'entities': {
        'urls': [
          {
            'url': 'https://t.co/short',
            'expanded_url': 'https://example.org/complete-resource',
          },
        ],
      },
    }, readableText: 'Read this https://t.co/short');

    expect(evidence.readableText, contains('https://t.co/short'));
    expect(
      evidence.outboundLinks.single.url,
      'https://example.org/complete-resource',
    );
  });
}
