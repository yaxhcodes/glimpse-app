# Glimpse Change Report After Last Commit

Date: 2026-06-04

This report captures the worktree state before rollback. It is intentionally detailed so the reverted work can be reviewed and rebuilt later in a more stable sequence.

## Baseline

### Flutter app repository

- Repository: `E:\code\glimpse`
- Last committed baseline observed: `70202c0`
- Tracked diff before rollback: 32 files changed
- Tracked diff size before rollback: 4112 insertions, 1095 deletions
- Untracked additions before rollback: docs, Rediscover services/screens/providers, recall services, Today's Pick services/cards

### Enrichment backend repository

- Repository: `E:\code\glimpse\glimpse-enrichment-backend`
- Last committed baseline observed: `19c28ff`
- Tracked diff before rollback: 8 files changed
- Tracked diff size before rollback: 1120 insertions, 83 deletions

## Executive Summary

The post-commit work focused on making Glimpse more intelligent and action-oriented:

- Rediscover was redesigned from topic browsing into recommendation/action packs.
- Home was changed to show Rediscover awareness instead of a large Today's Pick card.
- Notifications were connected conceptually to Rediscover through shared recall candidates.
- Ask Glimpse was extended toward URL-contextual chat actions.
- URL enrichment was heavily changed to support actor-based Instagram, TikTok, and YouTube enrichment.
- The backend worker gained TikTok/Instagram/YouTube extraction and Apify actor support.
- Saved URL models and backups were expanded to hold recommendation/enrichment memory.

The work also introduced instability:

- Recommendations appeared inconsistently across saves.
- Some old and new UI states appeared side by side.
- Cover images and titles could change after reopening a URL.
- Actor enrichment could run repeatedly for the same saved URL.
- TikTok enrichment remained weaker than Instagram and could become expensive without enough output quality.
- Some rich enrichment data appeared transient instead of being durably stored in the app database.

## Flutter App Changes

### 1. Rediscover Redesign

Intent:

- Move Rediscover away from category/topic browsing.
- Make Rediscover answer: "What should I do with my saved knowledge today?"
- Keep Home focused on saved content, browsing, collections, and organization.
- Remove the large Home Today's Pick card.
- Keep Rediscover as the destination for recommendations.

Files touched:

- `lib/features/home/home_screen.dart`
- `lib/features/home/rediscovery_section.dart`
- `lib/features/home/rediscovery_provider.dart`
- `lib/features/rediscover/rediscover_screen.dart`
- `lib/features/rediscover/rediscover_provider.dart`
- `lib/features/rediscover/pack_screen.dart`
- `lib/features/rediscover/rediscover_pack_provider.dart`
- `lib/features/rediscover/rediscover_reason.dart`
- `lib/features/rediscover/todays_pick_card.dart`
- `lib/features/rediscover/todays_pick_provider.dart`
- `lib/core/services/rediscover_pack_service.dart`
- `lib/core/services/todays_pick_service.dart`
- `lib/core/services/recall_candidate.dart`

Specific work:

- Reworked Home Rediscover UI so it used a smaller Rediscover indicator instead of a dominant Today's Pick preview.
- Removed or deleted the old Home rediscovery provider file.
- Added new Rediscover pack concepts:
  - Never opened packs
  - Forgotten gem packs
  - Continue/project-style packs
  - Seasonal-ish packs
  - Completion/unread-style packs
- Added a `RediscoverPack` style service layer that attempted to group saved URLs into goal-oriented packs.
- Added pack screen/provider files to render grouped recommendations.
- Added reason/explanation helpers for Rediscover recommendations.
- Added Today's Pick provider/card/service work to support a daily pick model inside Rediscover.
- Attempted to fail closed when pack confidence was weak and fall back to single-item recommendations.

Known problems:

- The user only wanted the large Today's Pick card removed from Home, but at one point Rediscover cards were also removed or hidden.
- Rediscover became inconsistent because multiple recommendation concepts existed at once:
  - old topics/categories
  - action packs
  - today's pick
  - home indicator
  - single-item recall
- Pack generation risked inventing narratives around weakly related links.
- Pack confidence and semantic cohesion rules were started conceptually, but the app was not yet stable enough to trust them.

