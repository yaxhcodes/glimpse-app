class SourceReference {
  const SourceReference({required this.label, required this.url});

  final String label;
  final String url;
}

class SourceEvidence {
  const SourceEvidence({
    required this.readableText,
    this.outboundLinks = const [],
  });

  final String readableText;
  final List<SourceReference> outboundLinks;

  bool get isEmpty => readableText.trim().isEmpty && outboundLinks.isEmpty;
}
