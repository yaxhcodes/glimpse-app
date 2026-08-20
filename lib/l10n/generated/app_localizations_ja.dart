// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Glimpse';

  @override
  String get home => 'ホーム';

  @override
  String get collections => 'コレクション';

  @override
  String get interests => '興味';

  @override
  String get search => '検索';

  @override
  String get askGlimpse => 'Glimpseに質問';

  @override
  String get settings => '設定';

  @override
  String get accountAndPlan => 'アカウントとプラン';

  @override
  String get personalization => 'パーソナライズ';

  @override
  String get lookAndFeel => '外観';

  @override
  String get themeAndAccent => 'テーマとアクセントカラー';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システム設定';

  @override
  String get languageEnglish => '英語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSpanish => 'スペイン語';

  @override
  String get languageFrench => 'フランス語';

  @override
  String get languagePortugueseBrazil => 'ポルトガル語（ブラジル）';

  @override
  String get chooseLanguage => '言語を選択';

  @override
  String get musicApp => '音楽アプリ';

  @override
  String get chooseWhereSongsOpen => '曲を開くアプリを選択';

  @override
  String get loadingPreference => '設定を読み込み中';

  @override
  String get libraryGestures => 'ライブラリのジェスチャー';

  @override
  String get notifications => '通知';

  @override
  String get privacyAndData => 'プライバシーとデータ';

  @override
  String get privacy => 'プライバシー';

  @override
  String get privacySubtitle => '端末に残る情報とアップロードされる情報';

  @override
  String get dataAndBackup => 'データとバックアップ';

  @override
  String get dataAndBackupSubtitle => '保存した知識を保護・復元';

  @override
  String get bin => 'ゴミ箱';

  @override
  String get binSubtitle => '削除した項目は30日間保持されます';

  @override
  String get clearAllData => 'すべてのデータを消去';

  @override
  String get clearAllDataSubtitle => '保存したリンクを完全に削除';

  @override
  String get about => 'アプリについて';

  @override
  String get aboutGlimpse => 'Glimpseについて';

  @override
  String get aboutSubtitle => 'バージョン、法的情報、ヘルプ';

  @override
  String get accountActions => 'アカウント操作';

  @override
  String get logOut => 'ログアウト';

  @override
  String get logOutSubtitle => 'この端末からログアウト';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get deleteAccountSubtitle => 'アカウント削除を申請';

  @override
  String get deletingAccount => 'アカウントを削除中…';

  @override
  String get cancel => 'キャンセル';

  @override
  String get deleteAll => 'すべて削除';

  @override
  String get clearAllDataQuestion => 'すべてのデータを消去しますか？';

  @override
  String get clearAllDataWarning => '保存したURLは完全に削除され、元に戻せません。';

  @override
  String get allDataCleared => 'すべてのデータを消去しました';

  @override
  String get logOutQuestion => 'ログアウトしますか？';

  @override
  String get logOutWarning => 'Glimpseアカウントにアクセスするには、再度ログインが必要です。';

  @override
  String get deleteAccountQuestion => 'アカウントを削除しますか？';

  @override
  String get manageSubscription => 'サブスクリプションを管理';

  @override
  String get accountDeleted => 'アカウントを削除しました';

  @override
  String get manageYourPlan => 'プランを管理';

  @override
  String get checkingSaveAllowance => '保存可能回数を確認中';

  @override
  String aiSavesLeft(num count) {
    return '今月のAI保存はあと$count回です';
  }

  @override
  String get captureTitle => '気になった内容を保存しています。';

  @override
  String get captureBody => '準備ができたら通知します。';

  @override
  String savedToCollection(String collectionName) {
    return '$collectionNameに保存しました';
  }

  @override
  String get makingSense => 'Glimpseが内容を整理しています。';

  @override
  String get savedWithoutAi => 'AI解析なしで保存しました';

  @override
  String get aiLimitBody => '今月の無料AI保存を使い切りました。タップしてアップグレードできます。';

  @override
  String get alreadyInYourWorld => 'すでに保存されています。';

  @override
  String get enrichmentFailed => '解析を完了できませんでした';

  @override
  String get tapToRetry => 'タップして再試行してください。';

  @override
  String get notification => '通知';

  @override
  String get today => '今日';

  @override
  String get yesterday => '昨日';

  @override
  String get retry => '再試行';

  @override
  String get close => '閉じる';

  @override
  String get addUrl => 'URLを追加';

  @override
  String get newCollection => '新しいコレクション';

  @override
  String get captured => '保存しました';

  @override
  String get undo => '元に戻す';

  @override
  String get alreadyInGlimpse => 'すでにGlimpseにあります';

  @override
  String get open => '開く';

  @override
  String get tryAgain => 'もう一度試す';

  @override
  String get exitSelection => '選択を終了';

  @override
  String get sources => 'ソース';

  @override
  String get viewAllSources => 'すべてのソースを表示';

  @override
  String get pasteLink => 'リンクを貼り付け…';

  @override
  String get dismissClipboardSuggestion => 'クリップボードの候補を閉じる';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get editCollection => 'コレクションを編集';

  @override
  String get moveContents => '内容を移動';

  @override
  String get deleteSelectedCollections => '選択したコレクションを削除';

  @override
  String get delete => '削除';

  @override
  String get collectionOptions => 'コレクションのオプション';

  @override
  String get grid => 'グリッド';

  @override
  String get list => 'リスト';

  @override
  String get manual => '手動';

  @override
  String get newest => '新しい順';

  @override
  String get alphabetical => '五十音・ABC順';

  @override
  String get reorder => '並べ替え';

  @override
  String get upgradeToPro => 'Proにアップグレード';

  @override
  String get reset => 'リセット';

  @override
  String get applyFilters => 'フィルターを適用';

  @override
  String get newChat => '新しいチャット';

  @override
  String get capture => '保存';

  @override
  String get capturing => '保存中…';

  @override
  String get pasteFromClipboard => 'クリップボードから貼り付け';

  @override
  String get addToCollection => 'コレクションに追加';

  @override
  String get more => 'その他';

  @override
  String get notes => 'メモ';

  @override
  String get categoryTechnology => 'テクノロジー';

  @override
  String get categoryBusiness => 'ビジネス';

  @override
  String get categoryFinance => '金融';

  @override
  String get categoryScience => '科学';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryEducation => '学び';

  @override
  String get categoryNews => 'ニュース';

  @override
  String get categoryDesign => 'デザイン';

  @override
  String get categoryHistory => '歴史';

  @override
  String get categoryPhilosophy => '哲学';

  @override
  String get categoryNature => '自然';

  @override
  String get categoryFood => '食';

  @override
  String get categoryTravel => '旅行';

  @override
  String get categoryEntertainment => 'エンターテインメント';

  @override
  String get categoryLifestyle => 'ライフスタイル';

  @override
  String get categorySports => 'スポーツ';

  @override
  String get categoryOther => 'その他';

  @override
  String minutesAgo(Object count) {
    return '$count分前';
  }

  @override
  String hoursAgo(Object count) {
    return '$count時間前';
  }

  @override
  String daysAgo(Object count) {
    return '$count日前';
  }

  @override
  String get smartNotificationsDescription => '保存したリンクについてのスマート通知';

  @override
  String get done => '完了';

  @override
  String get later => '後で';

  @override
  String get notificationFallbackTitle => '通知';

  @override
  String newNotificationCount(num count) {
    return '新しい通知 $count 件';
  }

  @override
  String get captureSomethingWorthReturning => 'また見返したいものを保存';

  @override
  String get captureContextAfter => '保存すると、Glimpseが内容を整理します。';

  @override
  String get link => 'リンク';

  @override
  String get detectedFromClipboard => 'クリップボードから検出';

  @override
  String get collection => 'コレクション';

  @override
  String get noCollection => 'コレクションなし';

  @override
  String get savingTo => '保存先';

  @override
  String get chooseCollection => 'コレクションを選択';

  @override
  String get chooseACollection => 'コレクションを選択';

  @override
  String get processingLink => 'リンクを処理中…';

  @override
  String get couldNotLoadCollections => 'コレクションを読み込めませんでした。';

  @override
  String linkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のリンク',
      zero: 'リンクなし',
    );
    return '$_temp0';
  }

  @override
  String get noteOptional => 'メモ（任意）';

  @override
  String get addNoteOptional => 'メモを追加（任意）';

  @override
  String get pleaseEnterUrl => 'URLを入力してください';

  @override
  String get couldNotCaptureLink => 'このリンクを保存できませんでした';

  @override
  String get findingSavedVersion => '保存済みの項目を探しています…';

  @override
  String get openSavedItem => '保存済みの項目を開く';

  @override
  String collectionSelection(String collectionName) {
    return 'コレクション、$collectionName';
  }

  @override
  String get capturedInGlimpse => 'Glimpseに保存しました';

  @override
  String get firstCapturedReady => '最初に保存した項目が下に表示されています。';

  @override
  String get shareAnyApp => 'どのアプリからでも共有できます。Glimpseが自動で整理します。';

  @override
  String get howGlimpseWorks => 'Glimpseの使い方';

  @override
  String get capturingWhatCaughtYourEye => '気になった内容を保存中';

  @override
  String get findingContext => '内容を確認中';

  @override
  String get invalidLink => '無効なリンク';

  @override
  String get rediscover => '再発見';

  @override
  String get rediscoverSubtitle => 'もう一度見てみませんか';

  @override
  String get rediscoverTip => '毎日、見返す価値のある思い出をいくつか選びます。';

  @override
  String get dismissRediscoverTip => '再発見のヒントを閉じる';

  @override
  String get pinned => '固定済み';

  @override
  String get recentSaves => '最近の保存';

  @override
  String get justNow => 'たった今';

  @override
  String weeksAgo(Object count) {
    return '$count週間前';
  }

  @override
  String monthsAgo(Object count) {
    return '$countか月前';
  }

  @override
  String yearsAgo(Object count) {
    return '$count年前';
  }

  @override
  String get retrying => '再試行中';

  @override
  String get processing => '処理中';

  @override
  String get needsAttention => '確認が必要';

  @override
  String get read => '既読';

  @override
  String get unread => '未読';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get linkCopied => 'リンクをコピーしました';

  @override
  String get openOriginal => '元のページを開く';

  @override
  String get share => '共有';

  @override
  String get enrichmentComplete => 'AI処理が完了しました';

  @override
  String get couldNotEnrichSave => 'この保存項目を処理できませんでした';

  @override
  String get allSources => 'すべてのソース';

  @override
  String get all => 'すべて';

  @override
  String get apps => 'アプリ';

  @override
  String get websites => 'ウェブサイト';

  @override
  String get results => '検索結果';

  @override
  String get topSources => 'よく使うソース';

  @override
  String get searchSources => 'アプリ、サイト、ドメインを検索…';

  @override
  String get filterSources => 'ソースを絞り込む';

  @override
  String get couldNotLoadSources => 'ソースを読み込めませんでした';

  @override
  String noSourcesMatch(String query) {
    return '「$query」に一致するソースはありません';
  }

  @override
  String get noSavesFromApps => 'アプリからの保存はまだありません';

  @override
  String get noWebsiteSaves => 'ウェブサイトからの保存はまだありません';

  @override
  String get noSourcesYet => 'ソースはまだありません';

  @override
  String get noSavesYet => '保存はまだありません';

  @override
  String saveCount(num count) {
    return '$count件の保存';
  }

  @override
  String savesThisWeek(Object count) {
    return '今週 +$count';
  }

  @override
  String get growing => '増加中';

  @override
  String lastSaved(String time) {
    return '最終保存 $time';
  }

  @override
  String get leftSwipe => '左スワイプ';

  @override
  String get rightSwipe => '右スワイプ';

  @override
  String get chooseSwipeAction => 'スワイプ操作を選択';

  @override
  String get markReadUnread => '既読／未読にする';

  @override
  String get pin => '固定';

  @override
  String get none => 'なし';

  @override
  String get smartNotifications => 'スマート通知';

  @override
  String get behaviorBasedAlerts => '利用状況に合わせたお知らせ';

  @override
  String get whereDoYouListen => 'どのアプリで聴きますか？';

  @override
  String get chooseMusicProvider => '見つけた曲を開くアプリを選択してください。';

  @override
  String get brightness => '明るさ';

  @override
  String get brightnessDescription => 'ライトまたはダーク表示を使用するタイミングを選択します。';

  @override
  String get systemTheme => 'システム';

  @override
  String get lightTheme => 'ライト';

  @override
  String get darkTheme => 'ダーク';

  @override
  String get amoledBlack => 'AMOLEDブラック';

  @override
  String get amoledUnavailable => 'ライトテーマ以外で利用できます。';

  @override
  String get amoledDescription => 'OLEDで完全な黒背景を使用し、電力を節約します。';

  @override
  String get accentColor => 'アクセントカラー';

  @override
  String get dynamicAccentDescription => '対応端末では壁紙のカラーパレットを使用します。';

  @override
  String selectedAccent(String accent) {
    return '選択中：$accent';
  }

  @override
  String get themePreview => 'テーマのプレビュー';

  @override
  String get themePreviewDescription => '下の選択に合わせてアクセントと背景が更新されます。';

  @override
  String get accentDynamic => 'ダイナミック';

  @override
  String get accentPurple => '紫';

  @override
  String get accentBlue => '青';

  @override
  String get accentTeal => 'ティール';

  @override
  String get accentGreen => '緑';

  @override
  String get accentLime => 'ライム';

  @override
  String get accentYellow => '黄';

  @override
  String get accentOrange => 'オレンジ';

  @override
  String get accentRed => '赤';

  @override
  String get accentPink => 'ピンク';

  @override
  String get accentSakura => '桜';

  @override
  String get accentIndigo => '藍';

  @override
  String get accentSlate => 'スレート';

  @override
  String get accentMonochrome => 'モノクロ';

  @override
  String get deleted => '削除しました';

  @override
  String get noNotificationsYet => '通知はまだありません';

  @override
  String get notificationsEmptyDescription =>
      '旅行のお知らせ、新しい発見、読書のリマインダー、週間ダイジェストがここに表示されます。';

  @override
  String get ready => '準備完了';

  @override
  String waitingCount(num count) {
    return '未読 $count件';
  }

  @override
  String get backInView => '再び注目';

  @override
  String get couldNotLoadSource => 'このソースを読み込めませんでした';

  @override
  String get noSavesFromSource => 'このソースからの保存はありません';

  @override
  String get saves => '保存';

  @override
  String get thisWeek => '今週';

  @override
  String get opened => '閲覧済み';

  @override
  String get topThemes => '主なテーマ';

  @override
  String get allItems => 'すべての項目';

  @override
  String get oldest => '古い順';

  @override
  String get recentlyOpened => '最近開いた順';

  @override
  String get showItems => '表示する項目';

  @override
  String get sortBy => '並べ替え';

  @override
  String get noItemsFromSource => 'このソースには項目がありません';

  @override
  String get noUnreadItems => '未読の項目はありません';

  @override
  String get noReadItems => '既読の項目はありません';

  @override
  String get lastSavedLabel => '最終保存';

  @override
  String get markAllRead => 'すべて既読にする';

  @override
  String get back => '戻る';

  @override
  String get subscription => 'サブスクリプション';

  @override
  String get couldNotLoadSubscription => 'サブスクリプション情報を読み込めませんでした';

  @override
  String get coreLibrary => '基本ライブラリ';

  @override
  String get unlimitedLinkSaving => 'リンクを無制限に保存';

  @override
  String get unlimitedLinkSavingDescription => '好きなだけリンクを保存できます';

  @override
  String get collectionsOrganization => 'コレクションと整理';

  @override
  String get collectionsOrganizationDescription => '自分らしくブックマークを整理・管理';

  @override
  String get smartNotificationsLongDescription => '行動に合わせた通知と読書リマインダー';

  @override
  String get aiAssistant => 'AIアシスタント';

  @override
  String get aiTaggingCategorization => 'AIタグ付けと分類';

  @override
  String get freeSavesProUnlimited => '無料：月30件・Pro：無制限';

  @override
  String get keywordSearch => 'キーワード検索';

  @override
  String get freeSearchesProUnlimited => '無料：月30回・Pro：無制限';

  @override
  String get askYourBookmarks => 'ブックマークに質問';

  @override
  String get freeQuestionsProUnlimited => '無料：月30問・Pro：無制限';

  @override
  String get proInsights => 'Proインサイト';

  @override
  String get semanticSearch => '意味検索';

  @override
  String get semanticSearchDescription => '単語だけでなく意味からリンクを検索';

  @override
  String get weeklyRecap => '週間まとめ';

  @override
  String get weeklyRecapDescription => '保存したリンクをAIが要約';

  @override
  String get multiLinkSynthesis => '複数リンクの統合分析';

  @override
  String get multiLinkSynthesisDescription => '複数のブックマークを横断して分析';

  @override
  String get active => '有効';

  @override
  String get free => '無料';

  @override
  String get proPlanDescription => 'ライブラリ全体で、すべてのAI機能を制限なく利用できます。';

  @override
  String get proPlanDevDescription =>
      'ライブラリ全体で、すべてのAI機能を制限なく利用できます。（開発用上書き、ストア：無料）';

  @override
  String get freePlanDescription =>
      '基本機能で自分だけの知識ライブラリを作れます。アップグレード前に試せるAI機能も含まれます。';

  @override
  String get upgradeToGlimpsePro => 'Glimpse Proにアップグレード';

  @override
  String get restorePurchases => '購入を復元';

  @override
  String get manageOnGooglePlay => 'Google Playで管理';

  @override
  String get local => '端末内';

  @override
  String get uploaded => 'アップロードされる情報';

  @override
  String get bookmarks => 'ブックマーク';

  @override
  String get aiSummaries => 'AI要約';

  @override
  String get accountInformation => 'アカウント情報';

  @override
  String get subscriptionStatus => 'サブスクリプション状況';

  @override
  String get anonymousProductAnalytics => '匿名の製品分析データ';

  @override
  String get storageLocation => '保存場所';

  @override
  String get pickAFolder => 'フォルダーを選択';

  @override
  String get chooseBackupFolderDescription => 'バックアップの保存先を選択します';

  @override
  String get backupFolderInfo =>
      'バックアップファイルの保存に使用します。一度フォルダーを選ぶと、Glimpseはそこに新しいバックアップを書き込みます。';

  @override
  String get automaticBackup => '自動バックアップ';

  @override
  String get off => 'オフ';

  @override
  String get backupFrequencyDescription => '保存場所へバックアップする頻度';

  @override
  String get backupSensitiveInfo =>
      'バックアップのコピーは別の場所にも保管できます。ライブラリ全体が含まれる場合があるため、共有時は機密情報として扱ってください。';

  @override
  String get backupAndRestore => 'バックアップと復元';

  @override
  String get createBackup => 'バックアップを作成';

  @override
  String get restoreBackup => 'バックアップを復元';

  @override
  String lastBackup(Object time) {
    return '前回のバックアップ：$time';
  }

  @override
  String get backupLocalInfo =>
      'バックアップにはリンク、コレクション、タグ、メタデータを含むライブラリ全体が保存されます。データは端末内に残ります。';

  @override
  String get deletedItemsRetention =>
      '削除した項目は30日間保管され、その後Glimpseの次回クリーンアップ時に完全に削除されます。';

  @override
  String daysLeft(num count) {
    return '残り$count日';
  }

  @override
  String get expiresToday => '本日まで';

  @override
  String get restore => '復元';

  @override
  String get deletePermanently => '完全に削除';

  @override
  String get restoreAll => 'すべて復元';

  @override
  String get emptyBin => 'ゴミ箱を空にする';

  @override
  String get binActions => 'ゴミ箱の操作';

  @override
  String get itemActions => '項目の操作';

  @override
  String get binIsEmpty => 'ゴミ箱は空です';

  @override
  String get binEmptyDescription => '削除した項目は30日間ここに表示されます。';

  @override
  String get deleteAccountProWarning =>
      'Glimpseアカウントのメタデータは削除されますが、ストアの請求は解約されません。Proは別のGlimpseアカウントへ移行できないため、削除前にサブスクリプションを管理してください。端末内のライブラリはSupabaseにアップロードされていません。';

  @override
  String get deleteAccountFreeWarning =>
      'Glimpseアカウントのメタデータを削除します。端末内のライブラリはSupabaseにアップロードされていません。';

  @override
  String get details => '詳細';

  @override
  String openInSource(Object source) {
    return '$sourceで開く';
  }

  @override
  String get summary => '要約';

  @override
  String get addNote => 'メモを追加';

  @override
  String get keyTakeaways => '重要ポイント';

  @override
  String get fullBreakdown => '詳しい内容';

  @override
  String get transcriptAndCaption => '文字起こしとキャプション';

  @override
  String get caption => 'キャプション';

  @override
  String get transcript => '文字起こし';

  @override
  String get onScreenText => '画面上のテキスト';

  @override
  String get peopleMentioned => '登場人物';

  @override
  String peopleMentionedCount(num count) {
    return '$count人に言及';
  }

  @override
  String get alsoMentioned => 'その他の言及';

  @override
  String get quotes => '引用';

  @override
  String get tags => 'タグ';

  @override
  String get informationMayBeInaccurate => '情報が正確でない場合があります';

  @override
  String get originalContentAttribution => '元のコンテンツの権利は作成者に帰属します。';

  @override
  String everyHours(Object count) {
    return '$count時間ごと';
  }

  @override
  String get weekly => '毎週';

  @override
  String get addTag => 'タグを追加';

  @override
  String get changeCategory => 'カテゴリーを変更';

  @override
  String get worthWatching => '注目の作品';

  @override
  String get worthReading => 'おすすめの本';

  @override
  String get gamesMentioned => '登場するゲーム';

  @override
  String get musicMentioned => '登場する音楽';

  @override
  String get toolsMentioned => '登場するツール';

  @override
  String get worthALook => '注目ポイント';

  @override
  String get appsToTry => '試したいアプリ';

  @override
  String get placesToVisit => '訪れたい場所';

  @override
  String get websitesMentioned => '登場するウェブサイト';

  @override
  String get claimsToRemember => '覚えておきたい主張';

  @override
  String get termsMentioned => '登場する用語';

  @override
  String get notableDetails => '注目すべき詳細';

  @override
  String get library => 'ライブラリ';

  @override
  String get libraryDescription => '保存から見つかった本、映画、場所';

  @override
  String get buildsQuietly => '保存するたびに少しずつ育ちます';

  @override
  String itemCount(num count) {
    return '$count件';
  }

  @override
  String addedTime(Object time) {
    return '追加 · $time';
  }

  @override
  String get rediscoverIntentTitle => '活用したい思い出';

  @override
  String chosenFromUnopened(Object count) {
    return '未読の保存$count件と、今大切なものから選びました。';
  }

  @override
  String get chosenFromSaved => '保存したもの、開いたもの、あとで見るものから選びました。';

  @override
  String get todayStableSet => '今日のための厳選セット。終わりのないフィードはありません。';

  @override
  String get recaps => 'まとめ';

  @override
  String get recapsDescription => '自分の保存から見える週間・月間の傾向。';

  @override
  String get dailyRecap => 'デイリーまとめ';

  @override
  String get monthlyRecap => '月間まとめ';

  @override
  String recapSummary(num count, Object waiting) {
    return '$count件の保存 · 未読$waiting件';
  }

  @override
  String get yourWeekInSaves => '今週の保存';

  @override
  String get yourMonthInMemories => '今月の思い出';

  @override
  String topicKeptShowingUp(Object topic) {
    return '$topicがよく登場しました';
  }

  @override
  String get queued => '待機中';

  @override
  String get forgottenGem => '忘れていた発見';

  @override
  String get fromYourPast => '過去の保存から';

  @override
  String get rediscoverOptions => '再発見の操作';

  @override
  String get notNow => '今はしない';

  @override
  String get hideFor7Days => '7日間非表示';

  @override
  String get lessLikeThis => 'このような内容を減らす';

  @override
  String get reduceSimilarTopics => '似たトピックを減らします';

  @override
  String get nothingStrongToday => '今日はおすすめがありません';

  @override
  String get rediscoverQuiet => '本当に見返す価値のある保存が見つかるまで、再発見は静かに待機します。';

  @override
  String get searchYourLibrary => 'ライブラリを検索…';

  @override
  String get findAnythingSaved => '保存したものを検索';

  @override
  String get searchEmptyDescription => 'タイトル、タグ、メモ、要約から検索し、条件で絞り込めます。';

  @override
  String get filters => 'フィルター';

  @override
  String get filtersActive => 'フィルター適用中';

  @override
  String get time => '期間';

  @override
  String get allTime => 'すべての期間';

  @override
  String get thisMonth => '今月';

  @override
  String get status => 'ステータス';

  @override
  String get hasNotes => 'メモあり';

  @override
  String get noNotes => 'メモなし';

  @override
  String get inCollection => 'コレクション内';

  @override
  String get notInCollection => 'コレクション外';

  @override
  String get specificCollection => 'コレクションを指定';

  @override
  String get sort => '並べ替え';

  @override
  String get relevance => '関連度';

  @override
  String get newestSaved => '新しい保存順';

  @override
  String get oldestSaved => '古い保存順';

  @override
  String get learningInterests => '興味の傾向を分析中';

  @override
  String get readingInterests => '興味を読み取り中…';

  @override
  String get topSignal => '最も強い関心';

  @override
  String get growingInterests => '高まりつつある関心';

  @override
  String get quieterInterests => 'その他の関心';

  @override
  String interestStats(num patterns, num saves) {
    return '$patterns個のパターン · $saves件の保存';
  }

  @override
  String interestGroupedStats(Object grouped, num patterns, Object saves) {
    return '$patterns個のパターン · $saves件中$grouped件を分類';
  }

  @override
  String noPatternsScanned(Object saves) {
    return 'パターンはまだありません · $saves件を分析済み';
  }

  @override
  String get rebuildMap => 'マップを再構築';

  @override
  String get couldNotBuildClusters => '関心グループを作成できませんでした';

  @override
  String get interestMapEmpty => '興味マップはまだ空です';

  @override
  String get interestMapEmptyDescription =>
      '3件以上のリンクを保存すると、Glimpseが繰り返し現れるテーマをつなぎます。';

  @override
  String lastAddedTime(Object time) {
    return '最終追加: $time';
  }

  @override
  String get hiddenFor7Days => '7日間非表示にしました';

  @override
  String get seeLessLikeThis => 'このような内容の表示を減らします';

  @override
  String get searchingLibrary => 'ライブラリを検索中…';

  @override
  String get semanticMatch => '意味で一致';

  @override
  String get noMatchesForFilter => 'このフィルターに一致するものはありません';

  @override
  String get broadenSearch => '期間を変えるか、検索条件を広げてください。';

  @override
  String get monthlyLimitReached => '月間上限に達しました';

  @override
  String get searchFailed => '検索できませんでした';

  @override
  String get monthlySearchLimitDescription =>
      '今月の検索上限に達しました。無制限に検索するにはGlimpse Proへアップグレードしてください。';

  @override
  String get openingInterest => '関心を開いています…';

  @override
  String get couldNotOpenInterest => 'この関心を開けませんでした。';

  @override
  String get interestNotFound => '関心が見つかりません';

  @override
  String interestSummary(num count) {
    return 'この関心には$count件の保存があります。';
  }

  @override
  String interestTopicsSummary(Object count, Object topics) {
    return '$count件の保存、$topics個のトピック';
  }

  @override
  String get reorderCollections => 'コレクションを並べ替え';

  @override
  String get dragToSetManualOrder => 'ドラッグして手動の順序を設定';

  @override
  String movedToCollection(Object name) {
    return '$nameに移動しました';
  }

  @override
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount) {
    return '$count件のリンクを$nameに移動し、元のコレクション$sourceCount個を削除しました';
  }

  @override
  String deleteCollectionNamed(Object name) {
    return '「$name」を削除しますか？';
  }

  @override
  String deleteCollectionsCount(Object count) {
    return '$count個のコレクションを削除しますか？';
  }

  @override
  String get deleteCollectionDescription => '保存したリンクはライブラリに残り、コレクションのみ削除されます。';

  @override
  String get deleteCollectionsDescription => '保存したリンクはライブラリに残り、コレクションのみ削除されます。';

  @override
  String collectionsDeleted(num count) {
    return '$count個のコレクションを削除しました';
  }

  @override
  String get createFirstCollection => '最初のコレクションを作成';

  @override
  String get collectionEmptyDescription => 'リンクを落ち着いて見返せる場所にまとめましょう。';

  @override
  String get libraryBooks => '本';

  @override
  String get libraryMoviesShows => '映画・番組';

  @override
  String get libraryPlaces => '場所';

  @override
  String get libraryBook => '本';

  @override
  String get libraryMovie => '映画';

  @override
  String get libraryPlace => '場所';

  @override
  String get libraryReadingList => '読書リスト';

  @override
  String get libraryWatchlist => '視聴リスト';

  @override
  String get libraryNotInReadingList => '読書リスト未登録';

  @override
  String get libraryNotInWatchlist => '視聴リスト未登録';

  @override
  String get libraryNotListed => '未登録';

  @override
  String get libraryPlanning => '予定';

  @override
  String get libraryReading => '読書中';

  @override
  String get libraryWatching => '視聴中';

  @override
  String get libraryInProgress => '進行中';

  @override
  String get libraryDropped => '中断';

  @override
  String get libraryRead => '読了';

  @override
  String get libraryWatched => '視聴済み';

  @override
  String get libraryVisited => '訪問済み';

  @override
  String libraryStatusSemantics(Object status) {
    return 'ステータス: $status';
  }

  @override
  String libraryReadingPageStatus(Object page) {
    return '読書中 · $pageページ';
  }

  @override
  String get libraryGenreFantasy => 'ファンタジー';

  @override
  String get libraryGenreScienceFiction => 'SF';

  @override
  String get libraryGenreMysteryThriller => 'ミステリー・スリラー';

  @override
  String get libraryGenreRomance => 'ロマンス';

  @override
  String get libraryGenreHorror => 'ホラー';

  @override
  String get libraryGenreBiographyMemoir => '伝記・回想録';

  @override
  String get libraryGenreHistory => '歴史';

  @override
  String get libraryGenrePhilosophy => '哲学';

  @override
  String get libraryGenrePsychology => '心理学';

  @override
  String get libraryGenreBusiness => 'ビジネス';

  @override
  String get libraryGenreFinanceInvesting => '金融・投資';

  @override
  String get libraryGenreTechnology => 'テクノロジー';

  @override
  String get libraryGenreScience => '科学';

  @override
  String get libraryGenreSelfDevelopment => '自己啓発';

  @override
  String get libraryGenreHealthWellness => '健康・ウェルネス';

  @override
  String get libraryGenrePoliticsSociety => '政治・社会';

  @override
  String get libraryGenreArtDesign => 'アート・デザイン';

  @override
  String get libraryGenreTravel => '旅行';

  @override
  String get libraryGenreComicsGraphicNovels => 'コミック・グラフィックノベル';

  @override
  String get libraryGenreFiction => 'フィクション';

  @override
  String get libraryGenreAction => 'アクション';

  @override
  String get libraryGenreAdventure => 'アドベンチャー';

  @override
  String get libraryGenreAnimation => 'アニメーション';

  @override
  String get libraryGenreComedy => 'コメディ';

  @override
  String get libraryGenreCrime => '犯罪';

  @override
  String get libraryGenreDocumentary => 'ドキュメンタリー';

  @override
  String get libraryGenreDrama => 'ドラマ';

  @override
  String get libraryGenreFamily => 'ファミリー';

  @override
  String get libraryGenreMystery => 'ミステリー';

  @override
  String get libraryGenreThriller => 'スリラー';

  @override
  String get libraryGenreWar => '戦争';

  @override
  String get libraryGenreWestern => '西部劇';

  @override
  String get libraryGenreMusic => '音楽';

  @override
  String get libraryGenreOther => 'その他';

  @override
  String get librarySubtypeTvShow => 'テレビ番組';

  @override
  String get librarySubtypeSeries => 'シリーズ';

  @override
  String get couldNotOpenLibrary => 'ライブラリを開けませんでした';

  @override
  String searchLibraryItems(Object kind) {
    return '$kindを検索';
  }

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get recentlyDiscovered => '最近見つかった順';

  @override
  String get titleAZ => 'タイトル A〜Z';

  @override
  String get yearNewest => '新しい年順';

  @override
  String libraryOptions(Object kind) {
    return '$kindのオプション';
  }

  @override
  String filterLibraryItems(Object kind) {
    return '$kindを絞り込む';
  }

  @override
  String get readingStatus => '読書ステータス';

  @override
  String get watchStatus => '視聴ステータス';

  @override
  String get anyStatus => 'すべてのステータス';

  @override
  String get genre => 'ジャンル';

  @override
  String get allGenres => 'すべてのジャンル';

  @override
  String get nothingMatchesFilters => 'このフィルターに一致するものはありません。';

  @override
  String get nothingRecognizedHere => 'まだ見つかったものはありません。';

  @override
  String get couldNotUpdateLibraryItem => 'ライブラリ項目を更新できませんでした。';

  @override
  String get foundInYourSaves => '保存から見つかったもの';

  @override
  String get recognizedOrganizedByType => '種類ごとに認識・整理されています';

  @override
  String libraryBookCount(num count) {
    return '$count冊';
  }

  @override
  String libraryMovieCount(num count) {
    return '$count本';
  }

  @override
  String libraryPlaceCount(num count) {
    return '$countか所';
  }

  @override
  String libraryStopCount(num count) {
    return '$countか所';
  }

  @override
  String get nothingRecognizedYet => 'まだ見つかったものはありません';

  @override
  String get recognizedTitlesGatherHere => '見つかったタイトルがここに集まります';

  @override
  String recognizedCount(Object count) {
    return '$count件を認識';
  }

  @override
  String get savedPlacesAppearOnMap => '保存した場所が地図に表示されます';

  @override
  String get addingDetails => '詳細を追加中';

  @override
  String get extraDetailsUnavailable => '追加情報は一時的に利用できません';

  @override
  String itemsCouldNotRefresh(num count) {
    return '$count件を更新できませんでした';
  }

  @override
  String progressOf(Object completed, Object total) {
    return '$completed/$total';
  }

  @override
  String get savedDetailsRemainAvailable => '保存済みの詳細は引き続き利用できます';

  @override
  String waitingToRetry(Object count) {
    return '$count件が再試行待ち';
  }

  @override
  String get libraryBuildsAsYouSave => '保存するたびに育ちます';

  @override
  String get libraryEmptyDescription =>
      '本、映画、場所のおすすめを保存すると、Glimpseがその中身をここに整理します。';

  @override
  String get libraryUnavailable => '現在ライブラリを利用できません';

  @override
  String get yourPlaces => 'あなたの場所';

  @override
  String placesAreasSummary(num areas, num places) {
    return '$placesか所 · $areasエリア';
  }

  @override
  String get planThisArea => 'このエリアを計画';

  @override
  String get planAnItinerary => '旅程を計画';

  @override
  String get searchSavedPlaces => '保存した場所を検索';

  @override
  String get yourPlans => 'あなたのプラン';

  @override
  String get plan => '計画';

  @override
  String get locationUnavailable => '位置情報なし';

  @override
  String openNamedItem(Object name) {
    return '$nameを開く';
  }

  @override
  String get wantToVisit => '行きたい';

  @override
  String get savedPlace => '保存した場所';

  @override
  String get planAVisit => '訪問を計画';

  @override
  String get maps => 'マップ';

  @override
  String get noSavedPlacesMatch => '検索に一致する保存済みの場所はありません。';

  @override
  String get noPlacesDiscovered => 'まだ場所が見つかっていません';

  @override
  String get placesMentionedGatherHere => '保存内で言及された場所がここに集まります。';

  @override
  String get fitAllPlaces => 'すべての場所を表示';

  @override
  String get noMappedPlaces => '地図に表示できる場所はまだありません';

  @override
  String get mapUnavailablePlacesListed => '地図を利用できません。場所の一覧は下に表示されています';

  @override
  String get libraryItemUnavailable => 'このライブラリ項目は利用できません。';

  @override
  String get couldNotUpdateBookmark => 'しおりを更新できませんでした。';

  @override
  String hiddenFromLibrary(Object name) {
    return '$nameをライブラリから非表示にしました';
  }

  @override
  String get libraryItemOptions => 'ライブラリ項目のオプション';

  @override
  String get hideFromLibrary => 'ライブラリから非表示';

  @override
  String get addToReadingList => '読書リストに追加';

  @override
  String get addToWatchlist => '視聴リストに追加';

  @override
  String get removeFromReadingList => '読書リストから削除';

  @override
  String get removeFromWatchlist => '視聴リストから削除';

  @override
  String get whyItMattered => '注目した理由';

  @override
  String get plot => 'あらすじ';

  @override
  String get yourBookmark => 'しおり';

  @override
  String get savePageYouAreOn => '現在のページを保存';

  @override
  String savePlaceAboutPages(Object count) {
    return '読書位置を保存 · 約$countページ';
  }

  @override
  String pageNumber(Object page) {
    return '$pageページ';
  }

  @override
  String pageAboutPages(Object count, Object page) {
    return '$pageページ · 全約$countページ';
  }

  @override
  String get setCurrentPage => '現在のページを設定';

  @override
  String get updatePage => 'ページを更新';

  @override
  String get updateYourBookmark => 'しおりを更新';

  @override
  String aboutPages(Object count) {
    return '約$countページ';
  }

  @override
  String get currentPage => '現在のページ';

  @override
  String get enterPageNumber => 'ページ番号を入力';

  @override
  String get saveBookmark => 'しおりを保存';

  @override
  String get pageGreaterThanZero => '1以上のページ番号を入力してください';

  @override
  String libraryItemSemantics(Object kind, Object title) {
    return '$kind: $title';
  }

  @override
  String libraryItemOpenHint(Object list) {
    return 'ダブルタップして開きます。長押しで$listのステータスを変更します。';
  }

  @override
  String get collectionEditSubtitle => 'この保存スペースを整えます。';

  @override
  String get collectionCreateSubtitle => '保存したアイデアをまとめるスペースを作成します。';

  @override
  String get nameLabel => '名前';

  @override
  String get descriptionLabel => '説明';

  @override
  String get collectionNameHint => '旅と散策';

  @override
  String get collectionDescriptionHint => 'このスペースについてのメモ（任意）';

  @override
  String get save => '保存';

  @override
  String get create => '作成';

  @override
  String get nameCollectionError => 'コレクション名を入力してください';

  @override
  String get duplicateCollectionError => '同じ名前のコレクションがすでにあります';

  @override
  String get deleteCollection => 'コレクションを削除';

  @override
  String get addLink => 'リンクを追加';

  @override
  String get noLinksInCollection => 'このコレクションにはまだリンクがありません。';

  @override
  String get notificationTravelPlaces => '旅行と場所';

  @override
  String get notificationNewDiscovery => '新しい発見';

  @override
  String get notificationReadingReminder => '読書リマインダー';

  @override
  String get notificationActivity => 'アクティビティ';

  @override
  String get notificationWorthRevisiting => 'もう一度見る価値あり';

  @override
  String get notificationRevisitReminder => '再訪リマインダー';

  @override
  String get notificationWeeklyDigest => '週間ダイジェスト';

  @override
  String get enrichmentNeedsAttention => 'AI解析を完了できませんでした';

  @override
  String get aiDetailsAvailable => 'AIによる詳細を追加できます';

  @override
  String get enrich => 'AIで解析';

  @override
  String get enriching => '解析中';

  @override
  String get messageGlimpse => 'Glimpseにメッセージ…';

  @override
  String get askAboutThisSave => 'この保存について質問…';

  @override
  String get sending => '送信中…';

  @override
  String get send => '送信';

  @override
  String get askGreetingEarlyMorning => '早起きですね。';

  @override
  String get askGreetingMorning => 'おはようございます。';

  @override
  String get askGreetingAfternoon => '何を探してみますか？';

  @override
  String get askGreetingEvening => 'こんばんは。';

  @override
  String get askGreetingNight => '今夜も気になりますか？';

  @override
  String get askGreetingLateNight => '今夜も夜更かしですか？';

  @override
  String get saveYourFirstLink => '最初のリンクを保存しましょう';

  @override
  String get moreSelectionActions => 'その他の選択操作';

  @override
  String get moveToCollection => 'コレクションに移動';

  @override
  String get markRead => '既読にする';

  @override
  String get markUnread => '未読にする';

  @override
  String get toggleReadStatus => '既読状態を切り替え';

  @override
  String get unpin => '固定を解除';

  @override
  String get yourNote => '自分のメモ';

  @override
  String get edit => '編集';

  @override
  String get notePrompt => '印象に残ったことは？';

  @override
  String get quickAdd => 'クイック追加';

  @override
  String get noteSaving => '保存中…';

  @override
  String get noteSaved => '保存済み';

  @override
  String get noteCouldNotSave => '保存できませんでした';

  @override
  String get addYourNote => '自分のメモを追加';

  @override
  String get showLess => '表示を減らす';

  @override
  String get showMore => 'さらに表示';

  @override
  String showAllCount(Object count) {
    return 'すべて表示（$count件）';
  }

  @override
  String get answerCopied => '回答をコピーしました';

  @override
  String get deleteAskNoteQuestion => 'Askのメモを削除しますか？';

  @override
  String get deleteAskNoteDescription => 'このリンクに保存した回答のみ削除されます。自分のメモには影響しません。';

  @override
  String get askNoteDeleted => 'Askのメモを削除しました';

  @override
  String get couldNotDeleteAskNote => 'Askのメモを削除できませんでした';

  @override
  String get askNoteActions => 'Askメモの操作';

  @override
  String get copyAnswer => '回答をコピー';

  @override
  String get quickTryThisWeekend => '今週末に試す';

  @override
  String get quickNeedIngredients => '材料が必要';

  @override
  String get quickShareWithSomeone => '誰かと共有';

  @override
  String get quickAlreadyTried => '試し済み';

  @override
  String get quickWatchLater => '後で見る';

  @override
  String get quickAddToWatchlist => 'ウォッチリストに追加';

  @override
  String get quickAlreadyWatched => '視聴済み';

  @override
  String get quickAddToReadingList => '読書リストに追加';

  @override
  String get quickReadLater => '後で読む';

  @override
  String get quickResearchThis => 'これを調べる';

  @override
  String get quickAlreadyRead => '読了済み';

  @override
  String get quickTryThisTool => 'このツールを試す';

  @override
  String get quickCompareAlternatives => '代替案を比較';

  @override
  String get quickUseInProject => 'プロジェクトで使う';

  @override
  String get quickShareWithTeam => 'チームと共有';

  @override
  String get quickPlanItinerary => '旅程を計画';

  @override
  String get quickCheckBestSeason => 'ベストシーズンを確認';

  @override
  String get quickSaveRoute => 'ルートを保存';

  @override
  String get quickPracticeLater => '後で練習';

  @override
  String get quickMakeChecklist => 'チェックリストを作る';

  @override
  String get quickRevisitNotes => 'メモを見返す';

  @override
  String get quickRevisitLater => '後で見返す';

  @override
  String get quickWorthTrying => '試す価値あり';

  @override
  String get quickAlreadyChecked => '確認済み';

  @override
  String get aboutTagline => '残しておきたいものを保存';

  @override
  String versionBuild(Object build, Object version) {
    return 'バージョン $version（ビルド $build）';
  }

  @override
  String get loadingVersion => 'バージョンを読み込み中…';

  @override
  String get legal => '法的情報';

  @override
  String get termsOfService => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get help => 'ヘルプ';

  @override
  String get faq => 'よくある質問';

  @override
  String get other => 'その他';

  @override
  String get shareBackup => 'バックアップを共有';

  @override
  String get shareBackupDescription => 'バックアップを別のアプリやクラウドサービスに送信';

  @override
  String backupSavedLinksTo(num count, Object location) {
    return '$locationに$count件のリンクを保存しました';
  }

  @override
  String backupSavedTo(Object location) {
    return 'バックアップを$locationに保存しました';
  }

  @override
  String get errorDetails => 'エラーの詳細';

  @override
  String get copy => 'コピー';

  @override
  String get couldNotReadSelectedFile => '選択したファイルを読み込めませんでした。';

  @override
  String get folderSelected => 'フォルダーを選択済み';

  @override
  String get couldNotSaveFolderPermission =>
      'フォルダーへのアクセス権を保存できませんでした。もう一度お試しください。';

  @override
  String get permanentBackupFolderAndroid => '固定のバックアップフォルダーはAndroidで利用できます';

  @override
  String get tapToChange => 'タップして変更';

  @override
  String get forgetFolder => 'フォルダー設定を解除';

  @override
  String get autoBackupAndroidOnly => '保存フォルダーを設定するとAndroidで自動バックアップが実行されます';

  @override
  String lastAutomaticBackup(Object time) {
    return '前回の自動バックアップ：$time';
  }

  @override
  String lastBackupAttemptFailed(Object time) {
    return '前回の試行は$timeに失敗しました。Glimpseが自動的に再試行します。';
  }

  @override
  String get setStorageBeforeAutoBackup => '自動バックアップを使用するには、上で保存場所を設定してください。';

  @override
  String get folderBackup => 'フォルダーのバックアップ';

  @override
  String lastSavedToFolder(Object time) {
    return 'フォルダーへの最終保存：$time';
  }

  @override
  String get noBackupFileInFolder =>
      'このフォルダーにはまだバックアップがありません。保存場所を選んだ後、上の「バックアップを作成」を使用してください。';
}