### 2. Recommendation Memory And Recall Signals

Intent:

- Stop recommending the same links repeatedly.
- Share intelligence between notifications and Rediscover.
- Track recommendation history and user feedback.
- Weight current intent signals more strongly than passive saves.

Files touched:

- `lib/core/models/saved_url.dart`
- `lib/core/models/saved_url.g.dart`
- `lib/core/services/recall_candidate.dart`
- `lib/core/services/rediscovery_service.dart`
- `lib/core/services/link_scorer.dart`
- `lib/core/services/user_fingerprint.dart`
- `lib/core/services/contextual_resurface_service.dart`
- `lib/core/database/isar_service.dart`
- `lib/core/services/backup/backup_models.dart`
- `lib/core/services/backup/backup_service.dart`

Specific work:

- Added recommendation-memory fields to saved URL data.
- Regenerated Isar model code with many new persisted properties/indexes.
- Added backup import/export support for the new fields.
- Added a recall candidate model intended to be shared by Rediscover and notifications.
- Added contextual resurfacing service experiments.
- Updated scoring services to account for richer signals.
- Started modeling signals such as:
  - last recommended time
  - opened from recommendation time
  - recommendation count
  - dismiss count
  - snooze count
  - notification shown/opened state
  - rediscovery shown/opened state

Known problems:

- The schema changed before the product behavior was stable.
- Several recommendation fields were added broadly, increasing rollback/rebuild complexity.
- Some rich enrichment outputs still did not appear to persist cleanly despite model expansion.

### 3. Notifications And Digest Integration

Intent:

- Make notifications and Rediscover draw from the same recall intelligence.
- Improve notification copy and scheduling around recall-worthy saved links.
- Avoid disconnected recommendation logic between notification and Rediscover surfaces.

Files touched:

- `lib/core/services/digest_notifications.dart`
- `lib/core/services/digest_prefs.dart`
- `lib/core/services/notification_router.dart`
- `lib/core/services/notification_scheduler.dart`
- `lib/core/services/notification_templates.dart`
- `lib/features/digest/notification_detail_screen.dart`
- `lib/notifications/gemini_copywriter.dart`

Specific work:

- Adjusted digest notification preferences.
- Changed notification scheduling logic.
- Updated templates and routing for recommendation/recall style notifications.
- Reworked notification detail UI/logic.
- Updated Gemini copywriter behavior for notifications.

Known problems:

- Notification and Rediscover work was being changed at the same time as enrichment and data model work, making failures harder to isolate.
- Shared intelligence was not yet proven stable.

### 4. Ask Glimpse URL Context Work

Intent:

- Make the "Ask Glimpse" swipe action useful by passing the saved URL as context.
- Let Ask Glimpse understand what URL it was opened from.
- Allow answers to be saved back onto the saved URL so users do not need to ask the same thing repeatedly.

Files touched:

- `lib/features/ask/ask_provider.dart`
- `lib/features/ask/ask_screen.dart`
- `lib/shared/widgets/swipeable_url_card.dart`
- `lib/features/url_detail/url_detail_screen.dart`

Specific work:

- Updated Ask Glimpse provider/screen toward contextual URL-aware behavior.
- Connected swipe card action behavior to Ask Glimpse.
- Explored saving AI answers back into saved URL context/notes.

Known problems:

- Ask Glimpse AI temporarily failed when the proxy had App Check config issues.
- The URL-context feature was not fully verified end to end.
- The app currently lacks durable chat history, so storing useful answers on saved URLs needs careful schema and UX design.

### 5. Add URL And Enrichment Flow

Intent:

- Improve enrichment quality for social/video URLs.
- Prefer platform-specific actor enrichment for Instagram/TikTok/YouTube when useful.
- Use Gemini as fallback rather than as the first choice for platform URLs.
- Avoid repeated backend calls for already enriched URLs.

Files touched:

- `lib/core/services/enrichment_service.dart`
- `lib/core/services/transcript_enrichment_service.dart`
- `lib/core/services/gemini_service.dart`
- `lib/core/services/link_preview_service.dart`
- `lib/features/add_url/add_url_provider.dart`
- `lib/features/add_url/add_url_screen.dart`
- `lib/features/url_detail/url_detail_screen.dart`
- `lib/core/database/isar_service.dart`

