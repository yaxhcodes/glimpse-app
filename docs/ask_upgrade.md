# Ask upgrade: verification and rollout

The Flutter app and `E:\code\glimpse-proxy` are separate repositories. No deployment is performed by this change.

## Release order

1. Run the proxy typecheck and security tests, including the Ask route tests.
2. Deploy the proxy with `/ask/plan` and `/ask/stream` before distributing the app.
3. Verify a real authenticated stream on an internal Android build, including Stop, interrupted connectivity, a resumed focused conversation, and a long comparison.
4. Verify the curated questions against representative saved libraries before production rollout. Host tests are not evidence of live model quality or Android latency.

Older gateways return 404/405 for streaming. The app then uses one buffered answer request. Planning failure falls back to local retrieval. There is no automatic answer regeneration after text becomes visible. The existing model selection is retained.

## Behavior and budgets

- Non-Bin saves, including completed items, define the library. Supported exact counts and full-link browsing are local and do not read quota or connectivity providers.
- Books, movies/shows, places, and songs use the existing deduplicating library index; these counts describe extracted items, not saved links. Missing extraction is not evidence that an item never appeared in a source.
- Hybrid retrieval combines the existing lexical/semantic ranking with indexed passages from reader content, notes, highlights, and collections. Each retrieval channel is capped at 40 candidates; answers use at most 12 sources.
- Inputs use a conservative local 12,000-token estimate and a separate character ceiling. This is not an exact provider tokenizer. Evidence is clipped per source, preserving every supplied source's identity and partial-media notice.
- A turn normally makes one answer call. Ambiguous/complex questions may make one planning call; semantic retrieval may make one embedding call. Attached-context follow-ups skip embeddings. Product quota is committed only for completed generated answers, with a stable logical-turn quota key. Gateway abuse limits still apply to paid requests.
- Citation targets come from supplied evidence only. Suggested follow-ups carry validated source references and are deduplicated against prior questions. Source validation is not a factual verification of the generated prose.
- History is local, versioned, and included in backup format 7. URL references reconnect to restored saves. Older backup versions remain supported. Clear-all-data flushes pending history writes before clearing the database.

## Automated checks

- `ask_library_context_test.dart`: exact 437-save counts, filters, source removal, passage refresh, chunk decoding, source references, query-plan validation, input clipping, curated candidate recall, and diagnostic 400/5,000-save host benchmarks.
- `ask_conversation_store_test.dart`: persistence, backup import, unsupported versions, local-only Ask execution, and deletion.
- `ask_answer_text_test.dart`: small-screen large-text tables, citation activation, and inert partial citations.
- `ask_stream_transport_test.dart`: split UTF-8 SSE, authorization, stable request identity, and no implicit stream retry.
- Existing Ask retrieval, response-quality, itinerary, reader, backup, and transport tests remain regression gates.

## Live release gates

Use `test/fixtures/ask_quality_cases.json` as a baseline and add questions based on real representative libraries. Check direct answers, evidence support, contradictory saves, contextual follow-ups, and practical plans. Require at least 90% expected-source candidate recall and no invalid citation targets. Measure warm local counts on a representative Android device against the 300 ms target; host VM numbers do not establish that target. Inspect first-text latency and request counts without logging prompts or saved text.
