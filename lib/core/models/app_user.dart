import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastSeen,
    required this.platform,
    required this.appVersion,
    required this.buildVersion,
    this.country,
    this.timezone,
    required this.onboardingCompleted,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final String platform;
  final String appVersion;
  final String buildVersion;
  final String? country;
  final String? timezone;
  final bool onboardingCompleted;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastSeen,
    String? platform,
    String? appVersion,
    String? buildVersion,
    String? country,
    String? timezone,
    bool? onboardingCompleted,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      buildVersion: buildVersion ?? this.buildVersion,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}
