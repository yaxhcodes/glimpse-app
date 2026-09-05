// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get musicDetailsUnavailable =>
      'No se pudieron cargar los detalles de algunas canciones.';

  @override
  String get loadingMusicDetails => 'Cargando detalles de las canciones…';

  @override
  String get couldNotSaveMusicProvider =>
      'No se pudo guardar tu app de música. Inténtalo de nuevo.';

  @override
  String get libraryMusicEmptyDescription =>
      'Aquí aparecerán las canciones encontradas en tus enlaces guardados.';

  @override
  String get libraryMusicDescription => 'Canciones de tus enlaces guardados';

  @override
  String get libraryMusic => 'Música';

  @override
  String get appName => 'Glimpse';

  @override
  String get home => 'Inicio';

  @override
  String get collections => 'Colecciones';

  @override
  String get interests => 'Intereses';

  @override
  String get search => 'Buscar';

  @override
  String get askGlimpse => 'Preguntar a Glimpse';

  @override
  String get settings => 'Ajustes';

  @override
  String get accountAndPlan => 'Cuenta y plan';

  @override
  String get personalization => 'Personalización';

  @override
  String get lookAndFeel => 'Apariencia';

  @override
  String get themeAndAccent => 'Tema y color de acento';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languagePortugueseBrazil => 'Portugués (Brasil)';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get chooseLanguage => 'Elegir idioma';

  @override
  String get musicApp => 'Aplicación de música';

  @override
  String get chooseWhereSongsOpen => 'Elige dónde abrir las canciones';

  @override
  String get loadingPreference => 'Cargando preferencia';

  @override
  String get libraryGestures => 'Gestos de la biblioteca';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get privacyAndData => 'Privacidad y datos';

  @override
  String get privacy => 'Privacidad';

  @override
  String get privacySubtitle => 'Qué permanece local y qué se sube';

  @override
  String get dataAndBackup => 'Datos y copia de seguridad';

  @override
  String get dataAndBackupSubtitle =>
      'Protege y restaura tus elementos guardados';

  @override
  String get bin => 'Papelera';

  @override
  String get binSubtitle =>
      'Los elementos eliminados se guardan durante 30 días';

  @override
  String get clearAllData => 'Borrar todos los datos';

  @override
  String get clearAllDataSubtitle =>
      'Eliminar permanentemente todos los enlaces guardados';

  @override
  String get about => 'Acerca de';

  @override
  String get aboutGlimpse => 'Acerca de Glimpse';

  @override
  String get aboutSubtitle => 'Versión, información legal y ayuda';

  @override
  String get accountActions => 'Acciones de la cuenta';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get logOutSubtitle => 'Cerrar sesión en este dispositivo';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountSubtitle => 'Solicitar la eliminación de la cuenta';

  @override
  String get deletingAccount => 'Eliminando tu cuenta…';

  @override
  String get cancel => 'Cancelar';

  @override
  String get deleteAll => 'Eliminar todo';

  @override
  String get clearAllDataQuestion => '¿Borrar todos los datos?';

  @override
  String get clearAllDataWarning =>
      'Esto eliminará permanentemente todas las URL guardadas. No se puede deshacer.';

  @override
  String get allDataCleared => 'Se borraron todos los datos';

  @override
  String get logOutQuestion => '¿Cerrar sesión?';

  @override
  String get logOutWarning =>
      'Tendrás que volver a iniciar sesión para acceder a tu cuenta de Glimpse.';

  @override
  String get deleteAccountQuestion => '¿Eliminar la cuenta?';

  @override
  String get manageSubscription => 'Gestionar suscripción';

  @override
  String get accountDeleted => 'Cuenta eliminada';

  @override
  String get manageYourPlan => 'Gestiona tu plan';

  @override
  String get checkingSaveAllowance => 'Comprobando guardados disponibles';

  @override
  String aiSavesLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count guardados con IA gratuitos',
      one: 'Queda 1 guardado con IA gratuito',
    );
    return '$_temp0';
  }

  @override
  String get captureBody => 'Te avisaremos cuando esté listo.';

  @override
  String get captureQueuedWithoutNotifications => 'Estará listo en Glimpse.';

  @override
  String get captureSchedulingFallback =>
      'Guardado. Abre Glimpse para terminar de organizarlo.';

  @override
  String get captureCouldNotSave => 'No se pudo guardar este enlace';

  @override
  String savedToCollection(String collectionName) {
    return 'Guardado en $collectionName';
  }

  @override
  String get savedWithoutAi => 'Guardado sin análisis de IA';

  @override
  String get aiLimitBody =>
      'Agotaste tus 30 guardados con IA gratuitos de por vida. Toca para mejorar el plan.';

  @override
  String get proAiLimitBody =>
      'Usaste 500 guardados con IA este mes. El enlace se guardó sin análisis de IA.';

  @override
  String get alreadyInYourWorld => 'Ya está entre tus guardados.';

  @override
  String get enrichmentFailed => 'No se pudo completar el análisis';

  @override
  String get tapToRetry => 'Toca para volver a intentarlo.';

  @override
  String get notification => 'Notificación';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get retry => 'Reintentar';

  @override
  String get close => 'Cerrar';

  @override
  String get addUrl => 'Añadir URL';

  @override
  String get newCollection => 'Nueva colección';

  @override
  String get captured => 'Guardado';

  @override
  String get undo => 'Deshacer';

  @override
  String get alreadyInGlimpse => 'Ya está en Glimpse';

  @override
  String get open => 'Abrir';

  @override
  String get tryAgain => 'Intentar de nuevo';

  @override
  String get exitSelection => 'Salir de la selección';

  @override
  String get sources => 'Fuentes';

  @override
  String get viewAllSources => 'Ver todas las fuentes';

  @override
  String get pasteLink => 'Pega un enlace…';

  @override
  String get dismissClipboardSuggestion =>
      'Descartar sugerencia del portapapeles';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get editCollection => 'Editar colección';

  @override
  String get moveContents => 'Mover contenido';

  @override
  String get deleteSelectedCollections => 'Eliminar colecciones seleccionadas';

  @override
  String get delete => 'Eliminar';

  @override
  String get collectionOptions => 'Opciones de la colección';

  @override
  String get grid => 'Cuadrícula';

  @override
  String get list => 'Lista';

  @override
  String get manual => 'Manual';

  @override
  String get newest => 'Más recientes';

  @override
  String get alphabetical => 'A–Z';

  @override
  String get reorder => 'Reordenar';

  @override
  String get upgradeToPro => 'Mejorar a Pro';

  @override
  String get reset => 'Restablecer';

  @override
  String get applyFilters => 'Aplicar filtros';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get capture => 'Guardar';

  @override
  String get capturing => 'Guardando…';

  @override
  String get pasteFromClipboard => 'Pegar desde el portapapeles';

  @override
  String get addToCollection => 'Añadir a una colección';

  @override
  String get more => 'Más';

  @override
  String get notes => 'Notas';

  @override
  String get categoryTechnology => 'Tecnología';

  @override
  String get categoryBusiness => 'Negocios';

  @override
  String get categoryFinance => 'Finanzas';

  @override
  String get categoryScience => 'Ciencia';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryEducation => 'Educación';

  @override
  String get categoryNews => 'Noticias';

  @override
  String get categoryDesign => 'Diseño';

  @override
  String get categoryHistory => 'Historia';

  @override
  String get categoryPhilosophy => 'Filosofía';

  @override
  String get categoryNature => 'Naturaleza';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryTravel => 'Viajes';

  @override
  String get categoryEntertainment => 'Entretenimiento';

  @override
  String get categoryLifestyle => 'Estilo de vida';

  @override
  String get categorySports => 'Deportes';

  @override
  String get categoryOther => 'Otros';

  @override
  String minutesAgo(Object count) {
    return 'hace $count min';
  }

  @override
  String hoursAgo(Object count) {
    return 'hace $count h';
  }

  @override
  String daysAgo(Object count) {
    return 'hace $count d';
  }

  @override
  String get smartNotificationsDescription =>
      'Notificaciones inteligentes sobre tus enlaces guardados';

  @override
  String get done => 'Listo';

  @override
  String get later => 'Más tarde';

  @override
  String get notificationFallbackTitle => 'Notificación';

  @override
  String newNotificationCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notificaciones nuevas',
      one: '1 notificación nueva',
    );
    return '$_temp0';
  }

  @override
  String get captureSomethingWorthReturning =>
      'Guarda algo que valga la pena retomar';

  @override
  String get captureContextAfter =>
      'Glimpse encontrará el contexto después de guardarlo.';

  @override
  String get link => 'Enlace';

  @override
  String get detectedFromClipboard => 'Detectado en el portapapeles';

  @override
  String get collection => 'Colección';

  @override
  String get noCollection => 'Sin colección';

  @override
  String get savingTo => 'Guardando en';

  @override
  String get chooseCollection => 'Elegir colección';

  @override
  String get chooseACollection => 'Elige una colección';

  @override
  String get processingLink => 'Procesando enlace…';

  @override
  String get couldNotLoadCollections =>
      'No se pudieron cargar las colecciones.';

  @override
  String linkCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '1 enlace',
      zero: 'Sin enlaces',
    );
    return '$_temp0';
  }

  @override
  String get noteOptional => 'Nota (opcional)';

  @override
  String get addNoteOptional => 'Añade una nota (opcional)';

  @override
  String get pleaseEnterUrl => 'Ingresa una URL';

  @override
  String get couldNotCaptureLink => 'No se pudo guardar este enlace';

  @override
  String get findingSavedVersion => 'Buscando la versión guardada…';

  @override
  String get openSavedItem => 'Abrir elemento guardado';

  @override
  String collectionSelection(String collectionName) {
    return 'Colección, $collectionName';
  }

  @override
  String get capturedInGlimpse => 'Guardado en Glimpse';

  @override
  String get firstCapturedReady =>
      'Tu primer elemento guardado está listo abajo.';

  @override
  String get shareAnyApp =>
      'Comparte desde cualquier app; Glimpse lo organiza por ti.';

  @override
  String get howGlimpseWorks => 'Cómo funciona Glimpse';

  @override
  String get capturingWhatCaughtYourEye => 'Guardando lo que llamó tu atención';

  @override
  String get findingContext => 'Buscando el contexto';

  @override
  String get invalidLink => 'Enlace no válido';

  @override
  String get rediscover => 'Redescubrir';

  @override
  String get rediscoverSubtitle => 'Vale la pena retomarlo';

  @override
  String get rediscoverTip =>
      'Cada día, Redescubrir elige algunos recuerdos que vale la pena retomar.';

  @override
  String get dismissRediscoverTip => 'Cerrar consejo de Redescubrir';

  @override
  String get pinned => 'Fijados';

  @override
  String get recentSaves => 'Guardados recientes';

  @override
  String get justNow => 'ahora mismo';

  @override
  String weeksAgo(Object count) {
    return 'hace $count sem';
  }

  @override
  String monthsAgo(Object count) {
    return 'hace $count mes';
  }

  @override
  String yearsAgo(Object count) {
    return 'hace $count a';
  }

  @override
  String get retrying => 'Reintentando';

  @override
  String get processing => 'Procesando';

  @override
  String get processingSavedHeadline => 'Guardado en tu biblioteca';

  @override
  String get processingSavedDetail => 'Preparando el contenido guardado';

  @override
  String get processingOpeningHeadline => 'Abriendo el contenido';

  @override
  String get processingOpeningDetail => 'Comprobando qué contiene';

  @override
  String processingReadingHeadline(String content) {
    return 'Leyendo $content';
  }

  @override
  String get processingExtractingDetail => 'Extrayendo los detalles útiles';

  @override
  String get processingUnderstoodHeadline => 'Contenido comprendido';

  @override
  String get processingUnderstoodDetail => 'Convirtiéndolo en algo útil';

  @override
  String get processingFindingHeadline => 'Buscando lo importante';

  @override
  String get processingFindingDetail => 'Buscando las ideas más importantes';

  @override
  String get processingConnectingHeadline => 'Conectando ideas';

  @override
  String get processingConnectingDetail =>
      'Conectándolo con guardados relacionados';

  @override
  String get processingFinishingHeadline => 'Terminando tu guardado';

  @override
  String get processingFinishingDetail =>
      'Preparando la búsqueda y el redescubrimiento';

  @override
  String get processingRetryHeadline => 'Intentando ese paso de nuevo';

  @override
  String get processingRetryDetail => 'Volviendo a intentar este paso';

  @override
  String get processingFailedHeadline => 'No se pudo terminar el proceso';

  @override
  String get processingFailedDetail =>
      'Tu guardado está seguro. Inténtalo de nuevo';

  @override
  String get processingDefaultHeadline => 'Comprendiendo este guardado';

  @override
  String get processingDefaultDetail =>
      'Buscando ideas que vale la pena conservar';

  @override
  String get processingContentReel => 'reel';

  @override
  String get processingContentVideo => 'vídeo';

  @override
  String get processingContentPin => 'pin';

  @override
  String get processingContentPage => 'página';

  @override
  String get needsAttention => 'Requiere atención';

  @override
  String get read => 'Leído';

  @override
  String get unread => 'No leído';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get linkCopied => 'Enlace copiado';

  @override
  String get openOriginal => 'Abrir original';

  @override
  String get share => 'Compartir';

  @override
  String get enrichmentComplete => 'Procesamiento completado';

  @override
  String get couldNotEnrichSave => 'No se pudo procesar este elemento';

  @override
  String get allSources => 'Todas las fuentes';

  @override
  String get all => 'Todo';

  @override
  String get apps => 'Apps';

  @override
  String get websites => 'Sitios web';

  @override
  String get results => 'Resultados';

  @override
  String get topSources => 'Fuentes principales';

  @override
  String get searchSources => 'Buscar apps, sitios y dominios…';

  @override
  String get filterSources => 'Filtrar fuentes';

  @override
  String get couldNotLoadSources => 'No se pudieron cargar las fuentes';

  @override
  String noSourcesMatch(String query) {
    return 'Ninguna fuente coincide con \"$query\"';
  }

  @override
  String get noSavesFromApps => 'Aún no hay elementos guardados desde apps';

  @override
  String get noWebsiteSaves =>
      'Aún no hay elementos guardados desde sitios web';

  @override
  String get noSourcesYet => 'Aún no hay fuentes';

  @override
  String get noSavesYet => 'Aún no hay elementos guardados';

  @override
  String saveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guardados',
      one: '1 guardado',
    );
    return '$_temp0';
  }

  @override
  String savesThisWeek(Object count) {
    return '+$count esta semana';
  }

  @override
  String get growing => 'En crecimiento';

  @override
  String lastSaved(String time) {
    return 'Último guardado $time';
  }

  @override
  String get leftSwipe => 'Deslizar a la izquierda';

  @override
  String get rightSwipe => 'Deslizar a la derecha';

  @override
  String get chooseSwipeAction => 'Elige la acción al deslizar';

  @override
  String get markReadUnread => 'Marcar como leído/no leído';

  @override
  String get pin => 'Fijar';

  @override
  String get none => 'Ninguna';

  @override
  String get smartNotifications => 'Notificaciones inteligentes';

  @override
  String get behaviorBasedAlerts => 'Alertas según tu actividad';

  @override
  String get whereDoYouListen => '¿Dónde escuchas música?';

  @override
  String get chooseMusicProvider =>
      'Elige la app que Glimpse usará para las canciones que encuentres.';

  @override
  String get brightness => 'Brillo';

  @override
  String get brightnessDescription =>
      'Elige cuándo usar colores claros u oscuros.';

  @override
  String get systemTheme => 'Sistema';

  @override
  String get lightTheme => 'Claro';

  @override
  String get darkTheme => 'Oscuro';

  @override
  String get amoledBlack => 'Negro AMOLED';

  @override
  String get amoledUnavailable => 'Disponible cuando no usas el tema claro.';

  @override
  String get amoledDescription =>
      'Fondos completamente negros en OLED para ahorrar energía.';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get dynamicAccentDescription =>
      'Dinámico usa la paleta de tu fondo de pantalla en dispositivos compatibles.';

  @override
  String selectedAccent(String accent) {
    return 'Seleccionado: $accent';
  }

  @override
  String get themePreview => 'Vista previa del tema';

  @override
  String get themePreviewDescription =>
      'El acento y las superficies cambian según tus elecciones.';

  @override
  String get accentDynamic => 'Dinámico';

  @override
  String get accentPurple => 'Morado';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentTeal => 'Verde azulado';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentLime => 'Lima';

  @override
  String get accentYellow => 'Amarillo';

  @override
  String get accentOrange => 'Naranja';

  @override
  String get accentRed => 'Rojo';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentSakura => 'Sakura';

  @override
  String get accentIndigo => 'Índigo';

  @override
  String get accentSlate => 'Pizarra';

  @override
  String get accentMonochrome => 'Monocromo';

  @override
  String get deleted => 'Eliminado';

  @override
  String get noNotificationsYet => 'Aún no hay notificaciones';

  @override
  String get notificationsEmptyDescription =>
      'Aquí aparecerán alertas de viajes, nuevos descubrimientos, recordatorios de lectura y resúmenes semanales.';

  @override
  String get ready => 'listo';

  @override
  String waitingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendientes',
      one: '1 pendiente',
    );
    return '$_temp0';
  }

  @override
  String get backInView => 'De nuevo a la vista';

  @override
  String get couldNotLoadSource => 'No se pudo cargar esta fuente';

  @override
  String get noSavesFromSource => 'No hay guardados de esta fuente';

  @override
  String get saves => 'Guardados';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get opened => 'Abiertos';

  @override
  String get topThemes => 'Temas principales';

  @override
  String get allItems => 'Todos los elementos';

  @override
  String get oldest => 'Más antiguos';

  @override
  String get recentlyOpened => 'Abiertos recientemente';

  @override
  String get showItems => 'Mostrar elementos';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get noItemsFromSource => 'No hay elementos de esta fuente';

  @override
  String get noUnreadItems => 'No hay elementos sin leer';

  @override
  String get noReadItems => 'No hay elementos leídos';

  @override
  String get lastSavedLabel => 'Último guardado';

  @override
  String get markAllRead => 'Marcar todo como leído';

  @override
  String get back => 'Volver';

  @override
  String get subscription => 'Suscripción';

  @override
  String get couldNotLoadSubscription =>
      'No se pudo cargar la información de suscripción';

  @override
  String get coreLibrary => 'Biblioteca principal';

  @override
  String get unlimitedLinkSaving => 'Guardado ilimitado de enlaces';

  @override
  String get unlimitedLinkSavingDescription =>
      'Guarda tantos enlaces como quieras';

  @override
  String get collectionsOrganization => 'Colecciones y organización';

  @override
  String get collectionsOrganizationDescription =>
      'Agrupa y organiza tus marcadores a tu manera';

  @override
  String get smartNotificationsLongDescription =>
      'Alertas según tu actividad y recordatorios de lectura';

  @override
  String get aiAssistant => 'Asistente de IA';

  @override
  String get aiTaggingCategorization => 'Etiquetado y clasificación con IA';

  @override
  String get freeSavesProUnlimited =>
      'Gratis: 30 con IA de por vida · Pro: 500/mes';

  @override
  String get keywordSearch => 'Búsqueda por palabras clave';

  @override
  String get freeSearchesProUnlimited =>
      'Gratis: 30 búsquedas/mes · Pro: acceso ampliado';

  @override
  String get askYourBookmarks => 'Pregunta a tus marcadores';

  @override
  String get freeQuestionsProUnlimited =>
      'Gratis: 30 preguntas/mes · Pro: uso razonable generoso';

  @override
  String get proInsights => 'Información Pro';

  @override
  String get semanticSearch => 'Búsqueda semántica';

  @override
  String get semanticSearchDescription =>
      'Encuentra enlaces por su significado, no solo por palabras';

  @override
  String get weeklyRecap => 'Resumen semanal';

  @override
  String get weeklyRecapDescription =>
      'Resumen de tus enlaces guardados generado por IA';

  @override
  String get multiLinkSynthesis => 'Síntesis de varios enlaces';

  @override
  String get multiLinkSynthesisDescription =>
      'Analiza en conjunto cualquier grupo de marcadores';

  @override
  String get active => 'Activo';

  @override
  String get free => 'Gratis';

  @override
  String get proPlanDescription =>
      '500 guardados con IA al mes, más acceso ampliado a Preguntar y buscar en tu biblioteca.';

  @override
  String get proPlanDevDescription =>
      '500 guardados con IA al mes, más acceso ampliado a Preguntar y buscar. (anulación de desarrollo; tienda: Gratis)';

  @override
  String get freePlanDescription =>
      'Guarda enlaces sin límite y prueba la IA con 30 guardados enriquecidos de por vida.';

  @override
  String get upgradeToGlimpsePro => 'Mejorar a Glimpse Pro';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get manageOnGooglePlay => 'Gestionar en Google Play';

  @override
  String get local => 'Local';

  @override
  String get uploaded => 'Subido';

  @override
  String get bookmarks => 'Marcadores';

  @override
  String get aiSummaries => 'Resúmenes de IA';

  @override
  String get accountInformation => 'Información de la cuenta';

  @override
  String get subscriptionStatus => 'Estado de la suscripción';

  @override
  String get anonymousProductAnalytics => 'Análisis anónimos del producto';

  @override
  String get storageLocation => 'Ubicación de almacenamiento';

  @override
  String get pickAFolder => 'Elegir una carpeta';

  @override
  String get chooseBackupFolderDescription =>
      'Toca para elegir dónde guardar las copias';

  @override
  String get backupFolderInfo =>
      'Se usa para guardar tus archivos de copia. Elige una carpeta una vez y Glimpse seguirá guardando allí las nuevas copias.';

  @override
  String get automaticBackup => 'Copia automática';

  @override
  String get off => 'Desactivada';

  @override
  String get backupFrequencyDescription =>
      'Frecuencia con la que se guarda una copia en tu ubicación';

  @override
  String get backupSensitiveInfo =>
      'Guarda también copias en otros lugares. Pueden incluir toda tu biblioteca; trátalas como información sensible si compartes los archivos.';

  @override
  String get backupAndRestore => 'Copia y restauración';

  @override
  String get createBackup => 'Crear copia';

  @override
  String get restoreBackup => 'Restaurar copia';

  @override
  String lastBackup(Object time) {
    return 'Última copia: $time';
  }

  @override
  String get backupLocalInfo =>
      'Las copias contienen toda tu biblioteca: enlaces, colecciones, etiquetas y metadatos. Permanecen en tu dispositivo.';

  @override
  String get deletedItemsRetention =>
      'Los elementos eliminados se conservan durante 30 días y se borran definitivamente la próxima vez que Glimpse haga limpieza.';

  @override
  String daysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count días',
      one: 'Queda 1 día',
    );
    return '$_temp0';
  }

  @override
  String get expiresToday => 'Caduca hoy';

  @override
  String get restore => 'Restaurar';

  @override
  String get deletePermanently => 'Eliminar definitivamente';

  @override
  String get restoreAll => 'Restaurar todo';

  @override
  String get emptyBin => 'Vaciar papelera';

  @override
  String get binActions => 'Acciones de la papelera';

  @override
  String get itemActions => 'Acciones del elemento';

  @override
  String get binIsEmpty => 'La papelera está vacía';

  @override
  String get binEmptyDescription =>
      'Los elementos que elimines aparecerán aquí durante 30 días.';

  @override
  String get deleteAccountProWarning =>
      'Esto elimina los metadatos de tu cuenta de Glimpse, pero no cancela la facturación de la tienda. Pro no se puede transferir a otra cuenta de Glimpse; gestiona tu suscripción antes de eliminarla. Tu biblioteca del dispositivo no se sube a Supabase.';

  @override
  String get deleteAccountFreeWarning =>
      'Esto elimina los metadatos de tu cuenta de Glimpse. Tu biblioteca del dispositivo no se sube a Supabase.';

  @override
  String get details => 'Detalles';

  @override
  String openInSource(Object source) {
    return 'Abrir en $source';
  }

  @override
  String get summary => 'Resumen';

  @override
  String get inBrief => 'En breve';

  @override
  String get fullExplanation => 'Explicación completa';

  @override
  String get resourcesAndReferences => 'Recursos y referencias';

  @override
  String get searchForResource => 'Buscar este recurso';

  @override
  String get rawSourceMaterial => 'Material original';

  @override
  String get addNote => 'Añadir nota';

  @override
  String get keyTakeaways => 'Ideas clave';

  @override
  String get fullBreakdown => 'Desglose completo';

  @override
  String get transcriptAndCaption => 'Transcripción y descripción';

  @override
  String get caption => 'Descripción';

  @override
  String get transcript => 'Transcripción';

  @override
  String get onScreenText => 'Texto en pantalla';

  @override
  String get peopleMentioned => 'Personas mencionadas';

  @override
  String peopleMentionedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas mencionadas',
      one: '1 persona mencionada',
    );
    return '$_temp0';
  }

  @override
  String get alsoMentioned => 'También se menciona';

  @override
  String get quotes => 'Citas';

  @override
  String get tags => 'Etiquetas';

  @override
  String get informationMayBeInaccurate => 'La información puede ser inexacta';

  @override
  String get originalContentAttribution =>
      'El contenido original pertenece a su creador.';

  @override
  String everyHours(Object count) {
    return 'Cada $count horas';
  }

  @override
  String get weekly => 'Semanal';

  @override
  String get addTag => 'Añadir etiqueta';

  @override
  String get changeCategory => 'Cambiar categoría';

  @override
  String get worthWatching => 'Para ver';

  @override
  String get worthReading => 'Para leer';

  @override
  String get gamesMentioned => 'Juegos mencionados';

  @override
  String get musicMentioned => 'Música mencionada';

  @override
  String get toolsMentioned => 'Herramientas mencionadas';

  @override
  String get worthALook => 'Vale la pena verlo';

  @override
  String get appsToTry => 'Apps para probar';

  @override
  String get placesToVisit => 'Lugares para visitar';

  @override
  String get websitesMentioned => 'Sitios web mencionados';

  @override
  String get claimsToRemember => 'Afirmaciones para recordar';

  @override
  String get termsMentioned => 'Términos mencionados';

  @override
  String get notableDetails => 'Detalles destacados';

  @override
  String get library => 'Biblioteca';

  @override
  String get libraryDescription =>
      'Libros, películas, lugares y música de tus enlaces guardados';

  @override
  String get buildsQuietly => 'Crece poco a poco mientras guardas';

  @override
  String itemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String addedTime(Object time) {
    return 'Añadido · $time';
  }

  @override
  String get rediscoverIntentTitle => 'Recuerdos que vale la pena recuperar';

  @override
  String chosenFromUnopened(Object count) {
    return 'Elegidos entre $count guardados sin abrir y lo que importa ahora.';
  }

  @override
  String get chosenFromSaved =>
      'Elegidos entre lo que guardaste, abriste y dejaste para después.';

  @override
  String get todayStableSet =>
      'Una selección estable para hoy, sin un feed interminable.';

  @override
  String get recaps => 'Resúmenes';

  @override
  String get recapsDescription =>
      'Patrones semanales y mensuales de tus propios guardados.';

  @override
  String get dailyRecap => 'Resumen diario';

  @override
  String get monthlyRecap => 'Resumen mensual';

  @override
  String recapSummary(num count, Object waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guardados',
      one: '1 guardado',
    );
    return '$_temp0 · $waiting sin abrir';
  }

  @override
  String get yourWeekInSaves => 'Tu semana en guardados';

  @override
  String get yourMonthInMemories => 'Tu mes en recuerdos';

  @override
  String topicKeptShowingUp(Object topic) {
    return '$topic siguió apareciendo';
  }

  @override
  String get queued => 'En cola';

  @override
  String get forgottenGem => 'Joya olvidada';

  @override
  String get fromYourPast => 'De tu pasado';

  @override
  String get rediscoverOptions => 'Opciones de redescubrimiento';

  @override
  String get notNow => 'Ahora no';

  @override
  String get hideFor7Days => 'Ocultar durante 7 días';

  @override
  String get lessLikeThis => 'Menos contenido así';

  @override
  String get reduceSimilarTopics => 'Reduce temas parecidos';

  @override
  String get nothingStrongToday => 'Nada destacado para hoy';

  @override
  String get rediscoverQuiet =>
      'Redescubrir esperará hasta que realmente valga la pena recuperar un guardado.';

  @override
  String get searchYourLibrary => 'Busca en tu biblioteca…';

  @override
  String get findAnythingSaved => 'Encuentra todo lo que guardaste';

  @override
  String get searchEmptyDescription =>
      'Busca en títulos, etiquetas, notas y resúmenes, y luego filtra los resultados.';

  @override
  String get filters => 'Filtros';

  @override
  String get filtersActive => 'Filtros activos';

  @override
  String get time => 'Periodo';

  @override
  String get allTime => 'Todo el tiempo';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get status => 'Estado';

  @override
  String get hasNotes => 'Con notas';

  @override
  String get noNotes => 'Sin notas';

  @override
  String get inCollection => 'En una colección';

  @override
  String get notInCollection => 'Fuera de una colección';

  @override
  String get specificCollection => 'Colección específica';

  @override
  String get sort => 'Ordenar';

  @override
  String get relevance => 'Relevancia';

  @override
  String get newestSaved => 'Guardados más recientes';

  @override
  String get oldestSaved => 'Guardados más antiguos';

  @override
  String get learningInterests => 'Aprendiendo qué capta tu atención';

  @override
  String get readingInterests => 'Analizando tus intereses…';

  @override
  String get topSignal => 'Interés principal';

  @override
  String get growingInterests => 'Intereses en crecimiento';

  @override
  String get quieterInterests => 'Otros intereses';

  @override
  String interestStats(num patterns, num saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns patrones',
      one: '1 patrón',
    );
    String _temp1 = intl.Intl.pluralLogic(
      saves,
      locale: localeName,
      other: '$saves guardados',
      one: '1 guardado',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String interestGroupedStats(Object grouped, num patterns, Object saves) {
    String _temp0 = intl.Intl.pluralLogic(
      patterns,
      locale: localeName,
      other: '$patterns patrones',
      one: '1 patrón',
    );
    return '$_temp0 · $grouped de $saves guardados agrupados';
  }

  @override
  String noPatternsScanned(Object saves) {
    return 'Aún no hay patrones · $saves guardados analizados';
  }

  @override
  String get rebuildMap => 'Reconstruir mapa';

  @override
  String get couldNotBuildClusters => 'No se pudieron crear los grupos';

  @override
  String get interestMapEmpty => 'Tu mapa de intereses está vacío';

  @override
  String get interestMapEmptyDescription =>
      'Guarda al menos 3 enlaces y Glimpse conectará los temas recurrentes.';

  @override
  String lastAddedTime(Object time) {
    return 'Último añadido: $time';
  }

  @override
  String get hiddenFor7Days => 'Oculto durante 7 días';

  @override
  String get seeLessLikeThis => 'Verás menos contenido así';

  @override
  String get searchingLibrary => 'Buscando en tu biblioteca…';

  @override
  String get semanticMatch => 'Coincidencia semántica';

  @override
  String get noMatchesForFilter => 'No hay resultados con este filtro';

  @override
  String get broadenSearch => 'Prueba otro periodo o amplía la búsqueda.';

  @override
  String get monthlyLimitReached => 'Alcanzaste el límite mensual';

  @override
  String get searchFailed => 'La búsqueda falló';

  @override
  String get monthlySearchLimitDescription =>
      'Alcanzaste tu límite mensual de búsquedas. Actualiza a Glimpse Pro para ampliar el acceso.';

  @override
  String get openingInterest => 'Abriendo interés…';

  @override
  String get couldNotOpenInterest => 'No se pudo abrir este interés.';

  @override
  String get interestNotFound => 'No se encontró el interés';

  @override
  String interestSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guardados en este interés.',
      one: '1 guardado en este interés.',
    );
    return '$_temp0';
  }

  @override
  String interestTopicsSummary(Object count, Object topics) {
    return '$count guardados en $topics temas';
  }

  @override
  String get reorderCollections => 'Reordenar colecciones';

  @override
  String get dragToSetManualOrder => 'Arrastra para definir el orden manual';

  @override
  String movedToCollection(Object name) {
    return 'Movido a $name';
  }

  @override
  String movedLinksAndDeletedSources(num count, Object name, num sourceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '1 enlace',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sourceCount,
      locale: localeName,
      other: 'eliminaron las colecciones de origen',
      one: 'eliminó la colección de origen',
    );
    return 'Se movieron $_temp0 a $name y se $_temp1';
  }

  @override
  String deleteCollectionNamed(Object name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String deleteCollectionsCount(Object count) {
    return '¿Eliminar $count colecciones?';
  }

  @override
  String get deleteCollectionDescription =>
      'Los enlaces guardados seguirán en tu biblioteca. Solo se eliminará la colección.';

  @override
  String get deleteCollectionsDescription =>
      'Los enlaces guardados seguirán en tu biblioteca. Solo se eliminarán las colecciones.';

  @override
  String collectionsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colecciones eliminadas',
      one: 'Colección eliminada',
    );
    return '$_temp0';
  }

  @override
  String get createFirstCollection => 'Crea tu primera colección';

  @override
  String get collectionEmptyDescription =>
      'Agrupa enlaces en espacios tranquilos y organizados.';

  @override
  String get libraryBooks => 'Libros';

  @override
  String get libraryMoviesShows => 'Películas y series';

  @override
  String get libraryPlaces => 'Lugares';

  @override
  String get libraryBook => 'Libro';

  @override
  String get libraryMovie => 'Película';

  @override
  String get libraryPlace => 'Lugar';

  @override
  String get libraryReadingList => 'Lista de lectura';

  @override
  String get libraryWatchlist => 'Lista para ver';

  @override
  String get libraryNotInReadingList => 'Fuera de la lista de lectura';

  @override
  String get libraryNotInWatchlist => 'Fuera de la lista para ver';

  @override
  String get libraryNotListed => 'Sin añadir';

  @override
  String get libraryPlanning => 'Planeado';

  @override
  String get libraryReading => 'Leyendo';

  @override
  String get libraryWatching => 'Viendo';

  @override
  String get libraryInProgress => 'En curso';

  @override
  String get libraryDropped => 'Abandonado';

  @override
  String get libraryRead => 'Leído';

  @override
  String get libraryWatched => 'Visto';

  @override
  String get libraryVisited => 'Visitado';

  @override
  String libraryStatusSemantics(Object status) {
    return 'Estado: $status';
  }

  @override
  String libraryReadingPageStatus(Object page) {
    return 'Leyendo · pág. $page';
  }

  @override
  String get libraryGenreFantasy => 'Fantasía';

  @override
  String get libraryGenreScienceFiction => 'Ciencia ficción';

  @override
  String get libraryGenreMysteryThriller => 'Misterio y suspenso';

  @override
  String get libraryGenreRomance => 'Romance';

  @override
  String get libraryGenreHorror => 'Terror';

  @override
  String get libraryGenreBiographyMemoir => 'Biografía y memorias';

  @override
  String get libraryGenreHistory => 'Historia';

  @override
  String get libraryGenrePhilosophy => 'Filosofía';

  @override
  String get libraryGenrePsychology => 'Psicología';

  @override
  String get libraryGenreBusiness => 'Negocios';

  @override
  String get libraryGenreFinanceInvesting => 'Finanzas e inversión';

  @override
  String get libraryGenreTechnology => 'Tecnología';

  @override
  String get libraryGenreScience => 'Ciencia';

  @override
  String get libraryGenreSelfDevelopment => 'Desarrollo personal';

  @override
  String get libraryGenreHealthWellness => 'Salud y bienestar';

  @override
  String get libraryGenrePoliticsSociety => 'Política y sociedad';

  @override
  String get libraryGenreArtDesign => 'Arte y diseño';

  @override
  String get libraryGenreTravel => 'Viajes';

  @override
  String get libraryGenreComicsGraphicNovels => 'Cómics y novelas gráficas';

  @override
  String get libraryGenreFiction => 'Ficción';

  @override
  String get libraryGenreAction => 'Acción';

  @override
  String get libraryGenreAdventure => 'Aventura';

  @override
  String get libraryGenreAnimation => 'Animación';

  @override
  String get libraryGenreComedy => 'Comedia';

  @override
  String get libraryGenreCrime => 'Crimen';

  @override
  String get libraryGenreDocumentary => 'Documental';

  @override
  String get libraryGenreDrama => 'Drama';

  @override
  String get libraryGenreFamily => 'Familiar';

  @override
  String get libraryGenreMystery => 'Misterio';

  @override
  String get libraryGenreThriller => 'Suspenso';

  @override
  String get libraryGenreWar => 'Bélica';

  @override
  String get libraryGenreWestern => 'Wéstern';

  @override
  String get libraryGenreMusic => 'Música';

  @override
  String get libraryGenreOther => 'Otros';

  @override
  String get librarySubtypeTvShow => 'Serie de TV';

  @override
  String get librarySubtypeSeries => 'Serie';

  @override
  String get couldNotOpenLibrary => 'No se pudo abrir la Biblioteca';

  @override
  String searchLibraryItems(Object kind) {
    return 'Buscar en $kind';
  }

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get recentlyDiscovered => 'Descubiertos recientemente';

  @override
  String get titleAZ => 'Título A–Z';

  @override
  String get yearNewest => 'Año más reciente';

  @override
  String libraryOptions(Object kind) {
    return 'Opciones de $kind';
  }

  @override
  String filterLibraryItems(Object kind) {
    return 'Filtrar $kind';
  }

  @override
  String get readingStatus => 'Estado de lectura';

  @override
  String get watchStatus => 'Estado de visualización';

  @override
  String get anyStatus => 'Cualquier estado';

  @override
  String get genre => 'Género';

  @override
  String get allGenres => 'Todos los géneros';

  @override
  String get nothingMatchesFilters => 'Nada coincide con estos filtros.';

  @override
  String get nothingRecognizedHere => 'Aún no hay nada reconocido aquí.';

  @override
  String get couldNotUpdateLibraryItem =>
      'No se pudo actualizar este elemento de la Biblioteca.';

  @override
  String get foundInYourSaves => 'Encontrado en tus guardados';

  @override
  String get recognizedOrganizedByType => 'Organizado automáticamente por tipo';

  @override
  String libraryBookCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libros',
      one: '1 libro',
    );
    return '$_temp0';
  }

  @override
  String libraryMovieCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count títulos',
      one: '1 título',
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
  String get nothingRecognizedYet => 'Aún no hay nada reconocido';

  @override
  String get recognizedTitlesGatherHere =>
      'Los títulos reconocidos aparecerán aquí';

  @override
  String recognizedCount(Object count) {
    return '$count reconocidos';
  }

  @override
  String get savedPlacesAppearOnMap =>
      'Los lugares guardados aparecerán en un mapa';

  @override
  String get addingDetails => 'Añadiendo detalles';

  @override
  String get extraDetailsUnavailable =>
      'Los detalles adicionales no están disponibles temporalmente';

  @override
  String itemsCouldNotRefresh(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron actualizar $count elementos',
      one: 'No se pudo actualizar 1 elemento',
    );
    return '$_temp0';
  }

  @override
  String progressOf(Object completed, Object total) {
    return '$completed de $total';
  }

  @override
  String get savedDetailsRemainAvailable =>
      'Los detalles guardados siguen disponibles';

  @override
  String waitingToRetry(Object count) {
    return '$count pendientes de reintento';
  }

  @override
  String get libraryBuildsAsYouSave => 'Crece mientras guardas';

  @override
  String get libraryEmptyDescription =>
      'Guarda recomendaciones de libros, películas, lugares y música. Glimpse organizará aquí lo que encuentre en ellas.';

  @override
  String get libraryUnavailable => 'La Biblioteca no está disponible ahora';

  @override
  String get yourPlaces => 'Tus lugares';

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
      other: '$areas zonas',
      one: '1 zona',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get planThisArea => 'Planear esta zona';

  @override
  String get planAnItinerary => 'Planear un itinerario';

  @override
  String get searchSavedPlaces => 'Buscar lugares guardados';

  @override
  String get yourPlans => 'Tus planes';

  @override
  String get plan => 'Planear';

  @override
  String get locationUnavailable => 'Ubicación no disponible';

  @override
  String openNamedItem(Object name) {
    return 'Abrir $name';
  }

  @override
  String get wantToVisit => 'Quiero visitar';

  @override
  String get savedPlace => 'Lugar guardado';

  @override
  String get planAVisit => 'Planear una visita';

  @override
  String get maps => 'Mapas';

  @override
  String get noSavedPlacesMatch =>
      'Ningún lugar guardado coincide con esta búsqueda.';

  @override
  String get noPlacesDiscovered => 'Aún no se descubrieron lugares';

  @override
  String get placesMentionedGatherHere =>
      'Los lugares mencionados en tus guardados aparecerán aquí.';

  @override
  String get fitAllPlaces => 'Mostrar todos los lugares';

  @override
  String get noMappedPlaces => 'Aún no hay lugares en el mapa';

  @override
  String get mapUnavailablePlacesListed =>
      'El mapa no está disponible; tus lugares siguen en la lista inferior';

  @override
  String get libraryItemUnavailable =>
      'Este elemento de la Biblioteca no está disponible.';

  @override
  String get couldNotUpdateBookmark => 'No se pudo actualizar tu marcador.';

  @override
  String hiddenFromLibrary(Object name) {
    return '$name se ocultó de la Biblioteca';
  }

  @override
  String get libraryItemOptions => 'Opciones del elemento de la Biblioteca';

  @override
  String get hideFromLibrary => 'Ocultar de la Biblioteca';

  @override
  String get addToReadingList => 'Añadir a tu lista de lectura';

  @override
  String get addToWatchlist => 'Añadir a tu lista para ver';

  @override
  String get removeFromReadingList => 'Quitar de la lista de lectura';

  @override
  String get removeFromWatchlist => 'Quitar de la lista para ver';

  @override
  String get whyItMattered => 'Por qué importó';

  @override
  String get plot => 'Sinopsis';

  @override
  String get yourBookmark => 'Tu marcador';

  @override
  String get savePageYouAreOn => 'Guarda la página en la que estás';

  @override
  String savePlaceAboutPages(Object count) {
    return 'Guarda tu avance · unas $count páginas';
  }

  @override
  String pageNumber(Object page) {
    return 'Página $page';
  }

  @override
  String pageAboutPages(Object count, Object page) {
    return 'Página $page · unas $count páginas';
  }

  @override
  String get setCurrentPage => 'Indicar página actual';

  @override
  String get updatePage => 'Actualizar página';

  @override
  String get updateYourBookmark => 'Actualizar tu marcador';

  @override
  String aboutPages(Object count) {
    return 'unas $count páginas';
  }

  @override
  String get currentPage => 'Página actual';

  @override
  String get enterPageNumber => 'Introduce un número de página';

  @override
  String get saveBookmark => 'Guardar marcador';

  @override
  String get pageGreaterThanZero =>
      'Introduce un número de página mayor que cero';

  @override
  String libraryItemSemantics(Object kind, Object title) {
    return '$kind: $title';
  }

  @override
  String libraryItemOpenHint(Object list) {
    return 'Toca dos veces para abrir. Mantén pulsado para cambiar el estado de $list.';
  }

  @override
  String get collectionEditSubtitle => 'Perfecciona este espacio guardado.';

  @override
  String get collectionCreateSubtitle =>
      'Crea un espacio enfocado para tus ideas guardadas.';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get descriptionLabel => 'Descripción';

  @override
  String get collectionNameHint => 'Viajes y aventuras';

  @override
  String get collectionDescriptionHint => 'Nota opcional para este espacio';

  @override
  String get save => 'Guardar';

  @override
  String get create => 'Crear';

  @override
  String get nameCollectionError => 'Ponle un nombre a la colección';

  @override
  String get duplicateCollectionError =>
      'Ya existe una colección con este nombre';

  @override
  String get deleteCollection => 'Eliminar colección';

  @override
  String get addLink => 'Añadir enlace';

  @override
  String get noLinksInCollection => 'Esta colección aún no tiene enlaces.';

  @override
  String get notificationTravelPlaces => 'Viajes y lugares';

  @override
  String get notificationNewDiscovery => 'Nuevo descubrimiento';

  @override
  String get notificationReadingReminder => 'Recordatorio de lectura';

  @override
  String get notificationActivity => 'Actividad';

  @override
  String get notificationWorthRevisiting => 'Vale la pena revisitar';

  @override
  String get notificationRevisitReminder => 'Recordatorio para revisitar';

  @override
  String get notificationWeeklyDigest => 'Resumen semanal';

  @override
  String get enrichmentNeedsAttention => 'El análisis necesita atención';

  @override
  String get aiDetailsAvailable => 'Hay detalles de IA disponibles';

  @override
  String get enrich => 'Analizar';

  @override
  String get enriching => 'Analizando';

  @override
  String get messageGlimpse => 'Escribe a Glimpse...';

  @override
  String get askAboutThisSave => 'Pregunta sobre este guardado...';

  @override
  String get sending => 'Enviando...';

  @override
  String get send => 'Enviar';

  @override
  String get askGreetingEarlyMorning => '¿Has madrugado?';

  @override
  String get askGreetingMorning => 'Buenos días.';

  @override
  String get askGreetingAfternoon => '¿Qué exploramos?';

  @override
  String get askGreetingEvening => 'Buenas tardes.';

  @override
  String get askGreetingNight => '¿Sigues con curiosidad esta noche?';

  @override
  String get askGreetingLateNight => '¿Otra vez despierto hasta tarde?';

  @override
  String get saveYourFirstLink => 'Guarda tu primer enlace';

  @override
  String get moreSelectionActions => 'Más acciones de selección';

  @override
  String get moveToCollection => 'Mover a una colección';

  @override
  String get markRead => 'Marcar como leído';

  @override
  String get markUnread => 'Marcar como no leído';

  @override
  String get toggleReadStatus => 'Cambiar estado de lectura';

  @override
  String get unpin => 'Desfijar';

  @override
  String get yourNote => 'Tu nota';

  @override
  String get edit => 'Editar';

  @override
  String get notePrompt => '¿Qué te llamó la atención?';

  @override
  String get quickAdd => 'Añadir rápido';

  @override
  String get noteSaving => 'Guardando…';

  @override
  String get noteSaved => 'Guardado';

  @override
  String get noteCouldNotSave => 'No se pudo guardar';

  @override
  String get addYourNote => 'Añade tu nota';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get showMore => 'Mostrar más';

  @override
  String showAllCount(Object count) {
    return 'Mostrar todo ($count)';
  }

  @override
  String get answerCopied => 'Respuesta copiada';

  @override
  String get deleteAskNoteQuestion => '¿Eliminar la nota de Ask?';

  @override
  String get deleteAskNoteDescription =>
      'Esto elimina la respuesta guardada de este enlace. Tu propia nota no se verá afectada.';

  @override
  String get askNoteDeleted => 'Nota de Ask eliminada';

  @override
  String get couldNotDeleteAskNote => 'No se pudo eliminar la nota de Ask';

  @override
  String get askNoteActions => 'Acciones de la nota de Ask';

  @override
  String get copyAnswer => 'Copiar respuesta';

  @override
  String get quickTryThisWeekend => 'Probar este fin de semana';

  @override
  String get quickNeedIngredients => 'Necesito ingredientes';

  @override
  String get quickShareWithSomeone => 'Compartir con alguien';

  @override
  String get quickAlreadyTried => 'Ya lo probé';

  @override
  String get quickWatchLater => 'Ver más tarde';

  @override
  String get quickAddToWatchlist => 'Añadir a la lista para ver';

  @override
  String get quickAlreadyWatched => 'Ya lo vi';

  @override
  String get quickAddToReadingList => 'Añadir a la lista de lectura';

  @override
  String get quickReadLater => 'Leer más tarde';

  @override
  String get quickResearchThis => 'Investigar esto';

  @override
  String get quickAlreadyRead => 'Ya lo leí';

  @override
  String get quickTryThisTool => 'Probar esta herramienta';

  @override
  String get quickCompareAlternatives => 'Comparar alternativas';

  @override
  String get quickUseInProject => 'Usar en un proyecto';

  @override
  String get quickShareWithTeam => 'Compartir con el equipo';

  @override
  String get quickPlanItinerary => 'Planear itinerario';

  @override
  String get quickCheckBestSeason => 'Consultar la mejor temporada';

  @override
  String get quickSaveRoute => 'Guardar ruta';

  @override
  String get quickPracticeLater => 'Practicar más tarde';

  @override
  String get quickMakeChecklist => 'Crear lista de tareas';

  @override
  String get quickRevisitNotes => 'Revisar notas';

  @override
  String get quickRevisitLater => 'Revisitar más tarde';

  @override
  String get quickWorthTrying => 'Vale la pena probarlo';

  @override
  String get quickAlreadyChecked => 'Ya lo revisé';

  @override
  String get aboutTagline => 'Guarda algo que merezca conservarse';

  @override
  String versionBuild(Object build, Object version) {
    return 'Versión $version (compilación $build)';
  }

  @override
  String get loadingVersion => 'Cargando versión…';

  @override
  String get legal => 'Legal';

  @override
  String get termsOfService => 'Términos del servicio';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get help => 'Ayuda';

  @override
  String get faq => 'Preguntas frecuentes';

  @override
  String get sendFeedback => 'Enviar comentarios';

  @override
  String get rateOnPlayStore => 'Valorar en Play Store';

  @override
  String get shareGlimpse => 'Compartir Glimpse';

  @override
  String get feedbackEmailSubject => 'Comentarios sobre Glimpse';

  @override
  String shareGlimpseText(Object url) {
    return 'Glimpse te ayuda a guardar enlaces a los que vale la pena volver. Pruébalo: $url';
  }

  @override
  String get couldNotOpenLink => 'No se pudo abrir este enlace.';

  @override
  String get couldNotShareGlimpse => 'No se pudo compartir Glimpse.';

  @override
  String get keepsakeQuoteCuriosity =>
      'Conserva lo que mantiene viva tu curiosidad.';

  @override
  String get keepsakeQuoteIdea =>
      'Un pequeño vistazo puede convertirse en una idea duradera.';

  @override
  String get keepsakeQuoteSpark => 'Guarda la chispa. Vuelve cuando importe.';

  @override
  String get keepsakeQuoteFutureSelf =>
      'Puede que tu yo del futuro esté buscando esto.';

  @override
  String get keepsakeQuoteNoticing =>
      'Vale la pena notarlo. Vale la pena guardarlo.';

  @override
  String get other => 'Otros';

  @override
  String get shareBackup => 'Compartir copia de seguridad';

  @override
  String get shareBackupDescription =>
      'Envía una copia a otra aplicación o servicio en la nube';

  @override
  String backupSavedLinksTo(num count, Object location) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces',
      one: '1 enlace',
    );
    return 'Se guardaron $_temp0 en $location';
  }

  @override
  String backupSavedTo(Object location) {
    return 'Copia guardada en $location';
  }

  @override
  String get errorDetails => 'Detalles del error';

  @override
  String get copy => 'Copiar';

  @override
  String get couldNotReadSelectedFile =>
      'No se pudo leer el archivo seleccionado.';

  @override
  String get folderSelected => 'Carpeta seleccionada';

  @override
  String get couldNotSaveFolderPermission =>
      'No se pudo guardar el permiso de la carpeta. Inténtalo de nuevo.';

  @override
  String get permanentBackupFolderAndroid =>
      'La carpeta permanente de copias está disponible en Android';

  @override
  String get tapToChange => 'Toca para cambiar';

  @override
  String get forgetFolder => 'Olvidar carpeta';

  @override
  String get autoBackupAndroidOnly =>
      'La copia automática funciona en Android al configurar una carpeta';

  @override
  String lastAutomaticBackup(Object time) {
    return 'Última copia automática: $time';
  }

  @override
  String lastBackupAttemptFailed(Object time) {
    return 'El último intento falló $time. Glimpse volverá a intentarlo automáticamente.';
  }

  @override
  String get setStorageBeforeAutoBackup =>
      'Configura arriba una ubicación antes de usar las copias automáticas.';

  @override
  String get folderBackup => 'Copia en carpeta';

  @override
  String lastSavedToFolder(Object time) {
    return 'Último guardado en la carpeta: $time';
  }

  @override
  String get noBackupFileInFolder =>
      'Todavía no hay una copia en esta carpeta. Elige la ubicación y usa Crear copia arriba.';

  @override
  String get highlight => 'Resaltar';

  @override
  String get removeHighlight => 'Quitar resaltado';

  @override
  String get highlightAdded => 'Resaltado guardado';

  @override
  String get highlightRemoved => 'Resaltado eliminado';

  @override
  String get highlightFailed => 'No se pudo actualizar el resaltado.';

  @override
  String get readerOverviewOnly =>
      'Solo hay un breve resumen de este contenido guardado. Abre la fuente para ver el contenido completo.';
}
