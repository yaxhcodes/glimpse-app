import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_haptics.dart';
import '../../l10n/l10n.dart';
import '../../shared/theme/app_icons.dart';
import '../settings/settings_components.dart';
import 'feedback_service.dart';

/// Report a problem or share an idea. Opened by shaking the phone (with a
/// picture of where you were) or from About › Send feedback.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key, this.launch = const FeedbackLaunch()});

  final FeedbackLaunch launch;

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  var _kind = FeedbackKind.bug;
  var _includeScreenshot = true;
  var _sending = false;
  var _showShakeTip = false;

  bool get _hasScreenshot => widget.launch.screenshot != null;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
    if (widget.launch.fromShake) {
      ShakeToReportPrefs.takeFirstShakeTip().then((first) {
        if (mounted && first) setState(() => _showShakeTip = true);
      });
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final strings = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    setState(() => _sending = true);
    try {
      await ref
          .read(feedbackServiceProvider)
          .submit(
            kind: _kind,
            message: _message.text,
            screenName: widget.launch.screenName,
            screenshotPng: _hasScreenshot && _includeScreenshot
                ? widget.launch.screenshot
                : null,
            locale: locale,
          );
      unawaited(AppHaptics.play(AppHaptics.success));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(strings.feedbackSent),
            behavior: SnackBarBehavior.floating,
          ),
        );
      navigator.pop();
    } on FeedbackException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.reason == FeedbackFailure.signedOut
                  ? strings.feedbackSignInNeeded
                  : strings.feedbackFailed,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canSend = !_sending && _message.text.trim().isNotEmpty;
    final withScreenshot = _hasScreenshot && _includeScreenshot;

    return SettingsPageScaffold(
      title: strings.feedbackTitle,
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: canSend ? _send : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(strings.feedbackSend),
          ),
        ),
      ),
      children: [
        if (_showShakeTip) ...[
          SettingsPanel(
            child: Row(
              children: [
                Icon(AppIcons.shakeReport, color: cs.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    strings.feedbackShakeTip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        SegmentedButton<FeedbackKind>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: FeedbackKind.bug,
              icon: const Icon(AppIcons.bug),
              label: Text(strings.feedbackKindBug),
            ),
            ButtonSegment(
              value: FeedbackKind.idea,
              icon: const Icon(AppIcons.idea),
              label: Text(strings.feedbackKindIdea),
            ),
          ],
          selected: {_kind},
          onSelectionChanged: (selection) {
            AppHaptics.play(AppHaptics.tick);
            setState(() => _kind = selection.single);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _message,
          autofocus: !_hasScreenshot,
          minLines: 5,
          maxLines: 10,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: _kind == FeedbackKind.bug
                ? strings.feedbackHintBug
                : strings.feedbackHintIdea,
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kSettingsGroupRadius),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        if (_hasScreenshot) ...[
          const SizedBox(height: 8),
          SettingsPanel(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Opacity(
                    opacity: _includeScreenshot ? 1 : 0.35,
                    child: Image.memory(
                      widget.launch.screenshot!,
                      height: 112,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.feedbackIncludeScreenshot,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.feedbackScreenshotNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _includeScreenshot,
                  thumbIcon: settingsSwitchThumbIcon(),
                  onChanged: (value) =>
                      setState(() => _includeScreenshot = value),
                ),
              ],
            ),
          ),
        ],
        SettingsFootnote(
          withScreenshot
              ? strings.feedbackPrivacyNoteWithScreenshot
              : strings.feedbackPrivacyNote,
        ),
      ],
    );
  }
}
