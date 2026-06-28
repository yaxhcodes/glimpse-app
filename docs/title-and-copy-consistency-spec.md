# Glimpse — Title & Copy Consistency Spec
> Notification ↔ Detail parity for save titles and supporting copy
> Version 1.0 — Source of truth for implementation
> Companion to the Engagement Engine Specification (Rediscover + Notifications)

---

## 1. Why this exists

The same saved item renders with **different titles** depending on where you see it:

| Surface | Shows | Method |
|---|---|---|
| Detail screen (correct) | **"Marcus Aurelius · Stoic Wisdom Quotes"** | `TitleResolver.resolveDetailTitle()` |
| Notification list row | "Stoicism · Self-improvement" | `formatForCompactCard(resolve(...))` |

These are the *same save*. The detail title is the one we want everywhere. A second, related defect lives in the supporting copy: a notification footer reads **"Mostly Instagram and Lifestyle"** — mixing a *platform* (Instagram) with a *category* (Lifestyle) in a line that should only ever name domains.

This spec defines one canonical title and one copy rule so every surface agrees.

---

## 2. Root cause

`TitleResolver` exposes several resolution paths that disagree about whether to trust the AI-generated `meaningful_title`:

- **`resolveDetailTitle(link)`** ([title_resolver.dart:78](../lib/core/services/title_resolver.dart#L78)) — reads `meaningful_title` from `enrichmentJson` **first**, falls back to `resolve()` only if it's missing/low-signal. Collapses whitespace, truncates at 92 chars. **No subtitle dropping.** → produces *"Marcus Aurelius · Stoic Wisdom Quotes"*.
- **`resolve(link)`** ([title_resolver.dart:36](../lib/core/services/title_resolver.dart#L36)) — **never looks at `meaningful_title`**. For a creator-handle / low-signal raw title it jumps straight to the **top-2 tags** (`_titleFromTags`) → *"Stoicism · Self-improvement"*.
- **`resolveStableDisplayTitle(link)`** ([title_resolver.dart:66](../lib/core/services/title_resolver.dart#L66)) — enrichment-first like detail, **but** then runs `formatForCompactCard` → truncates to 60 and **drops trailing subtitles** via `dropTrailingSubtitle`.
- **`formatForCompactCard(...)`** ([title_resolver.dart:367](../lib/core/services/title_resolver.dart#L367)) — applies `dropTrailingSubtitle` + tweet-sentence trim + 60-char truncate.

So three things diverge between surfaces: **(a) source** (enrichment `meaningful_title` vs tags), **(b) length cap** (92 vs 60), **(c) subtitle dropping** (off vs on). The notification list loses on all three.

---

## 3. Decisions (locked)

| # | Decision | Choice |
|---|---|---|
| D1 | Title parity strictness | **Pixel-identical everywhere.** Every surface resolves the exact same string. No per-surface truncation/subtitle differences in the *string*. Narrow layouts ellipsize at render time only. |
| D2 | "Mostly … / blend of …" meta line | **Domains only.** Never name a platform/source in this line. |
| D3 | Doc scope | Full copy & parity spec: titles + meta line + every notification/detail surface. |
| D4 | Push headline named entity ("Marcus Aurelius is still waiting") | **Keep current behavior.** Documented in §7, not changed now. |

---

## 4. Title parity rule (D1)

### 4.1 Canonical resolver

There is exactly **one** user-facing title method: the enrichment-first, full-length, no-subtitle-drop resolution currently implemented as **`resolveDetailTitle()`**.

> **Rule:** Any surface that displays a save's title to the user MUST call `resolveDetailTitle(link, tagFrequency: …)` and render the returned string verbatim. It MUST NOT pre-truncate, drop the subtitle, or substitute tag-derived titles.

- `resolveStableDisplayTitle` and `formatForCompactCard` are **deprecated for display.** Keep them only if an internal, non-user-facing consumer needs the compact form; otherwise remove.
- Narrow cards constrain with `maxLines` + `TextOverflow.ellipsis` at the widget level. The *string* stays identical; only the rendered ellipsis differs. That satisfies "pixel-identical string" while respecting layout.

### 4.2 Call-site migration

Display-title surfaces — must route through the canonical resolver:

| File:line | Current | Action |
|---|---|---|
| [url_detail_screen.dart:1732](../lib/features/url_detail/url_detail_screen.dart#L1732) | `resolveDetailTitle` | ✅ reference — no change |
| [url_card.dart:203](../lib/shared/widgets/url_card.dart#L203) | `resolveDetailTitle` | ✅ already canonical |
| [mindmap_screen.dart:539](../lib/features/mindmap/mindmap_screen.dart#L539) | `resolveDetailTitle` | ✅ already canonical |
| [interest_cluster_service.dart:598,639](../lib/features/mindmap/interest_cluster_service.dart#L598) | `resolveDetailTitle` | ✅ already canonical |
| [url_save_notifications.dart:131](../lib/core/services/url_save_notifications.dart#L131) | `resolveDetailTitle` | ✅ already canonical |
| **[notification_detail_screen.dart:115‑118](../lib/features/digest/notification_detail_screen.dart#L115)** | `formatForCompactCard(resolve(...))` | ❌ **→ `resolveDetailTitle`** (the screenshot bug) |
| **[digest_screen.dart:148‑151](../lib/features/digest/digest_screen.dart#L148)** | `formatForCompactCard(resolve(...))` | ❌ → `resolveDetailTitle` |
| **[ask_screen.dart:1529](../lib/features/ask/ask_screen.dart#L1529)** | `resolveStableDisplayTitle` | ❌ → `resolveDetailTitle` (drops subtitle today) |
| **[swipeable_url_card.dart:328](../lib/shared/widgets/swipeable_url_card.dart#L328)** | `resolve` | ❌ → `resolveDetailTitle` |
| **[synthesis_screen.dart:75](../lib/features/synthesis/synthesis_screen.dart#L75)** | `resolve` | ❌ → `resolveDetailTitle` |
| **[add_url_screen.dart:465](../lib/features/add_url/add_url_screen.dart#L465)** | `resolve` | ❌ → `resolveDetailTitle` |
| **[add_to_collection_sheet.dart:46](../lib/features/collections/add_to_collection_sheet.dart#L46)** | `resolve` | ❌ → `resolveDetailTitle` |
| **[rediscover_screen.dart:399,779](../lib/features/rediscover/rediscover_screen.dart#L399)** | `resolve` | ❌ → `resolveDetailTitle` |
| **[rediscover_journey_detail_screen.dart:507](../lib/features/rediscover/rediscover_journey_detail_screen.dart#L507)** | `resolve` | ❌ → `resolveDetailTitle` |

Copy-generation / push surfaces — these emit **user-facing** strings and must also use the canonical title where they embed a specific save's title:

| File:line | Current | Action |
|---|---|---|
| [notification_templates.dart:251,278](../lib/core/services/notification_templates.dart#L251) | `resolve` | ❌ → `resolveDetailTitle` |
| [notification_scheduler.dart:420](../lib/core/services/notification_scheduler.dart#L420) | `resolve` | ❌ → `resolveDetailTitle` |

LLM-prompt input — model rephrases anyway; align for consistency but lower priority:

| File:line | Current | Action |
|---|---|---|
| [gemini_copywriter.dart:211,229,267,387,431](../lib/notifications/gemini_copywriter.dart#L211) | `resolve` | ⚠️ prefer `resolveDetailTitle` so the model sees the same title the user will |

Internal (not a displayed save title) — leave unless it surfaces:

| File:line | Note |
|---|---|
| [interest_cluster_service.dart:329](../lib/features/mindmap/interest_cluster_service.dart#L329) | cluster naming, `tagFrequency: null` — verify it isn't shown as a save title |

### 4.3 Tests

[title_resolver_test.dart](../test/title_resolver_test.dart) currently asserts `resolve()` behavior. Add a parity test: for a save with a `meaningful_title`, assert that **every** display surface helper returns byte-identical output, and that the value equals `resolveDetailTitle`. Update existing `resolve`-based expectations that were really standing in for display titles.

---

## 5. Meta / insight line — domains only (D2)

### 5.1 Rule

The supporting one-liner under a notification ("Mostly X and Y", "Reads like a blend of X and Y", "Mostly about X") names **domains/categories only**. It MUST NOT contain a platform/source name (Instagram, YouTube, TikTok, X, Reddit, …).

### 5.2 The platform-leak bug

`_bundleHintLine` ([notifications_screen.dart:302](../lib/features/digest/notifications_screen.dart#L302)) and `_syntheticInsight` ([notification_detail_screen.dart:84](../lib/features/digest/notification_detail_screen.dart#L84)) both count `u.effectiveCategories`. Because the **platform is present in `effectiveCategories`**, the count-sort picks "Instagram" (present on every save) as the top "category" → *"Mostly Instagram and Lifestyle."*

> **Fix:** Before counting, filter `effectiveCategories` to exclude any value that is a known source/platform name (compare against `CategoryResolver.displaySourceName` / the platform set). Count only true domains. Apply in **both** `_bundleHintLine` and `_syntheticInsight`.

### 5.3 Redundancy guard

The headline is often already domain-anchored ("…philosophy pieces…"). Avoid a meta line that just repeats it ("Mostly philosophy and …"). When the top domain equals the headline's domain, lead with the **secondary** domain(s), or fall back to "Mostly about \<domain\>" only when there's a single real domain.

### 5.4 Push body source

The push body that rendered "Mostly Instagram and Lifestyle" is LLM-authored (Gemini copywriter, see `_reasonForType`/templates). Constrain the prompt so the supporting line references the user's **domains**, never the platform, and add a post-generation guard that strips/【rejects】any platform token from that line. (The deterministic in-app lines in §5.2 are the safety net the push copy should mirror.)

---

## 6. Surface-by-surface copy contract

| Surface | Title | Supporting line | Notes |
|---|---|---|---|
| **Push notification** | Entity headline (see §7) | Domain-only (§5.4) | Body = "[N] [domain] pieces aren't going to read themselves." Source line, if any, domains only. |
| **Notifications hub list** ([notifications_screen.dart](../lib/features/digest/notifications_screen.dart)) | n/a (topic/headline) | `_bundleHintLine`, domains only (§5.2) | |
| **Notification detail** ([notification_detail_screen.dart](../lib/features/digest/notification_detail_screen.dart)) | Per-row `resolveDetailTitle` (§4) | `_syntheticInsight`, domains only (§5.2) | This is the screenshot screen — both bugs live here. |
| **Detail screen** ([url_detail_screen.dart](../lib/features/url_detail/url_detail_screen.dart)) | `resolveDetailTitle` (reference) | category line + topics | Canonical source of truth for the title string. |
| **Home / Rediscover / Digest / Ask / Mindmap cards** | `resolveDetailTitle` (§4.2) | per-surface | Must match detail byte-for-byte. |

---

## 7. Push headline entity (D4 — keep current, documented)

The push headline asserts a named entity: *"Marcus Aurelius is still waiting on you."* Current behavior is **retained as-is** for now. Known risk (not fixed in this version): the entity is chosen by the copy generator and is **not** verified to be present in the saves the deep link surfaces, so the headline can name something the destination slot doesn't contain. Track as an open item; revisit alongside the Engagement Engine notification-trigger ↔ slot binding work.

---

## 8. Open questions

- **Taxonomy for the meta line** — ✅ **Decided: display categories.** The "domains only" line uses `effectiveCategories` (the app's display categories like "Spirituality & Philosophy") minus platform names, via `CategoryResolver.isPlatformName`. The Engagement Engine's 15-value `Domain` enum is *not* used here.
- **Deprecate vs keep** `resolveStableDisplayTitle` / `formatForCompactCard` — after this change both have **no remaining display callers** (`resolveStableDisplayTitle` is unused; `formatForCompactCard` is only called internally by it). Left in place for now; safe to delete in a follow-up.
- **92-char cap** — confirm 92 is the right universal cap now that compact cards inherit it (they rely on `maxLines` to clip visually).

---

## 9. Implementation checklist

- [x] Route every display-title call-site in §4.2 through `resolveDetailTitle`.
- [x] Fix the screenshot screen: [notification_detail_screen.dart](../lib/features/digest/notification_detail_screen.dart).
- [x] Narrow cards already use `maxLines` + ellipsis (no per-surface string truncation).
- [x] Filter platform names out of category counting in `_bundleHintLine` and `_syntheticInsight` via `CategoryResolver.isPlatformName` (§5.2).
- [x] Constrain push-copy prompt: added a "never name a platform/app" rule to the Gemini `_systemInstruction` (no extra API calls — copy is gated + 24h cached).
- [x] Add a title-parity test; existing `resolve`-based expectations kept (they test the resolver, not surfaces) (§4.3).
- [ ] Redundancy guard (§5.3) — secondary-domain-first when top domain repeats the headline. Not yet done.
- [ ] Optional belt-and-suspenders: deterministic platform-token guard on parsed Gemini copy (prompt rule covers it for now).
- [ ] Deprecate/remove `resolveStableDisplayTitle` / `formatForCompactCard` for display use (now unused).

---

## 10. Rediscover journey coherence (on-device, no Gemini)

The Rediscover journey detail screen surfaced three signals computed independently, so they could disagree (observed: a **Software** eyebrow + **"Worth returning to Self-improvement"** title over a **film-analysis** save):

- **Title** ← `_topicJourneyTitle(_dominantTopic(urls))` — global dominant tag across *all* saves.
- **Eyebrow/motif** ← keyword match over `journey.title` + items ([journey_visual.dart](../lib/features/rediscover/journey_visual.dart)).
- **Items** ← `interestShelfProvider` — a separate set.

**Fix applied:** for the `becauseYouSaved` journey, the title topic is now derived from the journey's **own items** (`_dominantTopic(interestItems.map((i) => i.url))`), so title, eyebrow, and items all reference the same content. ([rediscover_journey_provider.dart](../lib/features/rediscover/rediscover_journey_provider.dart))

**Removed:** the "Why this belongs together" explanation block (`_JourneyExplanation`) per product call — it restated the grouping rationale and added little. ([rediscover_journey_detail_screen.dart](../lib/features/rediscover/rediscover_journey_detail_screen.dart))

**Still open (deeper, deferred):** the *items themselves* can be a mixed grab-bag (the interest shelf blends topics). Tightening which saves cluster into a journey is a clustering-quality problem, not a copy problem — tracked separately so it doesn't expand this change.

---

*Last updated: based on UI review with Yash (notification list vs detail screenshots). Detail-screen title is the reference. Any deviation should be noted and fed back for spec update.*
