import 'package:flutter/widgets.dart';

enum AnalyticsEvent {
  appOpen('app_open'),
  sessionStart('session_start'),
  sessionEnd('session_end'),
  screenOpen('screen_open'),
  homeOpened('home_opened'),
  saveCompleted('save_completed'),
  rediscoverOpened('rediscover_opened'),
  searchOpened('search_opened'),
  askGlimpseOpened('ask_glimpse_opened'),
  libraryOpened('library_opened'),
  libraryBooksOpened('library_books_opened'),
  libraryMoviesOpened('library_movies_opened'),
  libraryPlacesOpened('library_places_opened'),
  libraryMusicOpened('library_music_opened'),
  libraryPlaceAreaSelected('library_place_area_selected'),
  libraryPlaceStatusChanged('library_place_status_changed'),
  placeItineraryCreated('place_itinerary_created'),
  placeItineraryOpened('place_itinerary_opened'),
  placeItineraryRouteOpened('place_itinerary_route_opened'),
  libraryBackfillSucceeded('library_backfill_succeeded'),
  libraryBackfillFailed('library_backfill_failed'),
  subscriptionScreenOpened('subscription_screen_opened'),
  subscriptionPurchased('subscription_purchased'),
  settingsOpened('settings_opened'),
  onboardingStarted('onboarding_started'),
  onboardingChapterWelcome('onboarding_chapter_welcome'),
  onboardingChapterReader('onboarding_chapter_reader'),
  onboardingChapterLibrary('onboarding_chapter_library'),
  onboardingChapterDiscovered('onboarding_chapter_discovered'),
  onboardingChapterAsk('onboarding_chapter_ask'),
  onboardingChapterRediscover('onboarding_chapter_rediscover'),
  onboardingChapterPro('onboarding_chapter_pro'),
  onboardingProExplored('onboarding_pro_explored'),
  onboardingGuidanceDismissed('onboarding_guidance_dismissed'),
  onboardingFirstSave('onboarding_first_real_save'),
  onboardingFirstRead('onboarding_first_real_read'),
  notificationPermissionEnabled('notification_permission_enabled'),
  notificationPermissionDeclined('notification_permission_declined'),
  onboardingTransformed('onboarding_transformed'),
  onboardingSkipped('onboarding_skipped'),
  onboardingCompleted('onboarding_completed');

  const AnalyticsEvent(this.name);

  final String name;
}

enum AnalyticsScreen {
  home('home'),
  collections('collections'),
  interests('interests'),
  search('search'),
  addUrl('add_url'),
  settings('settings'),
  subscription('subscription'),
  privacy('privacy'),
  rediscover('rediscover'),
  askGlimpse('ask_glimpse'),
  urlDetail('url_detail'),
  dataBackup('data_backup'),
  onboarding('onboarding');

  const AnalyticsScreen(this.name);

  final String name;
}

abstract interface class AnalyticsService {
  String get sessionId;

  Future<void> initialize();

  Future<void> trackEvent(AnalyticsEvent event, {AnalyticsScreen? screen});

  Future<void> trackScreen(AnalyticsScreen screen);

  Future<void> flush();

  Future<void> handleLifecycleState(AppLifecycleState state);

  Future<void> dispose();
}