Specific work:

- Added actor-preferred enrichment path for Instagram, TikTok, and YouTube-like URLs.
- Added debug logging around actor enrichment request/result behavior.
- Added source-specific logic to avoid generic Gemini fallback when actor results were present.
- Added fallback behavior when actor results were weak.
- Added canonical URL handling for social links:
  - Instagram reel/post URL cleanup
  - TikTok video URL cleanup
  - YouTube Shorts/watch URL cleanup
- Added stable-enrichment checks to avoid re-enriching URLs that already had strong saved title/summary/category/tags.
- Added cached transcript/enrichment result checks in URL detail before calling backend.
- Updated add URL flow around AI save/enrichment behavior.

Known problems:

- Actor URLs could bypass the normal "already enriched" guard and call the backend again on detail open.
- Reopening a saved URL could call Apify again, changing title/cover/summary.
- Duplicate detection likely relied too much on exact raw URL, so query parameters or share variants could create repeat saves.
- Actor result richness was partly stored in transient cache, while the durable `SavedUrl` model did not fully capture everything needed.
- Cover image URLs from actor providers could be temporary/per-run, making covers appear to change.

### 6. Instagram Enrichment

Intent:

- Get Instagram-like results with:
  - meaningful title
  - summary
  - caption
  - creator
  - thumbnail
  - transcript when available
  - likes/comments pills
  - useful tags and category

Specific work:

- Switched Instagram toward actor-first enrichment.
- Preserved Gemini fallback for weak actor results.
- Added parsing/display paths for creator, caption, stats, thumbnail, and transcript metadata.
- Fixed missing `debugPrint` import issue in `enrichment_service.dart`.
- Adjusted app display so likes/comments/creator pills could appear in Details.

Known problems:

- Likes/comments pills were hit or miss.
- Some saves had good Instagram enrichment while others fell back to sparse metadata.
- The same Instagram URL could re-enrich and change stored/displayed content.

### 7. TikTok Enrichment

Intent:

- Make TikTok enrichment competitive with Instagram for target markets:
  - USA
  - UK
  - Australia
  - Germany
  - Canada
- Support TikTok titles, summaries, tags, creator, stats, cover images, transcript or audio-derived understanding.

Specific work:

- Added TikTok actor support in the app and backend.
- Added TikTok metadata parsing:
  - author username
  - author avatar
  - caption/text
  - digg/like count
  - comment count
  - share/play/collect counts
  - video duration
  - web URL
- Added optional TikTok transcript actor exploration.
- Added optional TikTok audio transcription mode.
- Discussed and tested `clockworks/tiktok-transcript-extractor` as a possible cheaper/more focused actor.
- Added logging to show TikTok actor result keys and whether transcript/recipe data existed.

Known problems:

- TikTok is banned in India, which can affect direct device behavior, but the Cloudflare Worker/Apify flow can still work from external infrastructure.
- The TikTok scraper often returned metadata but not subtitles/audio transcript.
- Recipe TikToks without subtitles could not be understood well from metadata alone.
- Optional transcription add-on increased cost while still not guaranteeing good extraction.
- Cover image was still missing or unstable in some app results despite actor JSON containing media fields.
- TikTok results remained weaker than Instagram and likely need either:
  - reliable transcript source
  - video/audio download plus transcription
  - OCR/vision pass
  - a product decision to keep TikTok metadata-only unless user requests deep scan

### 8. YouTube And Shorts Enrichment

Intent:

- Extend actor/platform enrichment approach beyond Instagram to YouTube Shorts and YouTube URLs.
- Normalize YouTube links to reduce duplicate saves and repeated enrichment.

Specific work:

- Added app-side URL classification/canonicalization paths for YouTube Shorts/watch URLs.
- Backend work included YouTube evidence extraction hooks.
- Intended to support transcript/caption-driven enrichment where available.

Known problems:

- This path was less tested than Instagram.
- The app still needed a consistent persistence strategy before more platform support could be trusted.

### 9. URL Detail Screen

Intent:

- Show enriched social URL details consistently.
- Display platform metadata pills.
- Avoid re-fetching enrichment each time the details page opens.

Files touched:

- `lib/features/url_detail/url_detail_screen.dart`

