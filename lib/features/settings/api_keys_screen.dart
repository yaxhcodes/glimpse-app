import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/service_providers.dart';

class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  final _geminiController = TextEditingController();
  final _voyageController = TextEditingController();
  bool _geminiObscured = true;
  bool _voyageObscured = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final apiKeyService = ref.read(apiKeyServiceProvider);
    final gemini = await apiKeyService.getGeminiKey();
    final voyage = await apiKeyService.getVoyageKey();
    if (!mounted) return;
    setState(() {
      _geminiController.text = gemini ?? '';
      _voyageController.text = voyage ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final apiKeyService = ref.read(apiKeyServiceProvider);
    final gemini = _geminiController.text.trim();
    final voyage = _voyageController.text.trim();

    if (gemini.isEmpty) {
      await apiKeyService.deleteGeminiKey();
    } else {
      await apiKeyService.setGeminiKey(gemini);
    }

    if (voyage.isEmpty) {
      await apiKeyService.deleteVoyageKey();
    } else {
      await apiKeyService.setVoyageKey(voyage);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API keys saved')),
    );
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _voyageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('AI & API Keys')),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── Info banner ────────────────────────────────────
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: theme.colorScheme.onSecondaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Keys are stored in the device keystore and never leave your phone. '
                              'Without keys, Glimpse uses smart domain detection as a fallback.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Gemini ─────────────────────────────────────────
                  Text('Gemini (AI Summaries & Tagging)',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _geminiController,
                    obscureText: _geminiObscured,
                    decoration: InputDecoration(
                      hintText: 'AIza...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_geminiObscured
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _geminiObscured = !_geminiObscured),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get a free key at aistudio.google.com',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  // ─── Voyage AI ──────────────────────────────────────
                  Text('Voyage AI (Semantic Search)',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _voyageController,
                    obscureText: _voyageObscured,
                    decoration: InputDecoration(
                      hintText: 'pa-...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_voyageObscured
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _voyageObscured = !_voyageObscured),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get a free key at dash.voyageai.com',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),

                  // ─── Save button ────────────────────────────────────
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Keys'),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
