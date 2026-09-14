import 'package:flutter/material.dart';
import '../../core/services/usage_limits.dart';
import '../../l10n/l10n.dart';
import '../ask/ask_screen.dart';
import '../ask/ask_provider.dart';
import '../rediscover/journey_visual.dart';
import '../rediscover/rediscover_journey_provider.dart';

abstract final class OnboardingArtwork {
  static String artwork(String name) => 'assets/onboarding/$name.webp';
}

class OnboardingProductPreview extends StatelessWidget {
  const OnboardingProductPreview({
    super.key,
    required this.chapter,
    this.part = 0,
  });
  final int chapter;
  final int part;
  @override
  Widget build(BuildContext context) => switch (chapter) {
    0 => const _WelcomeScene(),
    4 => const _AskScene(),
    5 => _ReturnScene(part: part),
    _ => const _PlanScene(),
  };
}

class _WelcomeScene extends StatelessWidget {
  const _WelcomeScene();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: .8,
          child: Image.asset(
            OnboardingArtwork.artwork('opening'),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ],
  );
}

class _AskScene extends StatelessWidget {
  const _AskScene();
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            OnboardingArtwork.artwork('ask-landscape'),
            width: double.infinity,
            height: 96,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 18),
        AskConversationPreview(
          messages: [
            ChatMessage(
              id: 'onboarding-question',
              text: l.obQuestion,
              isUser: true,
            ),
            ChatMessage(
              id: 'onboarding-answer',
              text: l.obAnswer,
              isUser: false,
              label: 'Glimpse',
            ),
          ],
        ),
      ],
    );
  }
}

class _ReturnScene extends StatelessWidget {
  const _ReturnScene({this.part = 0});
  final int part;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final journey = RediscoverJourney(
      kind: RediscoverJourneyKind.becauseYouSaved,
      title: l.obTravel,
      subtitle: l.obAutomaticNote,
      icon: Icons.auto_awesome_outlined,
      items: const [],
      signal: 1,
      topicAnchor: 'Travel',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (part == 0 || part == 1)
          RediscoverArtworkCard(
            journey: journey,
            title: l.obTravel,
            supportingText: l.obAutomaticNote,
            metadata: l.glimpsesWhyToday,
            height: 224,
          ),
        if (part == 0) const SizedBox(height: 16),
        if (part == 0 || part == 2)
          RediscoverArtworkCard(
            journey: RediscoverJourney(
              kind: RediscoverJourneyKind.memoryGoal,
              title: l.obCooking,
              subtitle: l.obRevisit,
              icon: Icons.bookmark_outline,
              items: const [],
              signal: 1,
              topicAnchor: 'Cooking',
            ),
            title: l.obChosen,
            supportingText: l.obRevisit,
            metadata: l.obChosenNote,
            height: 224,
          ),
      ],
    );
  }
}

class _PlanScene extends StatelessWidget {
  const _PlanScene();
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _SceneCard(
      children: [
        Text(l.obFree, style: Theme.of(context).textTheme.titleLarge),
        Text(l.obUnlimited),
        Text(l.obFreeAi(UsageLimits.planAllowance(UsageFeature.aiSave))),
        Text(l.obMonthlyAsk(UsageLimits.planAllowance(UsageFeature.ask))),
        Text(l.obMonthlySearch(UsageLimits.planAllowance(UsageFeature.search))),
        const Divider(),
        Text('Glimpse Pro', style: Theme.of(context).textTheme.titleLarge),
        Text(
          l.obProAi(
            UsageLimits.planAllowance(UsageFeature.aiSave, isPro: true),
          ),
        ),
        Text(l.obFairUse),
        Text(l.obSemantic),
      ],
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    ),
  );
}
