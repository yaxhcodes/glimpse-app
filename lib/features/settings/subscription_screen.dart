import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_environment.dart';
import '../../core/providers/analytics_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/app_haptics.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/providers/usage_providers.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/usage_limits.dart';
import 'package:purchases_flutter/purchases_flutter.dart'
    show Package, PackageType;
import '../../l10n/l10n.dart';
import '../../shared/widgets/expressive_loading_indicator.dart';
import 'settings_components.dart';
import 'package:glimpse/shared/theme/app_icons.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  /// Identifier of the plan tapped in the picker; null until one is.
  String? _chosen;

  // NO initState refresh. The notifier's `build()` already serves the
  // cached tier from RevenueCat's local cache instantly, and the
  // `addCustomerInfoUpdateListener` pushes any future change into state.
  // Kicking off a refresh here was the source of the "loader every time
  // the screen opens" and the "Free flash over a correct Pro badge".

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = context.l10n;
    final tierAsync = ref.watch(subscriptionTierProvider);
    developer.log(
      'SubscriptionScreen: rebuild with tier=$tierAsync',
      name: 'Subscription',
    );

    return tierAsync.when(
      loading: () => SettingsPageScaffold(
        title: strings.subscription,
        children: const [
          SizedBox(height: 80),
          Center(child: ExpressiveLoadingIndicator()),
        ],
      ),
      error: (_, _) => SettingsPageScaffold(
        title: strings.subscription,
        children: [
          const SizedBox(height: 48),
          Icon(AppIcons.error, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            strings.couldNotLoadSubscription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(subscriptionTierProvider),
              child: Text(strings.retry),
            ),
          ),
        ],
      ),
      data: (rcTier) {
        final isPro = ref.watch(isProUserProvider);
        final showDevOverrideHint =
            AppEnvironment.allowsLocalProOverride &&
            (ref.watch(devProOverrideProvider).valueOrNull ?? false) &&
            rcTier == SubscriptionTier.free;

        final plans = rcTier == SubscriptionTier.free
            ? ref.watch(subscriptionPlansProvider).valueOrNull
            : null;
        final selected = _selectedPackage(plans);

        return SettingsPageScaffold(
          title: strings.subscription,
          bottomPadding: 24,
          // The call to action stays in reach, under the scroll.
          bottomBar: _CtaFooter(
            rcTier: rcTier,
            price: selected == null ? null : _priceLabel(strings, selected),
            onUpgrade: () => _showPaywall(context, ref, selected),
            onRestore: () => _restorePurchases(context, ref),
            onManage: () => _openCustomerCenter(context, ref),
            onManageOnPlay: () => _manageSubscription(context),
          ),
          children: [
            _PlanHero(isPro: isPro, showDevOverrideHint: showDevOverrideHint),
            const SizedBox(height: 28),
            SettingsGroupLabel(strings.planYourUsage),
            _UsagePanel(isPro: isPro),
            if (plans != null) ...[
              const SizedBox(height: 24),
              SettingsGroupLabel(strings.choosePlan),
              _PlanPicker(
                plans: plans,
                selected: selected,
                onSelect: (package) =>
                    setState(() => _chosen = package.identifier),
              ),
            ],
            const SizedBox(height: 24),
            SettingsGroupLabel(strings.compareTitle),
            const _CompareTable(),
            SettingsFootnote(strings.fairUseNote),
            const SizedBox(height: 8),
            const _LegalLinks(),
          ],
        );
      },
    );
  }

  /// The package the person picked, else yearly (the better deal), else
  /// whatever the offering has.
  Package? _selectedPackage(SubscriptionPlans? plans) {
    if (plans == null) return null;
    for (final package in [plans.monthly, plans.yearly]) {
      if (package != null && package.identifier == _chosen) return package;
    }
    return plans.yearly ?? plans.monthly ?? plans.fallback;
  }

  static String _priceLabel(AppLocalizations strings, Package package) {
    final price = package.storeProduct.priceString;
    return switch (package.packageType) {
      PackageType.annual => strings.pricePerYear(price),
      PackageType.monthly => strings.pricePerMonth(price),
      _ => price,
    };
  }

  Future<void> _showPaywall(
    BuildContext context,
    WidgetRef ref,
    Package? package,
  ) async {
    final service = ref.read(subscriptionServiceProvider);
    if (!service.isConfigured) {
      _showSubscriptionMessage(context, (s) => s.subscriptionsUnavailableBuild);
      return;
    }

    // 1. Native purchase via RevenueCat.
    final purchaseOutcome = await service.purchaseRecommendedPackage(
      package: package,
    );
    if (!context.mounted) return;
    switch (purchaseOutcome) {
      case SubscriptionPurchaseOutcome.cancelled:
        return;
      case SubscriptionPurchaseOutcome.pending:
        _showSubscriptionMessage(context, (s) => s.purchasePending);
        return;
      case SubscriptionPurchaseOutcome.ownedByAnotherAccount:
        _showSubscriptionMessage(context, (s) => s.subscriptionOtherAccount);
        return;
      case SubscriptionPurchaseOutcome.unavailable:
        _showSubscriptionMessage(context, (s) => s.subscriptionsUnavailableNow);
        return;
      case SubscriptionPurchaseOutcome.failed:
        _showSubscriptionMessage(context, (s) => s.purchaseFailed);
        return;
      case SubscriptionPurchaseOutcome.success:
      case SubscriptionPurchaseOutcome.alreadyPurchased:
        break;
    }

    // 2. Explicit, one-shot post-purchase reconciliation so the local
    // RevenueCat cache does not serve the pre-purchase "free" payload for up
    // to five minutes.
    await ref.read(subscriptionTierProvider.notifier).refreshAfterPurchase();

    if (!context.mounted) return;
    final entitled =
        ref.read(subscriptionTierProvider).valueOrNull ==
        SubscriptionTier.premium;
    if (entitled) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .trackEvent(
              AnalyticsEvent.subscriptionPurchased,
              screen: AnalyticsScreen.subscription,
            ),
      );
      _showSubscriptionMessage(context, (s) => s.welcomeToPro);
    } else {
      _showSubscriptionMessage(
        context,
        (s) => purchaseOutcome == SubscriptionPurchaseOutcome.alreadyPurchased
            ? s.subscriptionOtherAccount
            : s.purchaseNotVerified,
      );
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final service = ref.read(subscriptionServiceProvider);
    // Purchases.restorePurchases() returns fresh CustomerInfo AND fires
    // the update listener, which the notifier is subscribed to — so the
    // Riverpod state updates on its own. No manual refresh required.
    final outcome = await service.restorePurchases();
    if (context.mounted) {
      _showSubscriptionMessage(
        context,
        (s) => switch (outcome) {
          SubscriptionRestoreOutcome.success => s.purchasesRestored,
          SubscriptionRestoreOutcome.notFound => s.noPurchasesFound,
          SubscriptionRestoreOutcome.ownedByAnotherAccount =>
            s.subscriptionOtherAccount,
          SubscriptionRestoreOutcome.unavailable =>
            s.subscriptionsUnavailableNow,
          SubscriptionRestoreOutcome.failed => s.restorePurchasesFailed,
        },
      );
    }
  }

  void _showSubscriptionMessage(
    BuildContext context,
    String Function(AppLocalizations strings) message,
  ) {
    if (!context.mounted) return;
    final text = message(context.l10n);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Future<void> _openCustomerCenter(BuildContext context, WidgetRef ref) async {
    // Any change the user makes inside the Customer Center (cancel, switch
    // plan, etc.) fires the RC update listener, which flips Riverpod state
    // automatically. No manual refresh required.
    await ref.read(subscriptionServiceProvider).presentCustomerCenter();
  }

  Future<void> _manageSubscription(BuildContext context) async {
    const packageName = 'com.shinrinyoku.glimpse';
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions?package=$packageName',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showSubscriptionMessage(context, (s) => s.couldNotOpenGooglePlay);
      }
    } catch (_) {
      if (context.mounted) {
        _showSubscriptionMessage(context, (s) => s.couldNotOpenGooglePlay);
      }
    }
  }
}