Specific work:

- Added rendering paths for actor-enriched metadata.
- Added stats pill handling for likes/comments.
- Added creator/caption/url display behavior.
- Added cached enrichment lookup before backend calls.
- Added stable actor-field checks.

Known problems:

- Details view could still trigger enrichment repeatedly.
- Some metadata appeared only after fresh actor calls.
- Old saved records could show sparse data while new records showed richer data.
- Because work was in flight, opening the same URL could produce different visible content over time.

### 10. UI And Navigation Touches

Files touched:

- `lib/app.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/home/rediscovery_section.dart`
- `lib/features/collections/collection_detail_screen.dart`
- `lib/shared/widgets/swipeable_url_card.dart`

Specific work:

- Added/adjusted routes for Rediscover packs and Today's Pick flows.
- Updated collection detail and swipe card behavior.
- Adjusted Home Rediscover placement/indicator.

Known problems:

- Mixed old/new icon states were observed by the user.
- Some UI components were partially updated while their related providers/services were also changing.

## Backend Worker Changes

Repository: `E:\code\glimpse\glimpse-enrichment-backend`

### Files touched

- `.dev.vars.example`
- `src/index.ts`
- `src/services/apify.ts`
- `src/services/extraction.ts`
- `src/services/shared.ts`
- `src/types.ts`
- `wrangler.toml`
- `wrangler.toml.example`

### 1. Actor-Based Platform Enrichment

Intent:

- Support richer social/video URL enrichment through platform-specific actors.
- Use actor output before Gemini where actor output is more grounded.
- Avoid generic Gemini guesses when real platform metadata/transcript exists.

Specific work:

- Added or expanded Apify actor integration.
- Added Instagram actor result handling.
- Added TikTok actor result handling.
- Added YouTube evidence/extraction pathways.
- Merged actor data into `/enrich-url` responses.
- Returned fields such as:
  - `meaningful_title`
  - `summary`
  - `tags`
  - `category`
  - `source_type`
  - `confidence`
  - `creator`
  - `caption`
  - `thumbnail_url`
  - `duration_seconds`
  - `like_count`
  - `comment_count`
  - `transcript`

### 2. TikTok Backend Work

Intent:

- Make TikTok saves useful for Western target markets where TikTok is important.
- Improve beyond metadata-only results when possible.

Specific work:

- Added TikTok Apify actor configuration.
- Added `TIKTOK_APIFY_ACTOR_ID` secret/config support.
- Added optional transcript actor config exploration:
  - `TIKTOK_TRANSCRIPT_APIFY_ACTOR_ID`
  - `TIKTOK_TRANSCRIPT_MODE`
- Added TikTok result parsing for:
  - creator
  - caption/text
  - stats
  - duration
  - thumbnail/media fields
- Added optional audio transcription path.

Known problems:

- The TikTok scraper often did not return transcript/subtitle data.
- Transcription mode cost more and still did not guarantee recipe/book extraction quality.
- Rich understanding of TikTok likely needs a deeper media pipeline, not only metadata.

### 3. Instagram Backend Work

Intent:

- Restore the richer Instagram behavior that previously produced good recipes, books, movies, and place recommendations.
- Avoid Gemini dominating when actor/extract data was better grounded.

Specific work:

- Repaired proxy/Gemini routing issues.
- Adjusted backend behavior after Gemini/App Check config fixes.
- Changed actor/enrichment priority so Instagram actor extraction could lead.
- Added richer result fields for app display.

Known problems:

- The backend could return rich data, but the app did not consistently persist or display every field.
- Some actor runs returned metadata-only or partial output.

### 4. Worker Config And Deployment

Specific work:

- Updated `wrangler.toml` and examples with actor/transcript config.
- Added or changed env typings in `src/types.ts`.
- Deployed backend during testing.
- One observed deployed backend version before rollback request:
  - `83b2a0c3-770a-444c-9e2c-81b844704e9f`

Known problems:

- Worker code was moving quickly alongside app code.
- Some deployed backend behavior may remain active even after local rollback unless separately redeployed from a clean backend commit.

## Documentation Added

Untracked docs before rollback:

- `docs/rediscover_audit_report.md`
- `docs/rediscover_feature_report.md`

Purpose:

