import '../../core/models/saved_url.dart';

class AskLaunchRequest {
  const AskLaunchRequest({this.source, this.initialPrompt});

  final SavedUrl? source;
  final String? initialPrompt;
}
