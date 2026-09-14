import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../l10n/l10n.dart';
import 'onboarding_progress.dart';

enum FirstUseKind { reader, library, rediscover }

class FirstUseGuide extends ConsumerStatefulWidget {
  const FirstUseGuide({super.key, required this.kind});
  final FirstUseKind kind;
  @override
  ConsumerState<FirstUseGuide> createState() => _FirstUseGuideState();
}

class _FirstUseGuideState extends ConsumerState<FirstUseGuide> {
  bool _visible = false;
  String get _key => 'onboarding_v2_guide_${widget.kind.name}';
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted ||
          p.getBool(OnboardingProgress.enabledKey) != true ||
          p.getBool(_key) == true) {
        return;
      }
      setState(() => _visible = true);
      await p.setBool(_key, true);
    } catch (error, stackTrace) {
      developer.log(
        'Could not load first-use guidance',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
      if (mounted) {
        await ref
            .read(analyticsServiceProvider)
            .trackEvent(AnalyticsEvent.onboardingGuidanceDismissed);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not persist first-use guidance',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final l = context.l10n;
    final text = switch (widget.kind) {
      FirstUseKind.reader => l.obReaderGuide,
      FirstUseKind.library => l.obLibraryGuide,
      FirstUseKind.rediscover => l.obRediscoverGuide,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(child: Text(text)),
              IconButton(
                tooltip: l.obDismiss,
                onPressed: _dismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