/// Premium plan header — brand mark, plan name, status pill and the value
/// pitch, in a single rounded hero.
class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.isPro, required this.showDevOverrideHint});

  final bool isPro;
  final bool showDevOverrideHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;

    final description = isPro
        ? (showDevOverrideHint
              ? strings.proPlanDevDescription
              : strings.proPlanDescription)
        : strings.freePlanDescription;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPro ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(kSettingsGroupRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  AppAssets.launcherIcon,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isPro ? strings.planNamePro : strings.planNameFree,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isPro ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              SettingsBadge(
                label: isPro ? strings.active : strings.free,
                emphasized: isPro,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: isPro
                  ? cs.onPrimaryContainer.withValues(alpha: 0.85)
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// How much of the plan's allowance is spent. Pro only meters AI saves;
/// Ask and search are fair use there.
class _UsagePanel extends StatelessWidget {
  const _UsagePanel({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return SettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UsageMeter(
            feature: UsageFeature.aiSave,
            isPro: isPro,
            label: isPro ? strings.usageAiSavesPro : strings.usageAiSavesFree,
          ),
          if (!isPro) ...[
            const SizedBox(height: 18),
            _UsageMeter(
              feature: UsageFeature.ask,
              isPro: isPro,
              label: strings.usageAsk,
            ),
            const SizedBox(height: 18),
            _UsageMeter(
              feature: UsageFeature.search,
              isPro: isPro,
              label: strings.usageSearch,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageMeter extends ConsumerWidget {
  const _UsageMeter({
    required this.feature,
    required this.isPro,
    required this.label,
  });

  final UsageFeature feature;
  final bool isPro;
  final String Function(int used, int limit) label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final limit = UsageLimits.getLimit(feature, isPro: isPro);
    final remaining = ref.watch(remainingUsageProvider(feature)).valueOrNull;
    final used = remaining == null ? null : (limit - remaining).clamp(0, limit);
    final fraction = used == null || limit == 0 ? 0.0 : used / limit;
    final exhausted = used != null && used >= limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // Until the count arrives, the allowance alone.
          label(used ?? 0, limit),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: used == null ? cs.onSurfaceVariant : cs.onSurface,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: exhausted ? cs.error : cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

/// Monthly or yearly, as Google Play prices them.
class _PlanPicker extends StatelessWidget {
  const _PlanPicker({
    required this.plans,
    required this.selected,
    required this.onSelect,
  });

  final SubscriptionPlans plans;
  final Package? selected;
  final ValueChanged<Package> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final options = [
      if (plans.yearly case final yearly?)
        (
          package: yearly,
          title: strings.planYearly,
          price: strings.pricePerYear(yearly.storeProduct.priceString),
          saving: plans.yearlySavingPercent,
        ),
      if (plans.monthly case final monthly?)
        (
          package: monthly,
          title: strings.planMonthly,
          price: strings.pricePerMonth(monthly.storeProduct.priceString),
          saving: null,
        ),
    ];
    // A lone plan needs no picking; the button carries its price.
    if (options.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, option) in options.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _PlanOption(
            title: option.title,
            price: option.price,
            saving: option.saving == null
                ? null
                : strings.savePercent(option.saving!),
            selected: option.package.identifier == selected?.identifier,
            onTap: () {
              AppHaptics.play(AppHaptics.tick);
              onSelect(option.package);
            },
          ),
        ],
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.price,
    required this.saving,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;
  final String? saving;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(kSettingsGroupRadius);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? cs.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                AppIcon(
                  selected ? AppIcons.radioSelected : AppIcons.radioUnselected,
                  size: 22,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        price,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? cs.onPrimaryContainer.withValues(alpha: 0.85)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (saving != null) ...[
                  const SizedBox(width: 8),
                  SettingsBadge(label: saving!, emphasized: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Free and Pro side by side, with the real allowances.
class _CompareTable extends StatelessWidget {
  const _CompareTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    final freeMonthly = strings.perMonthCount(
      UsageLimits.planAllowance(UsageFeature.ask),
    );
    final freeSearches = strings.perMonthCount(
      UsageLimits.planAllowance(UsageFeature.search),
    );
    final proSaves = strings.perMonthCount(
      UsageLimits.planAllowance(UsageFeature.aiSave, isPro: true),
    );

    Widget header(String text, {bool pro = false}) => Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: pro ? cs.primary : cs.onSurfaceVariant,
      ),
    );

    return SettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompareRow(
            label: const SizedBox.shrink(),
            free: header(strings.free),
            pro: header('Pro', pro: true),
          ),
          const SizedBox(height: 6),
          _CompareRow.values(
            label: strings.unlimitedLinkSaving,
            free: const _Mark(true),
            pro: const _Mark(true),
          ),
          _CompareRow.values(
            label: strings.compareAiSaves,
            free: _Value(strings.compareFreeAiSaves),
            pro: _Value(proSaves, pro: true),
          ),
          _CompareRow.values(
            label: strings.compareAsk,
            free: _Value(freeMonthly),
            pro: _Value(strings.unlimitedFairUse, pro: true),
          ),
          _CompareRow.values(
            label: strings.compareSearch,
            free: _Value(freeSearches),
            pro: _Value(strings.unlimitedFairUse, pro: true),
          ),
          _CompareRow.values(
            label: strings.semanticSearch,
            free: const _Mark(false),
            pro: const _Mark(true),
          ),
          _CompareRow.values(
            label: strings.weeklyRecap,
            free: const _Mark(false),
            pro: const _Mark(true),
          ),
          _CompareRow.values(
            label: strings.multiLinkSynthesis,
            free: const _Mark(false),
            pro: const _Mark(true),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.free,
    required this.pro,
  });

  _CompareRow.values({
    required String label,
    required this.free,
    required this.pro,
  }) : label = _Label(label);

  final Widget label;
  final Widget free;
  final Widget pro;

  static const _columnWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: label),
          SizedBox(
            width: _columnWidth,
            child: Center(child: free),
          ),
          SizedBox(
            width: _columnWidth,
            child: Center(child: pro),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.pro = false});

  final String text;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: pro ? FontWeight.w700 : FontWeight.w500,
        color: pro ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }
}

/// Included or not, for features with no allowance.
class _Mark extends StatelessWidget {
  const _Mark(this.included);

  final bool included;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!included) {
      return Text(
        '—',
        semanticsLabel: '',
        style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
      );
    }
    return AppIcon(AppIcons.check, size: 18, color: cs.primary);
  }
}

/// Terms and privacy, under everything else on the page.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  static final _termsUri = Uri.parse('https://www.getglimpse.xyz/terms');
  static final _privacyUri = Uri.parse('https://www.getglimpse.xyz/privacy');

  static Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: () => _open(_termsUri),
          child: Text(strings.termsOfService),
        ),
        TextButton(
          onPressed: () => _open(_privacyUri),
          child: Text(strings.privacyPolicy),
        ),
      ],
    );
  }
}

/// Pinned bottom action bar so the primary CTA never requires scrolling.
class _CtaFooter extends StatelessWidget {
  const _CtaFooter({
    required this.rcTier,
    required this.price,
    required this.onUpgrade,
    required this.onRestore,
    required this.onManage,
    required this.onManageOnPlay,
  });

  final SubscriptionTier rcTier;

  /// The chosen plan's price, once the store has answered.
  final String? price;
  final VoidCallback onUpgrade;
  final VoidCallback onRestore;
  final VoidCallback onManage;
  final VoidCallback onManageOnPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final strings = context.l10n;
    // Action buttons always follow **RevenueCat** tier, not the dev override.
    final isFree = rcTier == SubscriptionTier.free;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: isFree
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: onUpgrade,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: Text(
                        price == null
                            ? strings.upgradeToGlimpsePro
                            : strings.startProWithPrice(price!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.subscriptionTerms,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: onRestore,
                      child: Text(strings.restorePurchases),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: onManage,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      child: Text(strings.manageSubscription),
                    ),
                    TextButton(
                      onPressed: onManageOnPlay,
                      child: Text(strings.manageOnGooglePlay),
                    ),
                    if (AppEnvironment.isDevContext)
                      Text(
                        'May not work in debug builds',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
