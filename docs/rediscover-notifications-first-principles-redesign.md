# Rediscover and Notifications: First-Principles Redesign

## 1. Current Implementation Audit

### Rediscover surfaces

Rediscover currently has two overlapping product surfaces:

- Home uses `rediscoverJourneysProvider` to show journey cards built from interest clusters.
- `/rediscover` still uses `todaysPicksProvider`, `revisitQueueProvider`, `forgottenGemsProvider`, `neverOpenedProvider`, `goalShelfProvider`, and `interestShelfProvider`.
- Journey detail pages use the journey object passed from the Home card and then split that same item set into `Continue from here`, `Forgotten gems`, `Related interests`, and `Connected saves`.

This means Home, the Rediscover screen, and notification selection do not share one memory model. The user can see a coherent journey on Home, then a separate deck/shelf system inside Rediscover, then receive a notification from a third A-G trigger system.

### Card generation

Home journey cards are generated from embedding-based interest clusters through `interestClusterThemesProvider`. The provider:

- loads cached cluster themes from SharedPreferences;
- clusters embedded URLs by broad category and cosine similarity;
- optionally asks Gemini to name main clusters and subclusters;
- applies heuristic fallback labels;
- merges duplicate themes and promotes foreign subclusters when a subcluster clearly belongs to another broad category.

`rediscoverJourneysProvider` then filters those clusters to live, processing-ready saves, trims each cluster to an on-theme core, frames the cluster, ranks it, and returns up to six journeys.

The current on-theme core keeps the top 60% of embedded members by centroid similarity. This is a good idea, but the fixed percentage is blunt: loose clusters keep too many outliers, while tight clusters unnecessarily lose relevant saves.

### Category and topic generation

Categories come from enrichment and normalization. They are useful infrastructure but are still too visible in some Rediscover framing. Real backup data shows why this is dangerous:

- 215 saves total.
- 134 unopened.
- 198 enriched.
- 212 embedded.
- Top raw domains are `instagram.com` and `x.com`.
- Top raw tags include `social`, `x`, `twitter`, `instagram`, `web`, and `video`.

The app already has `TagNoiseFilter` and `TagAnalyzer.notificationTopicTags`, which correctly separate searchable tags from notification-safe topic tags. Rediscover and notification code should treat those as mandatory gates.

### Ranking

There are two ranking systems:

- `RevisitScorer` scores individual saved URLs using explicit queue state, on-this-day anniversaries, embedding similarity to recent saves, category/tag overlap, unopened state, age, and recent resurfacing dampening.
- `rediscoverJourneysProvider` scores journeys using framing base score, unopened share, freshest-save recency, behavioral affinity, and a queued boost.

The journey ranker is closer to the desired model because Rediscover should mostly surface coherent memory groups, not isolated old links. `RevisitScorer` remains useful as an item-level fallback and for single-link notifications, but it should not be the main Rediscover brain.

### Card lifecycle

Saved URLs have useful lifecycle fields:

- `openedAt`
- `resurfacedAt`
- `rediscoverDismissedAt`
- `intentStatus`
- `intentAction`
- `intentSetAt`
- `revisitAfter`

These are strong primitives. The weakness is that lifecycle is stored at the save level, while Rediscover is now mostly journey-level. A journey can be shown repeatedly if only one member is resurfaced, and dismissing a save does not clearly express "less of this topic for now."

### Refresh frequency

Interest clusters rebuild when the embedded URL count changes enough or when cache is cleared. Rediscover providers rebuild when URL count changes. There is no explicit daily Rediscover session model, no stable "today's set", and no journey-level shown history.

This can make Rediscover feel either static or unstable:

- static, because cached clusters and deterministic sorting produce familiar cards;
- unstable, because provider invalidation can reshuffle item order without a clear daily contract.

### Notifications

Notifications are scheduled by WorkManager through `DigestScheduler` and selected by `NotificationScheduler`. The scheduler has seven trigger letters:

- A: geography
- B: new interest
- C: collector/deep-dive pile
- D: saving streak
- E: specific old unread save
- F: weekly digest
- G: revisit reminder