- Capture Rediscover design/audit findings.
- Document the intended action-oriented Rediscover architecture.

These docs were also part of the uncommitted working set and were removed by rollback unless recovered from this report or external attachments.

## Full Tracked File Inventory Before Rollback

### Flutter app tracked modifications

- `lib/app.dart`
- `lib/core/database/isar_service.dart`
- `lib/core/models/saved_url.dart`
- `lib/core/models/saved_url.g.dart`
- `lib/core/services/backup/backup_models.dart`
- `lib/core/services/backup/backup_service.dart`
- `lib/core/services/digest_notifications.dart`
- `lib/core/services/digest_prefs.dart`
- `lib/core/services/enrichment_service.dart`
- `lib/core/services/gemini_service.dart`
- `lib/core/services/link_preview_service.dart`
- `lib/core/services/link_scorer.dart`
- `lib/core/services/notification_router.dart`
- `lib/core/services/notification_scheduler.dart`
- `lib/core/services/notification_templates.dart`
- `lib/core/services/rediscovery_service.dart`
- `lib/core/services/transcript_enrichment_service.dart`
- `lib/core/services/user_fingerprint.dart`
- `lib/features/add_url/add_url_provider.dart`
- `lib/features/add_url/add_url_screen.dart`
- `lib/features/ask/ask_provider.dart`
- `lib/features/ask/ask_screen.dart`
- `lib/features/collections/collection_detail_screen.dart`
- `lib/features/digest/notification_detail_screen.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/home/rediscovery_provider.dart`
- `lib/features/home/rediscovery_section.dart`
- `lib/features/rediscover/rediscover_provider.dart`
- `lib/features/rediscover/rediscover_screen.dart`
- `lib/features/url_detail/url_detail_screen.dart`
- `lib/notifications/gemini_copywriter.dart`
- `lib/shared/widgets/swipeable_url_card.dart`

### Flutter app untracked additions

- `docs/rediscover_audit_report.md`
- `docs/rediscover_feature_report.md`
- `lib/core/services/contextual_resurface_service.dart`
- `lib/core/services/recall_candidate.dart`
- `lib/core/services/rediscover_pack_service.dart`
- `lib/core/services/todays_pick_service.dart`
- `lib/features/rediscover/pack_screen.dart`
- `lib/features/rediscover/rediscover_pack_provider.dart`
- `lib/features/rediscover/rediscover_reason.dart`
- `lib/features/rediscover/todays_pick_card.dart`
- `lib/features/rediscover/todays_pick_provider.dart`

### Backend tracked modifications

- `.dev.vars.example`
- `src/index.ts`
- `src/services/apify.ts`
- `src/services/extraction.ts`
- `src/services/shared.ts`
- `src/types.ts`
- `wrangler.toml`
- `wrangler.toml.example`

## High-Risk Areas To Rebuild Carefully

### 1. Persistence before enrichment

Before rebuilding more actor enrichment, the app needs a clear persistence rule:

- If a URL has already been saved and enriched, opening details must not call expensive enrichment again.
- Canonical URL matching should be used for Instagram, TikTok, YouTube, and common share-link variants.
- Rich actor fields should be stored durably if the UI depends on them.
- Temporary actor URLs should not be treated as stable canonical cover assets unless cached or proxied intentionally.

### 2. One enrichment pipeline

There should be one clear pipeline:

1. Normalize URL.
2. Check existing saved URL by canonical URL.
3. If stable enrichment exists, use it.
4. If source is supported, run source actor.
5. If actor has enough grounded evidence, enrich with actor evidence.
6. If actor evidence is weak, fall back to Gemini or metadata depending on source and cost policy.
7. Persist final durable fields once.
8. Do not re-run unless user asks to refresh.

### 3. TikTok policy

TikTok likely needs a product choice:

- Cheap mode: metadata, creator, stats, thumbnail, caption, lightweight summary.
- Deep mode: download/transcribe/OCR/vision, higher cost, user-triggered or rate-limited.

Recipe extraction from TikTok cannot be reliable from metadata-only actor output.

### 4. Rediscover rebuild order

Rediscover should be rebuilt after enrichment persistence is stable.

Recommended order:

