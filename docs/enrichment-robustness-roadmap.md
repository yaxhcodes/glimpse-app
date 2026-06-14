# Enrichment pipeline — robustness roadmap & future work

_Last updated: 2026-06-14. Living doc for deferred work on the URL enrichment pipeline._

## Pipeline at a glance

```
Save → Apify (media + caption) → Groq (audio transcript)
     → [OCR/vision fallback if transcript thin] → Gemini (structure) → persist
```
- **Worker:** `glimpse-enrichment-backend` (separate git repo, branch `master`, **no remote** — local-only + deployed via `wrangler`). Lives at `glimpse-enrichment-backend.glimpse.workers.dev`.
- **Proxy:** `worker/glimpse-proxy` — fronts Gemini + Voyage embeddings. Has **no committed `wrangler.toml`** (only `.example`); it is shared critical infra — **do not redeploy it** without reconstructing config.
- **Cache:** KV `ENRICHMENT_CACHE`, read-through, keyed by normalized URL (`enrich:v1:`). Positive 30d, negative (permanent failures) 2h.

## Plan / cost reality (as of writing)
- **Gemini:** paid (credits purchased).
- **Apify / Groq / Cloudflare:** all free tier. Fine for closed testing (~few hundred saves). The cache/dedup is what stretches these.
- Upgrading any provider later is **config, not code** — flip the plan, limits lift, pipeline unchanged.

## Already shipped (don't redo)
- `await` on all route handlers (fixed unhandled-rejection → Cloudflare 1101 / HTTP 500).
- Instagram URL recognition invariant: `sourceTypeForUrl == 'instagram_reel'` iff `isInstagramReelUrl`; covers `reel/reels/p/tv/share` + `instagr.am` normalization.
- Failure classification: **422 (permanent, no client retry)** vs **424 (transient/`*TIMEOUT*` only)**; client retry ladder trimmed to 2 — bounds paid Apify spend.
- `transcribableMediaUrl()` — never sends the thumbnail image or post page to Groq (was causing `400 invalid_request_error`).
- OCR/vision fallback — when transcript is thin, reads on-screen text from cover + carousel images via a **direct** Gemini vision call (`env.GEMINI_KEY`, bypasses the proxy's 48 KB body cap). Fixes photo carousels (no video at all) and no-speech reels.
- KV read-through cache + dedup + negative cache.
- Presentation: destinations → `places[]` → "Places to visit" pin cards; warm reader-facing summary; warmer labels (`Worth watching/reading`); "Key Takeaways" suppressed when real entities exist.
- **Client `places[]` mapping** (keystone fix) — `_extractMentions` now maps the worker's `places[]` into place mentions.

---

## Deferred — build when the trigger fires

### #3 — Worker-side video download → Groq bytes
**What:** instead of handing Groq the Apify `videoUrl` (Groq fetches it), the worker fetches the bytes itself (browser UA, follow redirects) and uploads them to Groq as a multipart **file** (`form.set('file', blob)` — raw bytes, **not base64**).

**Why:** Instagram CDN sometimes blocks/expires links for Groq's server-side fetcher (`400 invalid_request_error`). A worker fetch with a real UA is far more likely to succeed, and lets us validate "this is really a video" first.

**Trigger to build it (don't build speculatively):** a **reel** that fails with `has_video_url: true` in the `TRANSCRIPT_EXTRACTION_STARTED` log AND a Groq `400`. That proves Groq can't fetch a *valid* video URL. We fixed the main 400 cause (non-video URLs) already, so this case is currently **unconfirmed**.

**Free-tier feasibility:** fine. Download/upload are network waits (don't count against Cloudflare's CPU-time limit). No base64 = low CPU. OCR already base64s images on free tier and works, so this lighter op fits.
- Cap: skip videos > ~20 MB (128 MB isolate memory + Groq ~25 MB file limit) → fall back to today's URL method.

**Effort:** ~30 min. Touch points: `services/transcription.ts` (accept bytes/Blob and send multipart `file`), `services/extraction.ts` (download `reel.video_url` with UA, size-cap, pass Blob).

### #4 — Async queue + success-rate metrics
**What:** move enrichment onto **Cloudflare Queues** — transient failures retry with backoff *off the user's path*; emit an aggregate "% saves reaching `SAVE_COMPLETED`, by failure reason" so success rate is observable before users complain.

**Why:** at scale, transient provider failures (Groq/Apify/Gemini 429/5xx) spike exactly at peak load. Today they fail after 2 retries inline.

**Trigger:** approaching production / when free-tier rate limits start biting, or when you can't answer "what's our save success rate right now?"

**Cost note:** Cloudflare Queues requires the **Workers Paid** plan ($5/mo). Defer until off free tier.

**Effort:** medium. Producer on `/enrich-url`, consumer runs the pipeline, results written back (push notification already exists for "capture ready").

### #5 — Durable Object in-flight dedup (nice-to-have)
**What:** the KV cache dedups saves *over time* but not a burst of the **same** URL saved simultaneously while the cache is cold (all miss at once → N extractions). A Durable Object lock per normalized URL coalesces concurrent cold saves into one.
**Trigger:** evidence of synchronized save storms on the same viral URL. Low priority.

---

## Known open issue — `callGemini` throw → caption dump
**Symptom:** some posts save with the **raw truncated caption** as the summary + generic single-word tags (e.g. `beautiful, himachal, places, social`). Seen on caption-heavy posts.
**Cause:** `callGemini` threw → fell back to `partialLlmFromExtraction()` (caption slice + `fallbackTags`).
**Unconfirmed why it throws** — need a tail showing `gemini_enrichment_failed_returning_partial`. Candidates: Gemini transient error / safety block / empty or non-JSON response / proxy error.
**Fix options (once diagnosed):** retry/backoff on transient Gemini errors before falling back; and **don't cache** low-quality partial results (currently a caption-dump gets cached as "ready" for 30d).

## Cache versioning on prompt changes
Prompt/UI improvements **don't reach already-cached URLs** (server KV 30d + client `transcript_enrichment_v5`). To force a global refresh after a meaningful prompt change, bump the key version (`enrich:v1:` → `v2:`) — but that re-extracts everything = cost. Currently `v1`. Test improvements with a **fresh** URL.

## Invariants / gotchas (read before changing the pipeline)
- **Any new worker enrichment field MUST also be mapped client-side** in `_extractMentions` / `TranscriptEnrichmentResult.fromJson` (`transcript_enrichment_service.dart`), or it's silently invisible. This is what hid `places[]` for ages.
- Keep the Instagram recognition invariant intact (classification ⇔ Apify-eligibility), or you get guaranteed-424 dead ends.
- Free Cloudflare caps **CPU time** (network waits are free). Avoid base64 / heavy byte-crunching on large payloads.
- The proxy's `/internal/gemini` caps bodies at 48 KB → images can't go through it; OCR uses the direct `GEMINI_KEY` on the worker.
- Observability stages to grep in `wrangler tail`: `MEDIA_URL_CLASSIFIED`, `APIFY_CONFIG_CHECKED`, `APIFY_REQUEST_FAILED`, `OCR_FALLBACK_STARTED/COMPLETED` (has `now_valid`), `RECOMMENDATION_COMPLETED` (has `place_count`/`movie_count`/`book_count`), `SAVE_COMPLETED`/`SAVE_FAILED` (has `retryable`, `cache`).
