// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Glimpse';

  @override
  String get home => 'Início';

  @override
  String get collections => 'Coleções';

  @override
  String get interests => 'Interesses';

  @override
  String get search => 'Buscar';

  @override
  String get askGlimpse => 'Perguntar ao Glimpse';

  @override
  String get settings => 'Configurações';

  @override
  String get accountAndPlan => 'Conta e plano';

  @override
  String get personalization => 'Personalização';

  @override
  String get lookAndFeel => 'Aparência';

  @override
  String get themeAndAccent => 'Tema e cor de destaque';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Padrão do sistema';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languageJapanese => 'Japonês';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languageFrench => 'Francês';

  @override
  String get languagePortugueseBrazil => 'Português (Brasil)';

  @override
  String get chooseLanguage => 'Escolher idioma';

  @override
  String get musicApp => 'Aplicativo de música';

  @override
  String get chooseWhereSongsOpen => 'Escolha onde abrir as músicas';

  @override
  String get loadingPreference => 'Carregando preferência';

  @override
  String get libraryGestures => 'Gestos da biblioteca';

  @override
  String get notifications => 'Notificações';

  @override
  String get privacyAndData => 'Privacidade e dados';

  @override
  String get privacy => 'Privacidade';

  @override
  String get privacySubtitle => 'O que fica no aparelho e o que é enviado';

  @override
  String get dataAndBackup => 'Dados e backup';

  @override
  String get dataAndBackupSubtitle => 'Proteja e restaure seus itens salvos';

  @override
  String get bin => 'Lixeira';

  @override
  String get binSubtitle => 'Os itens excluídos são mantidos por 30 dias';

  @override
  String get clearAllData => 'Limpar todos os dados';

  @override
  String get clearAllDataSubtitle =>
      'Excluir permanentemente todos os links salvos';

  @override
  String get about => 'Sobre';

  @override
  String get aboutGlimpse => 'Sobre o Glimpse';

  @override
  String get aboutSubtitle => 'Versão, informações legais e ajuda';

  @override
  String get accountActions => 'Ações da conta';

  @override
  String get logOut => 'Sair';

  @override
  String get logOutSubtitle => 'Sair deste dispositivo';

  @override
  String get deleteAccount => 'Excluir conta';

  @override
  String get deleteAccountSubtitle => 'Solicitar exclusão da conta';

  @override
  String get deletingAccount => 'Excluindo sua conta…';

  @override
  String get cancel => 'Cancelar';

  @override
  String get deleteAll => 'Excluir tudo';

  @override
  String get clearAllDataQuestion => 'Limpar todos os dados?';

  @override
  String get clearAllDataWarning =>
      'Isso excluirá permanentemente todas as URLs salvas. Não é possível desfazer.';

  @override
  String get allDataCleared => 'Todos os dados foram limpos';

  @override
  String get logOutQuestion => 'Sair?';

  @override
  String get logOutWarning =>
      'Você precisará entrar novamente para acessar sua conta do Glimpse.';

  @override
  String get deleteAccountQuestion => 'Excluir a conta?';

  @override
  String get manageSubscription => 'Gerenciar assinatura';

  @override
  String get accountDeleted => 'Conta excluída';

  @override
  String get manageYourPlan => 'Gerencie seu plano';

  @override
  String get checkingSaveAllowance => 'Verificando salvamentos disponíveis';

  @override
  String aiSavesLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count salvamentos com IA neste mês',
      one: 'Resta 1 salvamento com IA neste mês',
    );
    return '$_temp0';
  }

  @override
  String get captureTitle => 'Salvando o que chamou sua atenção.';

  @override
  String get captureBody => 'Avisaremos quando estiver pronto.';

  @override
  String savedToCollection(String collectionName) {
    return 'Salvo em $collectionName';
  }

  @override
  String get makingSense =>
      'O Glimpse está entendendo o que chamou sua atenção.';

  @override
  String get savedWithoutAi => 'Salvo sem análise de IA';

  @override
  String get aiLimitBody =>
      'Seus salvamentos gratuitos com IA deste mês acabaram. Toque para fazer upgrade.';

  @override
  String get alreadyInYourWorld => 'Já está entre os seus itens.';

  @override
  String get enrichmentFailed => 'Não foi possível concluir a análise';

  @override
  String get tapToRetry => 'Toque para tentar novamente.';

  @override
  String get notification => 'Notificação';

  @override
  String get today => 'Hoje';

  @override
  String get yesterday => 'Ontem';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get close => 'Fechar';

  @override
  String get addUrl => 'Adicionar URL';

  @override
  String get newCollection => 'Nova coleção';

  @override
  String get captured => 'Salvo';

  @override
  String get undo => 'Desfazer';

  @override
  String get alreadyInGlimpse => 'Já está no Glimpse';

  @override
  String get open => 'Abrir';

  @override
  String get tryAgain => 'Tentar novamente';

  @override
  String get exitSelection => 'Sair da seleção';

  @override
  String get sources => 'Fontes';

  @override
  String get viewAllSources => 'Ver todas as fontes';

  @override
  String get pasteLink => 'Cole um link…';

  @override
  String get dismissClipboardSuggestion =>
      'Dispensar sugestão da área de transferência';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get editCollection => 'Editar coleção';

  @override
  String get moveContents => 'Mover conteúdo';

  @override
  String get deleteSelectedCollections => 'Excluir coleções selecionadas';

  @override
  String get delete => 'Excluir';

  @override
  String get collectionOptions => 'Opções da coleção';

  @override
  String get grid => 'Grade';

  @override
  String get list => 'Lista';

  @override
  String get manual => 'Manual';

  @override
  String get newest => 'Mais recentes';

  @override
  String get alphabetical => 'A–Z';

  @override
  String get reorder => 'Reordenar';

  @override
  String get upgradeToPro => 'Fazer upgrade para Pro';

  @override
  String get reset => 'Redefinir';

  @override
  String get applyFilters => 'Aplicar filtros';

  @override
  String get newChat => 'Nova conversa';

  @override
  String get capture => 'Salvar';

  @override
  String get capturing => 'Salvando…';

  @override
  String get pasteFromClipboard => 'Colar da área de transferência';

  @override
  String get addToCollection => 'Adicionar a uma coleção';

  @override
  String get more => 'Mais';

  @override
  String get notes => 'Notas';

  @override
  String get categoryTechnology => 'Tecnologia';

  @override
  String get categoryBusiness => 'Negócios';

  @override
  String get categoryFinance => 'Finanças';

  @override
  String get categoryScience => 'Ciência';

  @override
  String get categoryHealth => 'Saúde';

  @override
  String get categoryEducation => 'Educação';

  @override
  String get categoryNews => 'Notícias';

  @override
  String get categoryDesign => 'Design';

  @override
  String get categoryHistory => 'História';

  @override
  String get categoryPhilosophy => 'Filosofia';

  @override
  String get categoryNature => 'Natureza';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryTravel => 'Viagens';

  @override
  String get categoryEntertainment => 'Entretenimento';

  @override
  String get categoryLifestyle => 'Estilo de vida';

  @override
  String get categorySports => 'Esportes';

  @override
  String get categoryOther => 'Outros';

  @override
  String minutesAgo(Object count) {
    return 'há $count min';
  }

  @override
  String hoursAgo(Object count) {
    return 'há $count h';
  }

  @override
  String daysAgo(Object count) {
    return 'há $count d';
  }

  @override
  String get smartNotificationsDescription =>
      'Notificações inteligentes sobre seus links salvos';

  @override
  String get done => 'Concluído';

  @override
  String get later => 'Mais tarde';

  @override
  String get notificationFallbackTitle => 'Notificação';

  @override
  String newNotificationCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novas notificações',
      one: '1 nova notificação',
    );
    return '$_temp0';
  }

  @override
  String get captureSomethingWorthReturning =>
      'Salve algo que valha a pena revisitar';

  @override
  String get captureContextAfter =>
      'O Glimpse encontrará o contexto depois que você salvar.';

  @override
  String get link => 'Link';

  @override
  String get detectedFromClipboard => 'Detectado na área de transferência';

  @override
  String get collection => 'Coleção';

  @override
  String get noCollection => 'Sem coleção';

  @override
  String get savingTo => 'Salvando em';

  @override
  String get chooseCollection => 'Escolher coleção';

  @override
  String get chooseACollection => 'Escolha uma coleção';

  @override
  String get processingLink => 'Processando link…';

  @override
  String get couldNotLoadCollections =>
      'Não foi possível carregar as coleções.';

  @override
  String linkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
      zero: 'Nenhum link',
    );
    return '$_temp0';
  }

  @override
  String get noteOptional => 'Nota (opcional)';

  @override
  String get addNoteOptional => 'Adicione uma nota (opcional)';

  @override
  String get pleaseEnterUrl => 'Insira uma URL';

  @override
  String get couldNotCaptureLink => 'Não foi possível salvar este link';

  @override
  String get findingSavedVersion => 'Procurando a versão salva…';

  @override
  String get openSavedItem => 'Abrir item salvo';

  @override
  String collectionSelection(String collectionName) {
    return 'Coleção, $collectionName';
  }

  @override
  String get capturedInGlimpse => 'Salvo no Glimpse';

  @override
  String get firstCapturedReady =>
      'Seu primeiro item salvo está pronto abaixo.';

  @override
  String get shareAnyApp =>
      'Compartilhe de qualquer app — o Glimpse organiza para você.';

  @override
  String get howGlimpseWorks => 'Como o Glimpse funciona';

  @override
  String get capturingWhatCaughtYourEye => 'Salvando o que chamou sua atenção';

  @override
  String get findingContext => 'Encontrando o contexto';

  @override
  String get invalidLink => 'Link inválido';

  @override
  String get rediscover => 'Redescobrir';

  @override
  String get rediscoverSubtitle => 'Vale a pena retomar';

  @override
  String get rediscoverTip =>
      'Todos os dias, o Redescobrir escolhe algumas memórias que valem a pena retomar.';

  @override
  String get dismissRediscoverTip => 'Fechar dica do Redescobrir';

  @override
  String get pinned => 'Fixados';

  @override
  String get recentSaves => 'Salvos recentemente';

  @override
  String get justNow => 'agora mesmo';

  @override
  String weeksAgo(Object count) {
    return 'há $count sem';
  }

  @override
  String monthsAgo(Object count) {
    return 'há $count mês';
  }

  @override
  String yearsAgo(Object count) {
    return 'há $count ano(s)';
  }

  @override
  String get retrying => 'Tentando novamente';

  @override
  String get processing => 'Processando';

  @override
  String get needsAttention => 'Requer atenção';

  @override
  String get read => 'Lido';

  @override
  String get unread => 'Não lido';

  @override
  String get copyLink => 'Copiar link';

  @override
  String get linkCopied => 'Link copiado';

  @override
  String get openOriginal => 'Abrir original';

  @override
  String get share => 'Compartilhar';

  @override
  String get enrichmentComplete => 'Processamento concluído';

  @override
  String get couldNotEnrichSave => 'Não foi possível processar este item';

  @override
  String get allSources => 'Todas as fontes';

  @override
  String get all => 'Tudo';

  @override
  String get apps => 'Apps';

  @override
  String get websites => 'Sites';

  @override
  String get results => 'Resultados';

  @override
  String get topSources => 'Principais fontes';

  @override
  String get searchSources => 'Buscar apps, sites e domínios…';

  @override
  String get filterSources => 'Filtrar fontes';

  @override
  String get couldNotLoadSources => 'Não foi possível carregar as fontes';

  @override
  String noSourcesMatch(String query) {
    return 'Nenhuma fonte corresponde a \"$query\"';
  }

  @override
  String get noSavesFromApps => 'Ainda não há itens salvos de apps';

  @override
  String get noWebsiteSaves => 'Ainda não há itens salvos de sites';

  @override
  String get noSourcesYet => 'Ainda não há fontes';

  @override
  String get noSavesYet => 'Ainda não há itens salvos';

  @override
  String saveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens salvos',
      one: '1 item salvo',
    );
    return '$_temp0';
  }

  @override
  String savesThisWeek(Object count) {
    return '+$count esta semana';
  }

  @override
  String get growing => 'Crescendo';

  @override
  String lastSaved(String time) {
    return 'Último item salvo $time';
  }

  @override
  String get leftSwipe => 'Deslizar para a esquerda';

  @override
  String get rightSwipe => 'Deslizar para a direita';

  @override
  String get chooseSwipeAction => 'Escolha a ação ao deslizar';

  @override
  String get markReadUnread => 'Marcar como lido/não lido';

  @override
  String get pin => 'Fixar';

  @override
  String get none => 'Nenhuma';

  @override
  String get smartNotifications => 'Notificações inteligentes';

  @override
  String get behaviorBasedAlerts => 'Alertas conforme sua atividade';

  @override
  String get whereDoYouListen => 'Onde você ouve música?';

  @override
  String get chooseMusicProvider =>
      'Escolha o app que o Glimpse deve usar para as músicas que você encontrar.';

  @override
  String get brightness => 'Brilho';

  @override
  String get brightnessDescription =>
      'Escolha quando usar cores claras ou escuras.';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Escuro';

  @override
  String get amoledBlack => 'Preto AMOLED';

  @override
  String get amoledUnavailable =>
      'Disponível quando o tema claro não está em uso.';

  @override
  String get amoledDescription =>
      'Fundos totalmente pretos em OLED para economizar energia.';

  @override
  String get accentColor => 'Cor de destaque';

  @override
  String get dynamicAccentDescription =>
      'Dinâmico usa a paleta do seu papel de parede em dispositivos compatíveis.';

  @override
  String selectedAccent(String accent) {
    return 'Selecionado: $accent';
  }

  @override
  String get themePreview => 'Prévia do tema';

  @override
  String get themePreviewDescription =>
      'O destaque e as superfícies mudam conforme suas escolhas abaixo.';

  @override
  String get accentDynamic => 'Dinâmico';

  @override
  String get accentPurple => 'Roxo';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentTeal => 'Verde-azulado';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentLime => 'Limão';

  @override
  String get accentYellow => 'Amarelo';

  @override
  String get accentOrange => 'Laranja';

  @override
  String get accentRed => 'Vermelho';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentSakura => 'Sakura';

  @override
  String get accentIndigo => 'Índigo';

  @override
  String get accentSlate => 'Ardósia';

  @override
  String get accentMonochrome => 'Monocromático';

  @override
  String get deleted => 'Excluído';

  @override
  String get noNotificationsYet => 'Ainda não há notificações';

  @override
  String get notificationsEmptyDescription =>
      'Alertas de viagem, novas descobertas, lembretes de leitura e resumos semanais aparecerão aqui.';

  @override
  String get ready => 'pronto';

  @override
  String waitingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendentes',
      one: '1 pendente',
    );
    return '$_temp0';
  }

  @override
  String get backInView => 'De volta à vista';

  @override
  String get couldNotLoadSource => 'Não foi possível carregar esta fonte';

  @override
  String get noSavesFromSource => 'Não há itens salvos desta fonte';

  @override
  String get saves => 'Salvos';

  @override
  String get thisWeek => 'Nesta semana';

  @override
  String get opened => 'Abertos';

  @override
  String get topThemes => 'Principais temas';

  @override
  String get allItems => 'Todos os itens';

  @override
  String get oldest => 'Mais antigos';

  @override
  String get recentlyOpened => 'Abertos recentemente';

  @override
  String get showItems => 'Mostrar itens';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get noItemsFromSource => 'Não há itens desta fonte';

  @override
  String get noUnreadItems => 'Não há itens não lidos';

  @override
  String get noReadItems => 'Não há itens lidos';

  @override
  String get lastSavedLabel => 'Último item salvo';

  @override
  String get markAllRead => 'Marcar tudo como lido';

  @override
  String get back => 'Voltar';

  @override
  String get subscription => 'Assinatura';

  @override
  String get couldNotLoadSubscription =>
      'Não foi possível carregar as informações da assinatura';

  @override
  String get coreLibrary => 'Biblioteca principal';

  @override
  String get unlimitedLinkSaving => 'Links salvos sem limite';

  @override
  String get unlimitedLinkSavingDescription => 'Salve quantos links quiser';

  @override
  String get collectionsOrganization => 'Coleções e organização';

  @override
  String get collectionsOrganizationDescription =>
      'Agrupe e organize seus favoritos do seu jeito';

  @override
  String get smartNotificationsLongDescription =>
      'Alertas baseados no comportamento e lembretes de leitura';

  @override
  String get aiAssistant => 'Assistente de IA';

  @override
  String get aiTaggingCategorization => 'Etiquetagem e categorização por IA';

  @override
  String get freeSavesProUnlimited => 'Grátis: 30 itens/mês · Pro: ilimitado';

  @override
  String get keywordSearch => 'Busca por palavras-chave';

  @override
  String get freeSearchesProUnlimited =>
      'Grátis: 30 buscas/mês · Pro: ilimitado';

  @override
  String get askYourBookmarks => 'Pergunte aos seus favoritos';

  @override
  String get freeQuestionsProUnlimited =>
      'Grátis: 30 perguntas/mês · Pro: ilimitado';

  @override
  String get proInsights => 'Insights Pro';

  @override
  String get semanticSearch => 'Busca semântica';

  @override
  String get semanticSearchDescription =>
      'Encontre links pelo significado, não só pelas palavras';

  @override
  String get weeklyRecap => 'Resumo semanal';

  @override
  String get weeklyRecapDescription =>
      'Resumo dos seus links salvos gerado por IA';

  @override
  String get multiLinkSynthesis => 'Síntese de vários links';

  @override
  String get multiLinkSynthesisDescription =>
      'Analise em conjunto qualquer grupo de favoritos';

  @override
  String get active => 'Ativo';

  @override
  String get free => 'Grátis';

  @override
  String get proPlanDescription =>
      'Todos os recursos de IA, sem limites, em toda a sua biblioteca.';

  @override
  String get proPlanDevDescription =>
      'Todos os recursos de IA, sem limites, em toda a sua biblioteca. (substituição de desenvolvimento; loja: Grátis)';

  @override
  String get freePlanDescription =>
      'Crie sua biblioteca pessoal de conhecimento com as ferramentas essenciais. Recursos de IA estão incluídos para você experimentar antes de fazer upgrade.';

  @override
  String get upgradeToGlimpsePro => 'Fazer upgrade para Glimpse Pro';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get manageOnGooglePlay => 'Gerenciar no Google Play';

  @override
  String get local => 'Local';

  @override
  String get uploaded => 'Enviado';

  @override
  String get bookmarks => 'Favoritos';

  @override
  String get aiSummaries => 'Resumos por IA';

  @override
  String get accountInformation => 'Informações da conta';

  @override
  String get subscriptionStatus => 'Status da assinatura';

  @override
  String get anonymousProductAnalytics => 'Análises anônimas do produto';

  @override
  String get storageLocation => 'Local de armazenamento';

  @override
  String get pickAFolder => 'Escolher uma pasta';

  @override
  String get chooseBackupFolderDescription =>
      'Toque para escolher onde os backups serão salvos';

  @override
  String get backupFolderInfo =>
      'Este local é usado para salvar seus arquivos de backup. Escolha uma pasta uma vez e o Glimpse continuará gravando novos backups nela.';

  @override
  String get automaticBackup => 'Backup automático';

  @override
  String get off => 'Desativado';

  @override
  String get backupFrequencyDescription =>
      'Frequência para salvar um backup no local escolhido';

  @override
  String get backupSensitiveInfo =>
      'Mantenha cópias dos backups em outros lugares também. Eles podem incluir toda a sua biblioteca; trate-os como dados sensíveis se compartilhar os arquivos.';

  @override
  String get backupAndRestore => 'Backup e restauração';

  @override
  String get createBackup => 'Criar backup';

  @override
  String get restoreBackup => 'Restaurar backup';

  @override
  String lastBackup(Object time) {
    return 'Último backup: $time';
  }

  @override
  String get backupLocalInfo =>
      'Os backups contêm toda a sua biblioteca: links, coleções, etiquetas e metadados. Eles permanecem no seu dispositivo.';

  @override
  String get deletedItemsRetention =>
      'Os itens excluídos ficam guardados por 30 dias e são removidos permanentemente na próxima limpeza do Glimpse.';

  @override
  String daysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count dias',
      one: 'Resta 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get expiresToday => 'Expira hoje';

  @override
  String get restore => 'Restaurar';

  @override
  String get deletePermanently => 'Excluir permanentemente';

  @override
  String get restoreAll => 'Restaurar tudo';

  @override
  String get emptyBin => 'Esvaziar lixeira';

  @override
  String get binActions => 'Ações da lixeira';

  @override
  String get itemActions => 'Ações do item';

  @override
  String get binIsEmpty => 'A lixeira está vazia';

  @override
  String get binEmptyDescription =>
      'Os itens excluídos aparecerão aqui por 30 dias.';

  @override
  String get deleteAccountProWarning =>
      'Isso remove os metadados da sua conta do Glimpse, mas não cancela a cobrança da loja. O Pro não pode ser transferido para outra conta do Glimpse; gerencie sua assinatura antes de excluir. Sua biblioteca no dispositivo não é enviada ao Supabase.';

  @override
  String get deleteAccountFreeWarning =>
      'Isso remove os metadados da sua conta do Glimpse. Sua biblioteca no dispositivo não é enviada ao Supabase.';

  @override
  String get details => 'Detalhes';

  @override
  String openInSource(Object source) {
    return 'Abrir no $source';
  }

  @override
  String get summary => 'Resumo';

  @override
  String get addNote => 'Adicionar nota';

  @override
  String get keyTakeaways => 'Principais pontos';

  @override
  String get fullBreakdown => 'Análise completa';

  @override
  String get transcriptAndCaption => 'Transcrição e legenda';

  @override
  String get caption => 'Legenda';

  @override
  String get transcript => 'Transcrição';

  @override
  String get onScreenText => 'Texto na tela';

  @override
  String get peopleMentioned => 'Pessoas mencionadas';

  @override
  String peopleMentionedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas mencionadas',
      one: '1 pessoa mencionada',
    );
    return '$_temp0';
  }

  @override
  String get alsoMentioned => 'Também mencionado';

  @override
  String get quotes => 'Citações';

  @override
  String get tags => 'Etiquetas';

  @override
  String get informationMayBeInaccurate =>
      'As informações podem estar imprecisas';

  @override
  String get originalContentAttribution =>
      'O conteúdo original pertence ao seu criador.';

  @override
  String everyHours(Object count) {
    return 'A cada $count horas';
  }

  @override
  String get weekly => 'Semanal';

  @override
  String get addTag => 'Adicionar etiqueta';

  @override
  String get changeCategory => 'Alterar categoria';

  @override
  String get worthWatching => 'Vale assistir';

  @override
  String get worthReading => 'Vale ler';

  @override
  String get gamesMentioned => 'Jogos mencionados';

  @override
  String get musicMentioned => 'Músicas mencionadas';

  @override
  String get toolsMentioned => 'Ferramentas mencionadas';

  @override
  String get worthALook => 'Vale conferir';

  @override
  String get appsToTry => 'Apps para experimentar';

  @override
  String get placesToVisit => 'Lugares para visitar';

  @override
  String get websitesMentioned => 'Sites mencionados';

  @override
  String get claimsToRemember => 'Afirmações para lembrar';

  @override
  String get termsMentioned => 'Termos mencionados';

  @override
  String get notableDetails => 'Detalhes importantes';

  @override
  String get library => 'Biblioteca';

  @override
  String get libraryDescription =>
      'Livros, filmes e lugares encontrados nos seus itens salvos';

  @override
  String get buildsQuietly => 'Cresce aos poucos enquanto você salva';

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String addedTime(Object time) {
    return 'Adicionado · $time';
  }

  @override
  String get rediscoverIntentTitle => 'Algumas lembranças que valem a pena';

  @override
  String chosenFromUnopened(Object count) {
    return 'Escolhidas entre $count itens não abertos e o que importa agora.';
  }

  @override
  String get chosenFromSaved =>
      'Escolhidas entre o que você salvou, abriu e deixou para depois.';

  @override
  String get todayStableSet =>
      'Uma seleção estável para hoje, sem feed infinito.';

  @override
  String get recaps => 'Resumos';

  @override
  String get recapsDescription =>
      'Padrões semanais e mensais dos seus próprios itens salvos.';

  @override
  String get dailyRecap => 'Resumo diário';

  @override
  String get monthlyRecap => 'Resumo mensal';

  @override
  String recapSummary(num count, Object waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens salvos',
      one: '1 item salvo',
    );
    return '$_temp0 · $waiting não abertos';
  }

  @override
  String get yourWeekInSaves => 'Sua semana em itens salvos';

  @override
  String get yourMonthInMemories => 'Seu mês em lembranças';

  @override
  String topicKeptShowingUp(Object topic) {
    return '$topic apareceu várias vezes';
  }

  @override
  String get queued => 'Na fila';

  @override
  String get forgottenGem => 'Achado esquecido';

  @override
  String get fromYourPast => 'Do seu passado';

  @override
  String get rediscoverOptions => 'Opções de redescoberta';

  @override
  String get notNow => 'Agora não';

  @override
  String get hideFor7Days => 'Ocultar por 7 dias';

  @override
  String get lessLikeThis => 'Menos conteúdo assim';

  @override
  String get reduceSimilarTopics => 'Reduzir assuntos parecidos';

  @override
  String get nothingStrongToday => 'Nada relevante para hoje';

  @override
  String get rediscoverQuiet =>
      'Redescobrir ficará em silêncio até que um item realmente mereça voltar.';

  @override
  String get searchYourLibrary => 'Pesquise na sua biblioteca…';

  @override
  String get findAnythingSaved => 'Encontre tudo o que você salvou';

  @override
  String get searchEmptyDescription =>
      'Pesquise em títulos, tags, notas e resumos e depois refine os resultados.';

  @override
  String get filters => 'Filtros';

  @override
  String get filtersActive => 'Filtros ativos';

  @override
  String get time => 'Período';

  @override
  String get allTime => 'Todo o período';

  @override
  String get thisMonth => 'Este mês';

  @override
  String get status => 'Status';

  @override
  String get hasNotes => 'Com notas';

  @override
  String get noNotes => 'Sem notas';

  @override
  String get inCollection => 'Em uma coleção';

  @override
  String get notInCollection => 'Fora de uma coleção';

  @override
  String get specificCollection => 'Coleção específica';

  @override
  String get sort => 'Ordenar';

  @override
  String get relevance => 'Relevância';

  @override
  String get newestSaved => 'Salvos mais recentes';

  @override
  String get oldestSaved => 'Salvos mais antigos';

  @override
  String get learningInterests => 'Aprendendo o que prende sua atenção';

  @override
  String get readingInterests => 'Analisando seus interesses…';

  @override
  String get topSignal => 'Principal interesse';

  @override
  String get growingInterests => 'Interesses em crescimento';

  @override
  String get quieterInterests => 'Outros interesses';

  @override
  String interestStats(num patterns, num saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns padrões',
      one: '1 padrão',
    );
    String _temp1 = intl.Intl.pluralLogic(
      saves,
      locale: localeName,
      other: '$saves itens salvos',
      one: '1 item salvo',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String interestGroupedStats(Object grouped, num patterns, Object saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns padrões',
      one: '1 padrão',
    );
    return '$_temp0 · $grouped de $saves itens agrupados';
  }

  @override
  String noPatternsScanned(Object saves) {
    return 'Nenhum padrão ainda · $saves itens analisados';
  }

  @override
  String get rebuildMap => 'Reconstruir mapa';

  @override
  String get couldNotBuildClusters => 'Não foi possível criar os grupos';

  @override
  String get interestMapEmpty => 'Seu mapa de interesses está vazio';

  @override
  String get interestMapEmptyDescription =>
      'Salve pelo menos 3 links e o Glimpse conectará os temas recorrentes.';

  @override
  String lastAddedTime(Object time) {
    return 'Última adição: $time';
  }

  @override
  String get hiddenFor7Days => 'Oculto por 7 dias';

  @override
  String get seeLessLikeThis => 'Você verá menos conteúdo assim';

  @override
  String get searchingLibrary => 'Pesquisando na sua biblioteca…';

  @override
  String get semanticMatch => 'Correspondência semântica';

  @override
  String get noMatchesForFilter => 'Nenhum resultado para este filtro';

  @override
  String get broadenSearch => 'Tente outro período ou amplie a busca.';

  @override
  String get monthlyLimitReached => 'Limite mensal atingido';

  @override
  String get searchFailed => 'A busca falhou';

  @override
  String get monthlySearchLimitDescription =>
      'Você atingiu seu limite mensal de buscas. Faça upgrade para o Glimpse Pro e pesquise sem limites.';

  @override
  String get openingInterest => 'Abrindo interesse…';

  @override
  String get couldNotOpenInterest => 'Não foi possível abrir este interesse.';

  @override
  String get interestNotFound => 'Interesse não encontrado';

  @override
  String interestSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens salvos neste interesse.',
      one: '1 item salvo neste interesse.',
    );
    return '$_temp0';
  }

  @override
  String interestTopicsSummary(Object count, Object topics) {
    return '$count itens salvos em $topics assuntos';
  }

  @override
  String get reorderCollections => 'Reordenar coleções';

  @override
  String get dragToSetManualOrder => 'Arraste para definir a ordem manual';

  @override
  String movedToCollection(Object name) {
    return 'Movido para $name';
  }

  @override
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links movidos',
      one: '1 link movido',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sourceCount,
      locale: localeName,
      other: 'as coleções de origem foram excluídas',
      one: 'a coleção de origem foi excluída',
    );
    return '$_temp0 para $name e $_temp1';
  }

  @override
  String deleteCollectionNamed(Object name) {
    return 'Excluir “$name”?';
  }

  @override
  String deleteCollectionsCount(Object count) {
    return 'Excluir $count coleções?';
  }

  @override
  String get deleteCollectionDescription =>
      'Os links salvos continuarão na sua biblioteca. Apenas a coleção será excluída.';

  @override
  String get deleteCollectionsDescription =>
      'Os links salvos continuarão na sua biblioteca. Apenas as coleções serão excluídas.';

  @override
  String collectionsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coleções excluídas',
      one: 'Coleção excluída',
    );
    return '$_temp0';
  }

  @override
  String get createFirstCollection => 'Crie sua primeira coleção';

  @override
  String get collectionEmptyDescription =>
      'Agrupe links em espaços tranquilos e organizados.';

  @override
  String get libraryBooks => 'Livros';

  @override
  String get libraryMoviesShows => 'Filmes e séries';

  @override
  String get libraryPlaces => 'Lugares';

  @override
  String get libraryBook => 'Livro';

  @override
  String get libraryMovie => 'Filme';

  @override
  String get libraryPlace => 'Lugar';

  @override
  String get libraryReadingList => 'Lista de leitura';

  @override
  String get libraryWatchlist => 'Lista para assistir';

  @override
  String get libraryNotInReadingList => 'Fora da lista de leitura';

  @override
  String get libraryNotInWatchlist => 'Fora da lista para assistir';

  @override
  String get libraryNotListed => 'Não listado';

  @override
  String get libraryPlanning => 'Planejado';

  @override
  String get libraryReading => 'Lendo';

  @override
  String get libraryWatching => 'Assistindo';

  @override
  String get libraryInProgress => 'Em andamento';

  @override
  String get libraryDropped => 'Abandonado';

  @override
  String get libraryRead => 'Lido';

  @override
  String get libraryWatched => 'Assistido';

  @override
  String get libraryVisited => 'Visitado';

  @override
  String libraryStatusSemantics(Object status) {
    return 'Status: $status';
  }

  @override
  String libraryReadingPageStatus(Object page) {
    return 'Lendo · pág. $page';
  }

  @override
  String get libraryGenreFantasy => 'Fantasia';

  @override
  String get libraryGenreScienceFiction => 'Ficção científica';

  @override
  String get libraryGenreMysteryThriller => 'Mistério e suspense';

  @override
  String get libraryGenreRomance => 'Romance';

  @override
  String get libraryGenreHorror => 'Terror';

  @override
  String get libraryGenreBiographyMemoir => 'Biografia e memórias';

  @override
  String get libraryGenreHistory => 'História';

  @override
  String get libraryGenrePhilosophy => 'Filosofia';

  @override
  String get libraryGenrePsychology => 'Psicologia';

  @override
  String get libraryGenreBusiness => 'Negócios';

  @override
  String get libraryGenreFinanceInvesting => 'Finanças e investimentos';

  @override
  String get libraryGenreTechnology => 'Tecnologia';

  @override
  String get libraryGenreScience => 'Ciência';

  @override
  String get libraryGenreSelfDevelopment => 'Desenvolvimento pessoal';

  @override
  String get libraryGenreHealthWellness => 'Saúde e bem-estar';

  @override
  String get libraryGenrePoliticsSociety => 'Política e sociedade';

  @override
  String get libraryGenreArtDesign => 'Arte e design';

  @override
  String get libraryGenreTravel => 'Viagem';

  @override
  String get libraryGenreComicsGraphicNovels => 'Quadrinhos e graphic novels';

  @override
  String get libraryGenreFiction => 'Ficção';

  @override
  String get libraryGenreAction => 'Ação';

  @override
  String get libraryGenreAdventure => 'Aventura';

  @override
  String get libraryGenreAnimation => 'Animação';

  @override
  String get libraryGenreComedy => 'Comédia';

  @override
  String get libraryGenreCrime => 'Crime';

  @override
  String get libraryGenreDocumentary => 'Documentário';

  @override
  String get libraryGenreDrama => 'Drama';

  @override
  String get libraryGenreFamily => 'Família';

  @override
  String get libraryGenreMystery => 'Mistério';

  @override
  String get libraryGenreThriller => 'Suspense';

  @override
  String get libraryGenreWar => 'Guerra';

  @override
  String get libraryGenreWestern => 'Faroeste';

  @override
  String get libraryGenreMusic => 'Música';

  @override
  String get libraryGenreOther => 'Outros';

  @override
  String get librarySubtypeTvShow => 'Série de TV';

  @override
  String get librarySubtypeSeries => 'Série';

  @override
  String get couldNotOpenLibrary => 'Não foi possível abrir a Biblioteca';

  @override
  String searchLibraryItems(Object kind) {
    return 'Pesquisar em $kind';
  }

  @override
  String get clearSearch => 'Limpar busca';

  @override
  String get clearAll => 'Limpar tudo';

  @override
  String get recentlyDiscovered => 'Descobertos recentemente';

  @override
  String get titleAZ => 'Título A–Z';

  @override
  String get yearNewest => 'Ano mais recente';

  @override
  String libraryOptions(Object kind) {
    return 'Opções de $kind';
  }

  @override
  String filterLibraryItems(Object kind) {
    return 'Filtrar $kind';
  }

  @override
  String get readingStatus => 'Status de leitura';

  @override
  String get watchStatus => 'Status de visualização';

  @override
  String get anyStatus => 'Qualquer status';

  @override
  String get genre => 'Gênero';

  @override
  String get allGenres => 'Todos os gêneros';

  @override
  String get nothingMatchesFilters => 'Nada corresponde a estes filtros.';

  @override
  String get nothingRecognizedHere => 'Nada reconhecido aqui ainda.';

  @override
  String get couldNotUpdateLibraryItem =>
      'Não foi possível atualizar este item da Biblioteca.';

  @override
  String get foundInYourSaves => 'Encontrado nos seus itens salvos';

  @override
  String get recognizedOrganizedByType => 'Reconhecido e organizado por tipo';

  @override
  String libraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livros',
      one: '1 livro',
    );
    return '$_temp0';
  }

  @override
  String libraryMovieCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmes',
      one: '1 filme',
    );
    return '$_temp0';
  }

  @override
  String libraryPlaceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lugares',
      one: '1 lugar',
    );
    return '$_temp0';
  }

  @override
  String libraryStopCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paradas',
      one: '1 parada',
    );
    return '$_temp0';
  }

  @override
  String get nothingRecognizedYet => 'Nada reconhecido ainda';

  @override
  String get recognizedTitlesGatherHere =>
      'Os títulos reconhecidos aparecerão aqui';

  @override
  String recognizedCount(Object count) {
    return '$count reconhecidos';
  }

  @override
  String get savedPlacesAppearOnMap =>
      'Os lugares salvos aparecerão em um mapa';

  @override
  String get addingDetails => 'Adicionando detalhes';

  @override
  String get extraDetailsUnavailable =>
      'Os detalhes extras estão temporariamente indisponíveis';

  @override
  String itemsCouldNotRefresh(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível atualizar $count itens',
      one: 'Não foi possível atualizar 1 item',
    );
    return '$_temp0';
  }

  @override
  String progressOf(Object completed, Object total) {
    return '$completed de $total';
  }

  @override
  String get savedDetailsRemainAvailable =>
      'Os detalhes salvos continuam disponíveis';

  @override
  String waitingToRetry(Object count) {
    return '$count aguardando nova tentativa';
  }

  @override
  String get libraryBuildsAsYouSave => 'Ela cresce enquanto você salva';

  @override
  String get libraryEmptyDescription =>
      'Salve recomendações de livros, filmes e lugares. O Glimpse organizará aqui o que encontrar neles.';

  @override
  String get libraryUnavailable => 'A Biblioteca está indisponível no momento';

  @override
  String get yourPlaces => 'Seus lugares';

  @override
  String placesAreasSummary(num areas, num places) {
    String _temp0 = intl.Intl.pluralLogic(
      places,
      locale: localeName,
      other: '$places lugares',
      one: '1 lugar',
    );
    String _temp1 = intl.Intl.pluralLogic(
      areas,
      locale: localeName,
      other: '$areas áreas',
      one: '1 área',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get planThisArea => 'Planejar esta área';

  @override
  String get planAnItinerary => 'Planejar um roteiro';

  @override
  String get searchSavedPlaces => 'Pesquisar lugares salvos';

  @override
  String get yourPlans => 'Seus planos';

  @override
  String get plan => 'Planejar';

  @override
  String get locationUnavailable => 'Localização indisponível';

  @override
  String openNamedItem(Object name) {
    return 'Abrir $name';
  }

  @override
  String get wantToVisit => 'Quero visitar';

  @override
  String get savedPlace => 'Lugar salvo';

  @override
  String get planAVisit => 'Planejar uma visita';

  @override
  String get maps => 'Mapas';

  @override
  String get noSavedPlacesMatch =>
      'Nenhum lugar salvo corresponde a esta busca.';

  @override
  String get noPlacesDiscovered => 'Nenhum lugar descoberto ainda';

  @override
  String get placesMentionedGatherHere =>
      'Os lugares mencionados nos seus itens salvos aparecerão aqui.';

  @override
  String get fitAllPlaces => 'Mostrar todos os lugares';

  @override
  String get noMappedPlaces => 'Nenhum lugar no mapa ainda';

  @override
  String get mapUnavailablePlacesListed =>
      'Mapa indisponível — seus lugares continuam listados abaixo';

  @override
  String get libraryItemUnavailable =>
      'Este item da Biblioteca está indisponível.';

  @override
  String get couldNotUpdateBookmark =>
      'Não foi possível atualizar seu marcador.';

  @override
  String hiddenFromLibrary(Object name) {
    return '$name foi ocultado da Biblioteca';
  }

  @override
  String get libraryItemOptions => 'Opções do item da Biblioteca';

  @override
  String get hideFromLibrary => 'Ocultar da Biblioteca';

  @override
  String get addToReadingList => 'Adicionar à sua lista de leitura';

  @override
  String get addToWatchlist => 'Adicionar à sua lista para assistir';

  @override
  String get removeFromReadingList => 'Remover da lista de leitura';

  @override
  String get removeFromWatchlist => 'Remover da lista para assistir';

  @override
  String get whyItMattered => 'Por que foi importante';

  @override
  String get plot => 'Sinopse';

  @override
  String get yourBookmark => 'Seu marcador';

  @override
  String get savePageYouAreOn => 'Salve a página em que você está';

  @override
  String savePlaceAboutPages(Object count) {
    return 'Salve seu progresso · cerca de $count páginas';
  }

  @override
  String pageNumber(Object page) {
    return 'Página $page';
  }

  @override
  String pageAboutPages(Object count, Object page) {
    return 'Página $page · cerca de $count páginas';
  }

  @override
  String get setCurrentPage => 'Definir página atual';

  @override
  String get updatePage => 'Atualizar página';

  @override
  String get updateYourBookmark => 'Atualizar seu marcador';

  @override
  String aboutPages(Object count) {
    return 'cerca de $count páginas';
  }

  @override
  String get currentPage => 'Página atual';

  @override
  String get enterPageNumber => 'Digite um número de página';

  @override
  String get saveBookmark => 'Salvar marcador';

  @override
  String get pageGreaterThanZero => 'Digite um número de página maior que zero';

  @override
  String libraryItemSemantics(Object kind, Object title) {
    return '$kind: $title';
  }

  @override
  String libraryItemOpenHint(Object list) {
    return 'Toque duas vezes para abrir. Mantenha pressionado para alterar o status de $list.';
  }

  @override
  String get collectionEditSubtitle => 'Ajuste este espaço de itens salvos.';

  @override
  String get collectionCreateSubtitle =>
      'Crie um espaço focado para suas ideias salvas.';

  @override
  String get nameLabel => 'Nome';

  @override
  String get descriptionLabel => 'Descrição';

  @override
  String get collectionNameHint => 'Viagens e descobertas';

  @override
  String get collectionDescriptionHint => 'Nota opcional para este espaço';

  @override
  String get save => 'Salvar';

  @override
  String get create => 'Criar';

  @override
  String get nameCollectionError => 'Dê um nome à coleção';

  @override
  String get duplicateCollectionError => 'Já existe uma coleção com este nome';

  @override
  String get deleteCollection => 'Excluir coleção';

  @override
  String get addLink => 'Adicionar link';

  @override
  String get noLinksInCollection => 'Esta coleção ainda não tem links.';

  @override
  String get notificationTravelPlaces => 'Viagens e lugares';

  @override
  String get notificationNewDiscovery => 'Nova descoberta';

  @override
  String get notificationReadingReminder => 'Lembrete de leitura';

  @override
  String get notificationActivity => 'Atividade';

  @override
  String get notificationWorthRevisiting => 'Vale revisitar';

  @override
  String get notificationRevisitReminder => 'Lembrete para revisitar';

  @override
  String get notificationWeeklyDigest => 'Resumo semanal';

  @override
  String get enrichmentNeedsAttention => 'A análise precisa de atenção';

  @override
  String get aiDetailsAvailable => 'Detalhes de IA disponíveis';

  @override
  String get enrich => 'Analisar';

  @override
  String get enriching => 'Analisando';

  @override
  String get messageGlimpse => 'Mensagem para o Glimpse...';

  @override
  String get askAboutThisSave => 'Pergunte sobre este item salvo...';

  @override
  String get sending => 'Enviando...';

  @override
  String get send => 'Enviar';

  @override
  String get askGreetingEarlyMorning => 'Acordou cedo?';

  @override
  String get askGreetingMorning => 'Bom dia.';

  @override
  String get askGreetingAfternoon => 'O que vamos explorar?';

  @override
  String get askGreetingEvening => 'Boa noite.';

  @override
  String get askGreetingNight => 'Ainda está curioso hoje?';

  @override
  String get askGreetingLateNight => 'Acordado até tarde de novo?';

  @override
  String get saveYourFirstLink => 'Salve seu primeiro link';

  @override
  String get moreSelectionActions => 'Mais ações de seleção';

  @override
  String get moveToCollection => 'Mover para uma coleção';

  @override
  String get markRead => 'Marcar como lido';

  @override
  String get markUnread => 'Marcar como não lido';

  @override
  String get toggleReadStatus => 'Alternar status de leitura';

  @override
  String get unpin => 'Desafixar';

  @override
  String get yourNote => 'Sua nota';

  @override
  String get edit => 'Editar';

  @override
  String get notePrompt => 'O que chamou sua atenção?';

  @override
  String get quickAdd => 'Adição rápida';

  @override
  String get noteSaving => 'Salvando…';

  @override
  String get noteSaved => 'Salvo';

  @override
  String get noteCouldNotSave => 'Não foi possível salvar';

  @override
  String get addYourNote => 'Adicione sua nota';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get showMore => 'Mostrar mais';

  @override
  String showAllCount(Object count) {
    return 'Mostrar tudo ($count)';
  }

  @override
  String get answerCopied => 'Resposta copiada';

  @override
  String get deleteAskNoteQuestion => 'Excluir nota do Ask?';

  @override
  String get deleteAskNoteDescription =>
      'Isso remove a resposta salva deste link. Sua própria nota não será afetada.';

  @override
  String get askNoteDeleted => 'Nota do Ask excluída';

  @override
  String get couldNotDeleteAskNote => 'Não foi possível excluir a nota do Ask';

  @override
  String get askNoteActions => 'Ações da nota do Ask';

  @override
  String get copyAnswer => 'Copiar resposta';

  @override
  String get quickTryThisWeekend => 'Experimentar neste fim de semana';

  @override
  String get quickNeedIngredients => 'Preciso de ingredientes';

  @override
  String get quickShareWithSomeone => 'Compartilhar com alguém';

  @override
  String get quickAlreadyTried => 'Já experimentei';

  @override
  String get quickWatchLater => 'Assistir mais tarde';

  @override
  String get quickAddToWatchlist => 'Adicionar à lista para assistir';

  @override
  String get quickAlreadyWatched => 'Já assisti';

  @override
  String get quickAddToReadingList => 'Adicionar à lista de leitura';

  @override
  String get quickReadLater => 'Ler mais tarde';

  @override
  String get quickResearchThis => 'Pesquisar isto';

  @override
  String get quickAlreadyRead => 'Já li';

  @override
  String get quickTryThisTool => 'Experimentar esta ferramenta';

  @override
  String get quickCompareAlternatives => 'Comparar alternativas';

  @override
  String get quickUseInProject => 'Usar em um projeto';

  @override
  String get quickShareWithTeam => 'Compartilhar com a equipe';

  @override
  String get quickPlanItinerary => 'Planejar roteiro';

  @override
  String get quickCheckBestSeason => 'Verificar a melhor época';

  @override
  String get quickSaveRoute => 'Salvar rota';

  @override
  String get quickPracticeLater => 'Praticar mais tarde';

  @override
  String get quickMakeChecklist => 'Criar checklist';

  @override
  String get quickRevisitNotes => 'Revisitar notas';

  @override
  String get quickRevisitLater => 'Revisitar mais tarde';

  @override
  String get quickWorthTrying => 'Vale a pena experimentar';

  @override
  String get quickAlreadyChecked => 'Já conferi';

  @override
  String get aboutTagline => 'Salve algo que vale a pena guardar';

  @override
  String versionBuild(Object build, Object version) {
    return 'Versão $version (compilação $build)';
  }

  @override
  String get loadingVersion => 'Carregando versão…';

  @override
  String get legal => 'Jurídico';

  @override
  String get termsOfService => 'Termos de Serviço';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get help => 'Ajuda';

  @override
  String get faq => 'Perguntas frequentes';

  @override
  String get sendFeedback => 'Enviar feedback';

  @override
  String get rateOnPlayStore => 'Avaliar na Play Store';

  @override
  String get shareGlimpse => 'Compartilhar o Glimpse';

  @override
  String get feedbackEmailSubject => 'Feedback sobre o Glimpse';

  @override
  String shareGlimpseText(Object url) {
    return 'O Glimpse ajuda você a salvar links aos quais vale a pena voltar. Experimente: $url';
  }

  @override
  String get couldNotOpenLink => 'Não foi possível abrir este link.';

  @override
  String get couldNotShareGlimpse => 'Não foi possível compartilhar o Glimpse.';

  @override
  String get keepsakeQuoteCuriosity =>
      'Guarde o que mantém viva a sua curiosidade.';

  @override
  String get keepsakeQuoteIdea =>
      'Um pequeno vislumbre pode virar uma ideia duradoura.';

  @override
  String get keepsakeQuoteSpark =>
      'Guarde a faísca. Volte quando ela importar.';

  @override
  String get keepsakeQuoteFutureSelf =>
      'Talvez o seu eu do futuro esteja procurando por isto.';

  @override
  String get keepsakeQuoteNoticing => 'Vale notar. Vale guardar.';

  @override
  String get other => 'Outros';

  @override
  String get shareBackup => 'Compartilhar backup';

  @override
  String get shareBackupDescription =>
      'Envie um backup para outro aplicativo ou serviço de nuvem';

  @override
  String backupSavedLinksTo(num count, Object location) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links salvos',
      one: '1 link salvo',
    );
    return '$_temp0 em $location';
  }

  @override
  String backupSavedTo(Object location) {
    return 'Backup salvo em $location';
  }

  @override
  String get errorDetails => 'Detalhes do erro';

  @override
  String get copy => 'Copiar';

  @override
  String get couldNotReadSelectedFile =>
      'Não foi possível ler o arquivo selecionado.';

  @override
  String get folderSelected => 'Pasta selecionada';

  @override
  String get couldNotSaveFolderPermission =>
      'Não foi possível salvar a permissão da pasta. Tente novamente.';

  @override
  String get permanentBackupFolderAndroid =>
      'A pasta permanente de backup está disponível no Android';

  @override
  String get tapToChange => 'Toque para alterar';

  @override
  String get forgetFolder => 'Esquecer pasta';

  @override
  String get autoBackupAndroidOnly =>
      'O backup automático funciona no Android quando uma pasta é definida';

  @override
  String lastAutomaticBackup(Object time) {
    return 'Último backup automático: $time';
  }

  @override
  String lastBackupAttemptFailed(Object time) {
    return 'A última tentativa falhou $time. O Glimpse tentará novamente automaticamente.';
  }

  @override
  String get setStorageBeforeAutoBackup =>
      'Defina um local acima antes de executar backups automáticos.';

  @override
  String get folderBackup => 'Backup da pasta';

  @override
  String lastSavedToFolder(Object time) {
    return 'Último salvamento na pasta: $time';
  }

  @override
  String get noBackupFileInFolder =>
      'Ainda não há backup nesta pasta. Escolha o local e use Criar backup acima.';
}
