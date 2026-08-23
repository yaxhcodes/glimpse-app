import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/core/services/transcript_enrichment_service.dart';
import 'package:glimpse/core/services/notification_hub_labels.dart';
import 'package:glimpse/core/services/tag_noise_filter.dart';
import 'package:glimpse/features/library/library_entity.dart';
import 'package:glimpse/features/library/library_localization.dart';
import 'package:glimpse/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves supported device locales and falls back to English', () {
    expect(resolveAppLocale(const [Locale('ja', 'JP')]), const Locale('ja'));
    expect(resolveAppLocale(const [Locale('es', 'MX')]), const Locale('es'));
    expect(
      resolveAppLocale(const [Locale('pt', 'PT')]),
      const Locale('pt', 'BR'),
    );
    expect(resolveAppLocale(const [Locale('de')]), const Locale('en'));
  });

  test('persists an explicit language and restores system mode', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppLocaleController();
    await controller.ready;
    await controller.setLanguage(AppLanguage.japanese);
    expect(controller.state.preference, AppLanguage.japanese);
    expect(controller.state.effectiveLocale, const Locale('ja'));

    await controller.setLanguage(AppLanguage.system);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('glimpse_app_language'), isFalse);
    controller.dispose();
  });

  test(
    'cold-start locale loading restores Japanese before background work',
    () async {
      SharedPreferences.setMockInitialValues({'glimpse_app_language': 'ja'});

      final controller = AppLocaleController();
      await controller.ready;

      expect(controller.state.preference, AppLanguage.japanese);
      expect(controller.state.effectiveLocale, const Locale('ja'));
      expect(await loadEffectiveAppLocale(), const Locale('ja'));
      controller.dispose();
    },
  );

  testWidgets('all v1 localization delegates load translated navigation', (
    tester,
  ) async {
    final expected = <Locale, String>{
      const Locale('en'): 'Home',
      const Locale('ja'): 'ホーム',
      const Locale('es'): 'Inicio',
      const Locale('fr'): 'Accueil',
      const Locale('pt', 'BR'): 'Início',
    };

    for (final entry in expected.entries) {
      final strings = await AppLocalizations.delegate.load(entry.key);
      expect(strings.home, entry.value);
    }
  });

  testWidgets(
    'generic taxonomy labels localize while proper names remain canonical',
    (tester) async {
      final expected = <Locale, String>{
        const Locale('en'): 'Movies & Shows',
        const Locale('ja'): '映画・番組',
        const Locale('es'): 'Películas y series',
        const Locale('fr'): 'Films et séries',
        const Locale('pt', 'BR'): 'Filmes e séries',
      };

      for (final entry in expected.entries) {
        final strings = await AppLocalizations.delegate.load(entry.key);
        expect(localizedCategoryLabel(strings, 'Movies & TV'), entry.value);
        expect(localizedTagLabel(strings, 'appletv'), 'Apple TV+');
      }
    },
  );

  test('tag cleanup preserves display casing while deduplicating safely', () {
    expect(
      TagNoiseFilter.filterTags(const ['Apple TV+', 'apple tv+', 'スパイドラマ']),
      const ['Apple TV+', 'スパイドラマ'],
    );
  });

  testWidgets('screenshot surfaces use the selected language catalog', (
    tester,
  ) async {
    final expected = <Locale, List<String>>{
      const Locale('ja'): [
        'また見返したいものを保存',
        'ソース',
        '最近の保存',
        'スワイプ操作を選択',
        'どのアプリで聴きますか？',
        '外観',
      ],
      const Locale('es'): [
        'Guarda algo que valga la pena retomar',
        'Fuentes',
        'Guardados recientes',
        'Elige la acción al deslizar',
        '¿Dónde escuchas música?',
        'Apariencia',
      ],
      const Locale('fr'): [
        'Enregistrez quelque chose à retrouver plus tard',
        'Sources',
        'Enregistrements récents',
        'Choisir l’action de balayage',
        'Où écoutez-vous votre musique ?',
        'Apparence',
      ],
      const Locale('pt', 'BR'): [
        'Salve algo que valha a pena revisitar',
        'Fontes',
        'Salvos recentemente',
        'Escolha a ação ao deslizar',
        'Onde você ouve música?',
        'Aparência',
      ],
    };

    for (final entry in expected.entries) {
      final strings = await AppLocalizations.delegate.load(entry.key);
      expect(
        [
          strings.captureSomethingWorthReturning,
          strings.sources,
          strings.recentSaves,
          strings.chooseSwipeAction,
          strings.whereDoYouListen,
          strings.lookAndFeel,
        ],
        entry.value,
        reason: 'Locale ${entry.key} should cover every reported surface.',
      );
    }
  });

  test('all v1 ARB catalogs contain the same messages', () {
    const paths = <String>[
      'lib/l10n/app_en.arb',
      'lib/l10n/app_ja.arb',
      'lib/l10n/app_es.arb',
      'lib/l10n/app_fr.arb',
      'lib/l10n/app_pt.arb',
    ];
    Set<String> messageKeys(String path) {
      final json =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      return json.keys.where((key) => !key.startsWith('@')).toSet();
    }

    final englishKeys = messageKeys(paths.first);
    for (final path in paths.skip(1)) {
      expect(messageKeys(path), englishKeys, reason: '$path is incomplete.');
    }
  });

  testWidgets('remaining Japanese settings and Details chrome is localized', (
    tester,
  ) async {
    final strings = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(
      [
        strings.markAllRead,
        strings.subscription,
        strings.privacy,
        strings.storageLocation,
        strings.automaticBackup,
        strings.bin,
        strings.details,
        strings.summary,
        strings.keyTakeaways,
        strings.quotes,
        strings.peopleMentioned,
        strings.transcriptAndCaption,
        strings.tags,
      ],
      [
        'すべて既読にする',
        'サブスクリプション',
        'プライバシー',
        '保存場所',
        '自動バックアップ',
        'ゴミ箱',
        '詳細',
        '要約',
        '重要ポイント',
        '引用',
        '登場人物',
        '文字起こしとキャプション',
        'タグ',
      ],
    );
  });

  testWidgets(
    'Collections, Rediscover, Search, and Interests chrome localizes',
    (tester) async {
      final strings = await AppLocalizations.delegate.load(const Locale('ja'));
      expect(
        [
          strings.library,
          strings.libraryDescription,
          strings.rediscover,
          strings.rediscoverIntentTitle,
          strings.recaps,
          strings.searchYourLibrary,
          strings.findAnythingSaved,
          strings.filters,
          strings.allTime,
          strings.interests,
          strings.readingInterests,
          strings.topSignal,
          strings.growingInterests,
        ],
        [
          'ライブラリ',
          '保存から見つかった本、映画、場所',
          '再発見',
          '活用したい思い出',
          'まとめ',
          'ライブラリを検索…',
          '保存したものを検索',
          'フィルター',
          'すべての期間',
          '興味',
          '興味を読み取り中…',
          '最も強い関心',
          '高まりつつある関心',
        ],
      );
    },
  );

  testWidgets('Library chrome, statuses, genres, and counts localize', (
    tester,
  ) async {
    final strings = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(
      [
        localizedLibraryKind(strings, LibraryEntityKind.book),
        localizedLibraryKind(strings, LibraryEntityKind.movie),
        localizedLibraryKind(strings, LibraryEntityKind.place),
        localizedLibraryStatus(
          strings,
          LibraryItemStatus.active,
          LibraryEntityKind.movie,
        ),
        localizedLibraryGenre(strings, 'Comedy'),
        localizedLibraryGenre(strings, 'Romance'),
        strings.recentlyDiscovered,
        strings.foundInYourSaves,
        strings.yourPlaces,
        strings.whyItMattered,
      ],
      [
        '本',
        '映画・番組',
        '場所',
        '視聴中',
        'コメディ',
        'ロマンス',
        '最近見つかった順',
        '保存から見つかったもの',
        'あなたの場所',
        '注目した理由',
      ],
    );
  });

  testWidgets(
    'latest reported collection, notification, retry, and Ask chrome localizes',
    (tester) async {
      final strings = await AppLocalizations.delegate.load(const Locale('ja'));
      expect(
        [
          strings.editCollection,
          strings.collectionEditSubtitle,
          strings.deleteCollection,
          NotificationHubLabels.forHistoryType(strings, 'resurface'),
          NotificationHubLabels.forHistoryType(strings, 'collector'),
          strings.aiDetailsAvailable,
          strings.enrich,
          strings.askGlimpse,
          strings.askGreetingNight,
          strings.messageGlimpse,
          strings.addToCollection,
          strings.pin,
          strings.delete,
          strings.newCollection,
          strings.collectionCreateSubtitle,
          strings.yourNote,
          strings.notePrompt,
          strings.quickAdd,
          strings.quickRevisitLater,
          strings.quickShareWithSomeone,
          strings.quickWorthTrying,
          strings.quickAlreadyChecked,
          strings.daysAgo(2),
          strings.about,
          strings.aboutTagline,
          strings.versionBuild('107', '1.0.7'),
          strings.legal,
          strings.termsOfService,
          strings.privacyPolicy,
          strings.help,
          strings.faq,
          strings.other,
          strings.shareBackup,
          strings.shareBackupDescription,
        ],
        [
          'コレクションを編集',
          'この保存スペースを整えます。',
          'コレクションを削除',
          'もう一度見る価値あり',
          '読書リマインダー',
          'AIによる詳細を追加できます',
          'AIで解析',
          'Glimpseに質問',
          '今夜も気になりますか？',
          'Glimpseにメッセージ…',
          'コレクションに追加',
          '固定',
          '削除',
          '新しいコレクション',
          '保存したアイデアをまとめるスペースを作成します。',
          '自分のメモ',
          '印象に残ったことは？',
          'クイック追加',
          '後で見返す',
          '誰かと共有',
          '試す価値あり',
          '確認済み',
          '2日前',
          'アプリについて',
          '残しておきたいものを保存',
          'バージョン 1.0.7（ビルド 107）',
          '法的情報',
          '利用規約',
          'プライバシーポリシー',
          'ヘルプ',
          'よくある質問',
          'その他',
          'バックアップを共有',
          'バックアップを別のアプリやクラウドサービスに送信',
        ],
      );
    },
  );

  test('reported screens do not retain their hard-coded English headings', () {
    const paths = <String>[
      'lib/features/add_url/add_url_screen.dart',
      'lib/features/home/home_screen.dart',
      'lib/features/home/rediscovery_section.dart',
      'lib/features/sources/sources_screen.dart',
      'lib/features/settings/settings_screen.dart',
      'lib/features/settings/look_and_feel_screen.dart',
      'lib/features/settings/subscription_screen.dart',
      'lib/features/settings/privacy_screen.dart',
      'lib/features/settings/data_backup_screen.dart',
      'lib/features/settings/about_screen.dart',
      'lib/features/settings/bin_screen.dart',
      'lib/features/digest/notification_detail_screen.dart',
      'lib/features/url_detail/url_detail_screen.dart',
      'lib/features/collections/collections_screen.dart',
      'lib/features/collections/collection_card.dart',
      'lib/features/collections/collection_reorder_sheet.dart',
      'lib/features/rediscover/rediscover_screen.dart',
      'lib/features/search/search_screen.dart',
      'lib/features/mindmap/mindmap_screen.dart',
      'lib/features/mindmap/cluster_card.dart',
      'lib/features/library/library_home.dart',
      'lib/features/library/library_browser_screen.dart',
      'lib/features/library/library_places_screen.dart',
      'lib/features/library/library_places_map.dart',
      'lib/features/library/library_entity_detail_screen.dart',
      'lib/features/library/library_widgets.dart',
      'lib/features/library/library_status_picker.dart',
      'lib/features/library/library_radial_status_menu.dart',
      'lib/features/library/library_reading_progress.dart',
      'lib/features/collections/create_collection_sheet.dart',
      'lib/features/collections/collection_detail_screen.dart',
      'lib/features/ask/ask_screen.dart',
      'lib/features/ask/ask_conversation_widgets.dart',
      'lib/features/digest/notifications_screen.dart',
      'lib/core/services/notification_hub_labels.dart',
      'lib/shared/widgets/bulk_selection_toolbar.dart',
      'lib/shared/widgets/music_provider_sheet.dart',
      'lib/shared/widgets/url_processing_presentation.dart',
    ];
    const forbidden = <String>[
      "'Capture something worth returning to'",
      "'Recent Saves'",
      "'Top sources'",
      "'Choose swipe action'",
      "'Where do you listen?'",
      "'Theme preview'",
      "'Smart notifications'",
      "'Mark all read'",
      "'Core Library'",
      "'Storage location'",
      "'Deleted items are kept for 30 days",
      "'Key Takeaways'",
      "'Transcript & Caption'",
      "'People mentioned'",
      "'Library'",
      "'Books, movies & places found in your saves'",
      "'A few memories worth using'",
      "'Weekly and monthly patterns from your own saves.'",
      "'Search your library…'",
      "'Find anything you saved'",
      "'Filters'",
      "'Top signal'",
      "'Growing interests'",
      "'Reading your interests...'",
      "'Found in your saves'",
      "'Recognized and organized by type'",
      "'Recently discovered'",
      "'Year newest'",
      "'Your places'",
      "'Why it mattered'",
      "'Hide from Library'",
      "'Reading status'",
      "'Want to visit'",
      "'Refine this saved space.'",
      "'Create a focused space for saved ideas.'",
      "'Delete collection'",
      "'Worth Revisiting'",
      "'Reading Reminder'",
      "'AI details available'",
      "'Message Glimpse...'",
      "'Still curious tonight?'",
      "'Your note'",
      "'What stood out to you?'",
      "'Quick add'",
      "'Save something worth keeping'",
      "'Terms of Service'",
      "'Privacy Policy'",
      "'Share backup'",
      "'Send a backup to another app or cloud service'",
      "'Reading the reel'",
      "'Pulling out the useful details'",
      "'Finding what matters'",
      "'Finishing your save'",
      "'Couldn\\'t finish processing'",
      "'Link copied'",
    ];

    final source = paths
        .map((path) => File(path).readAsStringSync())
        .join('\n');
    for (final literal in forbidden) {
      expect(
        source,
        isNot(contains(literal)),
        reason: '$literal is not localized.',
      );
    }
  });

  test('Japanese enrichment is useful and survives JSON round-trip', () {
    const result = TranscriptEnrichmentResult(
      schemaVersion: 4,
      outputLocale: 'ja',
      meaningfulTitle: '学びを深める方法',
      summary: '新しい考え方を実践に移すための具体的な方法を説明しています。毎日の小さな行動から始められます。',
      category: 'Education',
      tags: ['学習', '習慣'],
      keyPoints: ['小さく始める', '毎日振り返る'],
    );

    expect(result.hasStructuredEnrichment, isTrue);
    final restored = TranscriptEnrichmentResult.fromJson(result.toJson());
    expect(restored?.outputLocale, 'ja');
    expect(restored?.summary, result.summary);
    expect(restored?.category, 'Education');
  });
}
