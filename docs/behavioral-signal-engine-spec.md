# Glimpse — Behavioral Signal Engine Spec (#4)
> The on-device learning layer that fuels Rediscover + Notifications with everything the user does
> Version 0.1 — design for review (companion to the Engagement Engine Spec and title-and-copy-consistency-spec.md)

---

## 1. Purpose

Rediscover and notifications are Glimpse's moat: the reason someone opens the app on a random Tuesday to return to what *they* chose to save. Today they run on static content signals (recency, neglect, cluster size). This spec adds the missing layer: **a closed-loop, on-device model that learns from the user's own behavior** — what they save, open, search, revisit, dismiss, and which notifications they act on — and uses it to decide *what to resurface* and *what/when to notify*.

"Play like Zomato": every interaction feeds the next recommendation. The difference is we do it **entirely on-device, with no login and no LLM in the loop** — which is also the thing IG/X/YT can't replicate for *your* library.

## 2. Hard constraints (non-negotiable)

- **No network, ever.** The event log and the derived profile never leave the device. No sync, no server.
- **No login.** Identity is the device. Consistent with [free-tier-abuse-and-no-login] / on-device privacy stance.
- **No LLM in the scoring loop.** All ranking is deterministic on-device math (microseconds). Gemini stays only in the enrichment/clustering path it already occupies — this layer adds **zero** Gemini calls.
- **Cheap & bounded.** The event log is capped and time-decaying; recomputation runs inside the existing provider regeneration, not on a timer.

## 3. The blocker this solves

A real backup audit (215 saves) showed: saves, `savedAt`, `openedAt`, and `saveSessions` exist — but **notification-opens, category/cluster visits, searches, card dismissals, and repeat-opens are recorded nowhere.** You cannot rank by behavior you never logged. So Phase 1 is not scoring — it's **instrumentation**.

---

## 4. The Event Log

A new Isar collection. Append-only, capped, decaying.

```dart
enum EngagementEventType {
  save,           // a URL was saved
  open,           // a save's detail card was opened in-app
  tapThrough,     // user tapped through to the source (IG/web/etc.)
  search,         // a search query was run
  searchHit,      // a save was opened from search results
  categoryVisit,  // a category/interest surface was opened
  clusterVisit,   // an interest cluster was opened
  cardShown,      // a Rediscover card/slot was rendered to the user
  cardOpened,     // a Rediscover card was tapped
  cardDismissed,  // a Rediscover card was swiped away / "not interested"
  cardSnoozed,    // a Rediscover card was snoozed
  notifShown,     // a push notification was delivered
  notifOpened,    // a push notification was tapped
  notifDismissed, // a push notification was cleared without opening
  intentSet,      // user set queue/done intent (see engagement-intent-engine)
}

@collection
class EngagementEvent {
  Id id = Isar.autoIncrement;
  @enumerated(EnumType.name)
  late EngagementEventType type;
  late DateTime at;

  int? urlId;            // the save involved, if any
  String? category;      // denormalized for fast aggregation (content category, platforms excluded)
  String? clusterLabel;  // interest-cluster label, if known
  String? source;        // platform/source (Instagram, X, …)
  String? query;         // search text (stays on device)
  String? triggerType;   // notification trigger type, for notif* events
  int hourLocal = 0;     // local hour 0–23 at event time (for timing model)
}
```

**Retention:** keep the most recent **5,000 events or 180 days**, whichever is smaller; prune on write. This bounds storage and keeps the decay window meaningful.

**Instrumentation points (Phase 1):** wherever these actions already happen — `_launchUrl`/`updateOpenedAt` (open, tapThrough), search provider (search, searchHit), category/cluster screens (categoryVisit, clusterVisit), Rediscover card render/tap/dismiss/snooze, the notification router (notifOpened) and scheduler (notifShown), `updateIntent` (intentSet). One thin `EngagementLog.record(...)` call per site.

> Phase 1 ships **no behavior change** — it only starts recording. Everything downstream is worthless without this data, so it lands first and is allowed to bake while events accumulate.

---

## 5. Derived signal: the AffinityProfile

Folded from the event log on demand, cached with a short TTL (e.g. 1h) and invalidated on new saves. Pure math.

### 5.1 Time decay

Each event contributes `weight(type) × decay(age)` where:

```
decay(ageDays) = 0.5 ^ (ageDays / HALF_LIFE)   // exponential, HALF_LIFE = 21 days
```

Recent behavior dominates; old behavior fades but never fully disappears.

### 5.2 Event weights (starting values, tunable)

| Event | Weight | Rationale |
|---|---|---|
| tapThrough / searchHit | 5 | strongest intent — they went *into* it |
| open | 3 | engaged with the save |
| intentSet (queue/done) | 3 | explicit signal |
| save | 2 | interest, but cheap |
| clusterVisit / categoryVisit | 2 | active exploration |
| search | 1 | curiosity |
| cardOpened / notifOpened | 4 | the resurfacing *worked* |
| cardDismissed / notifDismissed | −4 | the resurfacing *missed* |
| cardSnoozed | −2 | soft miss |

### 5.3 What we compute