The scheduler enforces quiet hours, one notification per day, a 20-hour minimum gap, and a three-day topic-signature cooldown. Copy comes from `GeminiCopywriter` when the proxy is enabled and the profile is rich enough, with local fallbacks otherwise.

This is robust operationally, but not philosophically aligned with Rediscover. Trigger types are still system-centric. They ask "which template can fire?" more than "which memory deserves to come back today?"

### Personalization

The app has an `EngagementEvent` log and `AffinityProfile`:

- events are capped to 5,000 or 180 days;
- weights decay with a 21-day half-life;
- category, cluster, source, hour, trigger responsiveness, and engagement level are derived on-device.

This is the right foundation. Current gaps:

- Rediscover card opens are often logged as generic opens, not consistently as `cardOpened` with cluster context.
- `cardShown` is not consistently recorded.
- Notification opens are logged, but notification dismissals are not available from the local notification plugin.
- Notifications still rank candidates mostly by trigger type bandit, not by memory/journey value.

### Related content

Journey detail currently shows:

- `Continue from here`
- `Forgotten gems`
- `Related interests`
- `Connected saves`

These sections are useful when they add context, but today they are mechanically derived from opened/unopened state. They do not yet answer "why this supporting section exists." `Related interests` can become tag wallpaper if it repeats obvious tags.

## 2. Why The Current System Misses Delight

The implementation has good parts, but the emotional contract is fragmented.

- It often explains state, not meaning: `Unopened`, `Worth revisiting`, `3 saves worth reopening`.
- It uses topic labels as card identities: `Agriculture`, `Spirituality`, `Food`.
- It has no durable daily promise: a user cannot sense that Glimpse chose a few thoughtful things for today.
- Notifications are too separate from Rediscover: they can be warm copy over a trigger that was not selected by the same intelligence as the page.
- The UI can look premium while still feeling generated because multiple cards share the same sentence structure.

The core failure mode is not lack of AI. It is lack of a single resurfacing judgment.

## 3. Rediscover Philosophy

Rediscover should only surface something when it can answer six questions:

- Why this save or group?
- Why today?
- Why this user?
- Why now?
- What feeling should it create?
- What action should it invite?

The preferred feeling is recognition: "I forgot I saved this, and I am glad it came back."

Rediscover is not a feed. It is a small daily memory ritual. It should be selective, quiet, and explainable. Silence is acceptable. Filler is not.

## 4. Ideal System Shape

The core unit should be a `RediscoverMemory`, not a shelf, category, or template.

```text
RediscoverMemory
  id
  kind
  title
  headline
  reason
  action
  primarySaveIds
  supportingSaveIds
  topicAnchor
  intent
  lifeArea
  scoreBreakdown
  lifecycleState
  createdForDate
  expiresAt
  lastShownAt
  dismissedAt
```

Possible memory kinds:

- `explicit_revisit`: user queued this.
- `forgotten_thread`: coherent topic with unopened older saves.
- `momentum_thread`: recent repeated saving around one topic.
- `seasonal_return`: saved around this day or season.
- `goal_return`: multiple saves imply a practical user goal.
- `single_gem`: one unusually strong, enriched, old unread save.

Every UI card and notification should be a rendering of the same memory object.

## 5. Ranking Algorithm

Use a transparent weighted score. Start deterministic and on-device.

```text
score =
  baseKindWeight
  + explicitIntentBoost
  + neglectScore
  + topicalMomentumScore
  + freshnessScore
  + seasonalityScore
  + enrichmentQualityScore
  + actionabilityScore
  + affinityScore
  + diversityScore
  - fatiguePenalty
  - recentRepeatPenalty
  - weakEvidencePenalty
```

Recommended starting weights:

- `explicitIntentBoost`: +40 when the user queued the save and it is due.
- `neglectScore`: 0 to +20 based on unopened share and age, capped.
- `topicalMomentumScore`: 0 to +18 for repeated saves in a topic over recent days/weeks.
- `freshnessScore`: 0 to +10 when the topic is currently active.
- `seasonalityScore`: 0 to +12 for one-month, three-month, six-month, one-year returns.
- `enrichmentQualityScore`: 0 to +10 for summary, thumbnail, recipe/entities/key points, and embedding.
- `actionabilityScore`: 0 to +12 for recipes, travel plans, learning paths, products, tools, and queued actions.
- `affinityScore`: -15 to +20 from decayed engagement events.
- `diversityScore`: -8 to +8 to avoid showing the same life area repeatedly.
- `fatiguePenalty`: -30 for dismissed/recently ignored journeys.
- `recentRepeatPenalty`: -20 if the same journey was shown in the last few days.
- `weakEvidencePenalty`: -25 if the group depends mostly on source/platform/noise tags.

Keep a score breakdown in memory/debug output. This makes the system tuneable and prevents black-box randomness.

## 6. Card Generation Pipeline

1. Build clean candidate groups from interest clusters, explicit queued saves, on-this-day saves, and strong single gems.
2. Filter every topic through `TagAnalyzer.notificationTopicTags`.
3. Build adaptive on-theme cores from embedding distance, not a fixed percentage.
4. Infer the memory kind from member state.
5. Generate card identity from intent + topic + lifecycle, not raw category.
6. Score and diversify candidates.
7. Materialize a small daily set.
8. Render Home, Rediscover, journey detail, and notifications from the same set.
9. Record shown/opened/dismissed/snoozed outcomes.
10. Use those outcomes in the next scoring pass.

## 7. Category and Headline Strategy

Categories should not be headlines. They should provide color, motif, and fallback organization.

Card identities should be more like:

- `Healthy Breakfast Experiments`
- `Questions You Wanted Answered`
- `Your AI Builder Thread`
- `Natural Farming Notes`
- `Recipes That Could Solve Dinner`
- `Treks You Kept Coming Back To`

Headlines should be personal but restrained:

- `You were onto something here.`
- `This thread is still warm.`
- `Your future self left a useful clue.`
- `Sunday would be a good day for this.`
- `This one keeps matching what you save lately.`

Avoid:

- `Continue reading`
- `Rediscover this`
- `Worth revisiting`
- `You have unread links`
- `Your X collection is waiting`

## 8. Card Lifecycle

Recommended daily contract:

- Generate up to 5 active Rediscover memories per day.
- Show 1 primary memory and up to 4 supporting memories.
- Keep a memory active for 2 to 5 days unless opened, dismissed, or made stale.
- Do not show the same topic anchor as primary two days in a row unless it is explicit queued intent.
- Do not repeat a dismissed topic for at least 14 days, with decayed recovery after that.
- If there are no strong candidates, show nothing or a quiet empty state.

Save-level lifecycle should remain, but add journey/memory-level lifecycle in SharedPreferences or Isar once stable:

- `shownAt`
- `openedAt`
- `dismissedAt`
- `snoozedUntil`
- `scoreBreakdown`
- `primaryTopic`
- `sourceCandidateIds`

## 9. Personalization Engine

Personalization should fade in by library size:

- 0-9 saves: no Rediscover pressure; show recent saved context only.
- 10-99 saves: cluster and neglect signals dominate; minimal behavioral learning.
- 100-499 saves: daily memory set, diversity, topic momentum, and notification trust become meaningful.
- 500+ saves: stronger goal detection, seasonal returns, long-term interest cycles.
- 5000+ saves: indexing, cache invalidation, and lifecycle persistence become critical; avoid full scans in UI builds.

Use the existing `AffinityProfile`, but feed it better events:

- `cardShown` with memory id and topic/cluster.
- `cardOpened` with memory id and topic/cluster.
- `cardDismissed` with memory id and topic/cluster.
- `notifShown` with memory id and trigger.
- `notifOpened` with memory id and trigger.
- `tapThrough` from detail to source.
- `searchHit` when a user opens a result.

## 10. Notification Engine

Notifications should be selected from the same `RediscoverMemory` candidates as the page.

Notification flow:

1. Build today's Rediscover memories.
2. Remove anything already shown too recently or dismissed.
3. Require a minimum notification score higher than the in-app score.
4. Choose at most one notification candidate.
5. Generate copy from the memory object and local summary first.
6. Use Gemini only when the profile is rich and local copy cannot be specific.
7. Send nothing when the candidate is weak.

Notification timing:

- Keep quiet hours.
- Keep one-per-day max.
- Use `AffinityProfile.peakHour` when warm.
- Otherwise default to the current peak-open histogram fallback.
- Increase cooldown after ignored sends.
- Allow explicit queued reminders to bypass longer cooldowns, but not quiet hours.

Notification copy should reference the specific memory:

- `That high-protein breakfast idea might fit tomorrow morning.`
- `Your farming thread has a practical next step.`
- `You saved three free-will perspectives this week. One is worth reopening.`

## 11. Related Content

Supporting sections should be conditional:

- `Continue from here`: at least one item was opened or queued.
- `Forgotten gems`: at least two old unopened, enriched saves in the same memory.
- `Connected saves`: always valid when the journey contains multiple saves.
- `Related interests`: only when tags add new context and are not just repeats of the title.
- `Deep dive`: only when summaries/entities/key points can form a useful path.

No section should exist just because a list can be computed.

## 12. Suggested Flutter Architecture

Add a single domain layer:

```text
lib/core/services/rediscover_memory_engine.dart
lib/core/models/rediscover_memory.dart
lib/core/models/rediscover_score_breakdown.dart
lib/features/rediscover/rediscover_memory_provider.dart
```

Responsibilities:

- Engine builds, scores, diversifies, and explains candidates.
- Provider exposes today's active memories.
- UI renders memories.
- Notification scheduler asks the same provider/engine for notification candidates.

Keep UI-specific components in `features/rediscover`. Keep scoring and candidate generation out of widgets.

## 13. Migration Plan

Phase 1: tighten current journey quality.

- Replace fixed 60% centroid trimming with adaptive similarity trimming.
- Log Rediscover card opens with cluster context.
- Stop using generic fallback labels as card identities when a better topic exists.

Phase 2: unify UI surfaces.

- Point `/rediscover` at the same journey/memory output as Home.
- Retire standalone `Never opened` and topic-blind `Forgotten gems` shelves.
- Keep on-this-day and explicit queued intent, but render them as memory kinds.

Phase 3: introduce `RediscoverMemory`.

- Store score breakdowns and daily memory lifecycle.
- Build daily set once per day or when the library changes meaningfully.
- Add memory-level dismiss/snooze/open handling.

Phase 4: unify notifications.

- Select notifications from Rediscover memories.
- Keep existing A-G triggers only as fallback diagnostics during migration.
- Move copy generation to memory-based copy inputs.

Phase 5: deepen personalization.

- Add more event instrumentation.
- Use affinity in both ranking and timing.
- Add fatigue and diversity controls.

## 14. Edge Cases

- Thin libraries: do not force Rediscover before there are enough saves.
- No embeddings: fall back to explicit queued saves, on-this-day, and high-quality single gems.
- Mostly social saves: strip source/platform tags before topic selection.
- Stale thumbnails: card should still render with typography and motif.
- Processing saves: include only when summary or enrichment is present.
- Done saves: exclude from Rediscover and notifications.
- Dismissed saves: exclude save-level; memory-level dismissal should suppress the topic temporarily.
- Repeated saves in one day: treat as momentum only if topic-safe and coherent.
- No good notification candidate: send nothing.

## 15. What To Remove

- Remove topic-blind `Never opened` as a primary Rediscover section.
- Remove generic "saving streak, not reading" notification language. It creates guilt instead of trust.
- Remove category-as-identity headlines.
- Retire keyword-derived memory goals as card grouping. Keep explicit queued/done intent and structured enrichment intent.

## 16. Success Criteria

Rediscover is working when:

- each card has a clear "why today";
- repeated cards feel rare;
- notification copy and in-app cards point to the same memory logic;
- dismissing a card visibly reduces similar future surfacing;
- saving more links makes Rediscover more specific, not more cluttered;
- the system chooses silence over weak suggestions.