1. Restore a stable Rediscover screen.
2. Remove only the large Home Today's Pick card.
3. Keep Home Rediscover carousel/cards if desired.
4. Add a small "Fresh Today" or "1 pick waiting" indicator.
5. Add single-item recommendations first.
6. Add packs only after semantic cohesion can be proven.
7. Share recall candidate logic with notifications only after Rediscover works alone.

### 5. Ask Glimpse rebuild order

Recommended order:

1. Make Ask Glimpse AI transport stable.
2. Add explicit URL context to Ask Glimpse route arguments.
3. Show the tagged saved URL in the chat.
4. Include saved title, summary, caption/transcript, and notes in prompt context.
5. Save useful AI answer back to the URL as a note or structured "Glimpse answer".
6. Avoid silent mutation of notes unless the user accepts/saves the answer.

## Verification Observed Before Rollback

Observed during the broader session:

- Backend typecheck passed during worker iterations.
- Cloudflare Worker deploys succeeded after App Check/Gemini config fixes.
- App logs showed actor enrichment requests/results for Instagram and TikTok.
- App logs showed TikTok actor metadata results with likes/comments but no transcript.
- Latest focused Flutter analyzer run was interrupted before completion.

No final full-app verification was completed before rollback.

## Reason For Rollback

The current worktree mixed too many large changes at once:

- Rediscover product redesign
- notification recall architecture
- Ask Glimpse context
- saved model schema changes
- app persistence changes
- actor enrichment
- backend extraction changes
- TikTok transcript experiments
- UI rendering changes

Because these landed together without a stable checkpoint, the app became inconsistent. The safest next step is to return to the last committed state, preserve this report, and rebuild one stable feature slice at a time.

## Suggested Rebuild Plan After Rollback

### Phase 1: Stabilize saved URL identity and persistence

- Add canonical URL normalization.
- Ensure duplicate saves resolve to existing records.
- Ensure opening details never re-enriches unless data is missing or user refreshes.
- Add tests for Instagram/TikTok/YouTube canonical URL matching.

### Phase 2: Stabilize enrichment output storage

- Define durable fields needed by Details:
  - title
  - summary
  - tags
  - category
  - creator
  - caption
  - transcript snippet or extracted facts
  - thumbnail
  - stats
- Persist them consistently.
- Make actor cache versioning explicit and rare.

### Phase 3: Rebuild Instagram only

- Restore actor-first Instagram enrichment.
- Verify recipes, books, movies, and places.
- Verify likes/comments/creator/thumbnail/caption.
- Verify no repeated Apify calls on reopen.

### Phase 4: Add YouTube

- Add YouTube/Shorts transcript-first enrichment.
- Keep Gemini fallback only after grounded transcript/metadata evidence.
- Verify with a small fixed test set.

### Phase 5: Decide TikTok mode

- Start with metadata-only as baseline.
- Add optional Deep Scan for transcript/OCR/vision if worth the cost.
- Avoid pretending metadata-only results can extract recipes reliably.

### Phase 6: Rebuild Rediscover

- Remove only the Home Today's Pick card.
- Preserve Home's existing Rediscover content if that was already good.
- Add lightweight Home indicator.
- Add single-item Rediscover recommendations first.
- Add packs only when semantic cohesion is demonstrable.

### Phase 7: Rebuild notifications from shared recall candidates

- Only after Rediscover single-item logic is stable.
- Keep cooldowns and memory simple first.

### Phase 8: Rebuild Ask Glimpse context

- Add URL context to Ask Glimpse.
- Save accepted answers back to the saved URL.
- Keep mutations explicit and visible.

## Rollback Command Plan

The intended rollback keeps this report file and removes all other uncommitted changes:

```powershell
git -C E:\code\glimpse\glimpse-enrichment-backend restore .
git -C E:\code\glimpse\glimpse-enrichment-backend clean -fd
git -C E:\code\glimpse restore .
git -C E:\code\glimpse clean -fd -e CHANGE_REPORT_AFTER_70202c0.md
git -C E:\code\glimpse status --short
git -C E:\code\glimpse\glimpse-enrichment-backend status --short
```

Expected result after rollback:

- Parent app repo should show only:
  - `?? CHANGE_REPORT_AFTER_70202c0.md`
- Backend repo should be clean.