- **categoryAffinity**: `category → Σ weighted-decayed events`. What topics they actually act on.
- **clusterAffinity**: `clusterLabel → …`. Same, at interest-cluster granularity (reuses #3 clusters).
- **sourceAffinity**: `source → …`. Which platforms they genuinely return to (vs. just save from).
- **openByHour**: histogram of `open`/`notifOpened`/`cardOpened` by `hourLocal` → the user's real engagement window.
- **triggerResponsiveness**: `triggerType → opened / shown` rate → which notification types land vs. get ignored.
- **engagementLevel**: recent positive-event density → global "lean in vs. back off" dial.

All maps are normalized to 0–1 for use as multipliers.

---

## 6. Feeding Rediscover

Today each journey carries a static `signal` (memoryGoal 90, revisit 86, becauseYouSaved 78, gems 68, neverOpened 54, onThisDay 50) in `rediscover_journey_provider.dart`. Replace the static value with:

```
journeyScore = baseSignal(kind)
             × (0.5 + clusterAffinity[journey.cluster])   // 0.5–1.5 multiplier
             × neglectFactor(unopened share)
             × recencyFactor(freshest member)
             − fatiguePenalty(recently shown/dismissed this cluster)
```

- **Item selection within a journey**: weight each member by `neglect × (0.5 + categoryAffinity)`, so the most-relevant unopened saves lead.
- **Negative feedback**: a cluster the user repeatedly dismisses sinks via `clusterAffinity` going negative and the fatigue penalty — it stops being surfaced without a hard block.
- **Positive feedback**: a cluster they search for / revisit rises, even if it's older.

Result: the ordering of journeys becomes *personal and adaptive* instead of a fixed priority list.

## 7. Feeding Notifications

Wire the same profile into `notification_scheduler.dart` / `notification_templates.dart` / `gemini_copywriter.dart` (copy still constrained; no new Gemini calls — copy is already gated + 24h-cached):

- **Trigger selection** — among eligible triggers, pick by `affinity × triggerResponsiveness`. If they never open "Momentum" notifications, stop sending them. (Supersedes the original spec's fixed priority order with a learned one.)
- **Timing** — schedule inside the `openByHour` peak window instead of a hardcoded 7–9pm. Fall back to 7–9pm until enough data.
- **Frequency / fatigue** — keep the 1/day cap, but grow the cooldown when ignored and shrink it (toward the cap) when engaged, driven by `engagementLevel`.
- **Content anchor** — the save/cluster with the highest `affinity × neglect`, not just highest raw neglect.
- **Suppression** — dismiss/snooze and notif-ignored feed the negative loop (already partly in the Engagement Engine spec §6).

## 8. Closed feedback loops (the actual "Zomato")

The point is the loop, not the math:

- **Positive**: open, tapThrough, searchHit, intent=queue, cardOpened, notifOpened → boost that category / cluster / source / hour.
- **Negative**: dismiss, snooze, "not interested", notif ignored → decay it.

Every surfacing is also a probe; its outcome retrains the next one. No server, no login, per-user.

## 9. Cold start

A new user has almost no events. Until the log crosses a threshold (e.g. **≥ 30 weighted events**), affinity multipliers are forced toward 1.0 (neutral) and the engine runs purely on the content signals it has today (recency, neglect, clusters from #3). The behavioral layer fades in as data accrues — it never makes a thin profile *worse*.

## 10. Reconciliation with the existing engine

- **Extends, not replaces.** Builds on `RediscoveryService` / `revisit_scorer` / the journey + cluster architecture (#3) and memory goals.
- **The original Engagement Engine Spec** (ReadStatus, snooze, the 4 notification triggers, the daily session) is the substrate; this is the *learning layer* on top. Several fields that spec wanted but the model lacks (`openCount`, repeat-open history, `notificationShownCount`) are now **derivable from the event log** instead of needing new per-save columns.
- **title-and-copy-consistency-spec.md** governs how the resulting cards/notifications are *labeled*; this spec governs *what gets picked*.

## 11. Phasing

1. **Event log + instrumentation.** Ship the Isar collection + `EngagementLog.record(...)` at every action site. No behavior change. Let it bake. *(prerequisite — nothing else works without it)*
2. **AffinityProfile** computation + cache.
3. **Rediscover scoring** wired to affinity (journey order + item selection).
4. **Notification** trigger selection + timing + frequency wired to affinity.
5. **Feedback loops + cold-start guard + tuning** against the 3 testers' real logs.

## 12. Decisions (resolved)

- **Decay half-life = 21 days** (balanced). `decay(ageDays) = 0.5 ^ (ageDays / 21)`. Recent behavior dominates; interests stay stable over ~a month.
- **Notification timing = learned.** Schedule inside the user's real `openByHour` peak; fall back to a fixed 7–9pm window until the profile crosses the cold-start threshold (§9). Trigger *type* is also learned via `triggerResponsiveness`.
- **Negative feedback = decaying penalty.** A dismiss/snooze adds a penalty that **fades over time** (same 21-day decay), so a topic sinks gradually and can recover if the user re-engages — no hard one-strike block. Repeated dismissals stack, so persistent rejection still buries it, but a single bad day doesn't.
- **Event-log cap = 5,000 events / 180 days** (rolling, prune on write). Comfortable for a power user (215 saves ≈ a few hundred events/month).

---

*Reviewed with Yash; decisions above are locked. Phase 1 (instrumentation) is the unlock and lands first regardless — it's not blocked by any scoring decision.*
