import '../../core/models/saved_url.dart';

class AskLaunchRequest {
  const AskLaunchRequest({
    this.source,
    this.initialPrompt,
    this.autofocus = false,
  });

  final SavedUrl? source;
  final String? initialPrompt;
  final bool autofocus;
}
