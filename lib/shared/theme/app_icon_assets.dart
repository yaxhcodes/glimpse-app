part of 'app_icons.dart';

// Semantic IconData remains compatible with persisted preferences and pickers.
// All artwork resolution belongs here so every consumer uses the same drawing.
final _appIconOutlineAssets = <IconData, (String, String)>{
  AppIcons.home: (AppAssets.homeIcon, AppAssets.homeSelectedIcon),
  AppIcons.collections: (
    AppAssets.collectionsIcon,
    AppAssets.collectionsSelectedIcon,
  ),
  AppIcons.interests: (
    AppAssets.interestsIcon,
    AppAssets.interestsSelectedIcon,
  ),
  AppIcons.search: (AppAssets.searchIcon, AppAssets.searchSelectedIcon),
  AppIcons.addLink: (AppAssets.addLinkIcon, AppAssets.addLinkIcon),
  AppIcons.addToCollection: (
    AppAssets.addToCollectionIcon,
    AppAssets.addToCollectionFilledIcon,
  ),
  for (final entry in <IconData, String>{
    AppIcons.bookmark: 'bookmark',
    AppIcons.notifications: 'notification',
    AppIcons.calendar: 'calendar',
    AppIcons.settings: 'setting',
    AppIcons.document: 'document',
    AppIcons.feedback: 'message',
    AppIcons.heart: 'heart',
    AppIcons.game: 'game',
    AppIcons.place: 'location',
    AppIcons.wallet: 'wallet',
    AppIcons.rate: 'star',
    AppIcons.privacy: 'shield-done',
    AppIcons.clearData: 'delete',
    AppIcons.about: 'info-circle',
    AppIcons.logout: 'logout',
  }.entries)
    entry.key: (
      'assets/icons/iconly-${entry.value}.svg',
      'assets/icons/iconly-${entry.value}-selected.svg',
    ),
};

final _appIconAssets = <IconData, (String, String)>{
  ..._appIconOutlineAssets,
  // Explicit filled tokens arrive from saved-state and menu consumers too.
  for (final entry in AppIcons._filledVariants.entries)
    if (_appIconOutlineAssets[entry.key] case final pair?)
      entry.value: (pair.$2, pair.$2),
};
