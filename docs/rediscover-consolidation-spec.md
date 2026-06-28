# Glimpse — Rediscover Consolidation Spec
> Collapse the competing journey generators into one coherent pipeline
> Companion to: Engagement Engine Spec (the original 4-slot design), behavioral-signal-engine-spec.md (#4), title-and-copy-consistency-spec.md

---

## 1. The problem

Rediscover currently builds cards from **~6 independent generators** that don't coordinate:

| Generator | Grouping basis | Quality |
|---|---|---|
| memory goals | keyword intent classifier (`_fallbackIntent`) | weak — only 15/215 saves have real intent metadata |
| revisit queue | explicit user intent (queued) | strong |
| becauseYouSaved | embedding clusters (hardened in #3) | good, but centroid filter too lenient |
| forgotten gems | old + unopened | topic-blind |
| never opened | unopened | topic-blind grab-bag |
| on this day | temporal | fine, narrow |

They **compete and duplicate** (two "Still perfecting your recipes?" cards — a cook goal and a food cluster), and the topic-blind/keyword paths emit **incoherent cards** (a "Food" journey containing GitHub repos and bird identification). Coherence is only as good as the weakest generator, and several are weak. The Rediscover *screen* (`rediscover_screen.dart`) duplicates this with its own parallel shelves.

## 2. The principle

The old code conflated three concerns. Separate them:

1. **Grouping** — *what saves belong together.* ONE coherent source: embedding-cluster **on-theme cores**. Plus two explicit non-topic groups: **queued-for-later** (user intent) and **on-this-day** (time).
2. **Framing** — *why surface it now.* Derived from the group's member **state**, mapping back to the original Engagement Engine spec's four slot types: **Continue · Still waiting · Forgotten gem · Connected thread.**
3. **Ranking** — *which to show, in what order.* `neglect × recency × size` now; `× behavioral affinity` once #4 lands.

Grouping never comes from a keyword guess again. Framing is a label on a coherent group, not its own generator.

## 3. Architecture

A single `buildRediscoverJourneys(...)` replaces the pile of `journeys.add(...)` blocks:

```
1. clusters = interestClusterThemesProvider           // coherent grouping
   → for each: members = liveIds ∩ isProcessingReady, then on-theme core
2. for each cluster core, read member state → assign a FRAMING:
     • 2+ saves added in last 48h            → Continue   (momentum)
     • has 21d+ saves, openCount 0, rich      → Forgotten gem
     • 2–3 saves share 2+ entityMentions      → Connected thread   (phase 5)
     • else                                   → Still waiting (because-you-saved)
   title  = topicJourneyTitle(dominantTopic(core))     // content-derived, not cluster.label
   eyebrow= motif vote over core                        // already fixed (#2)
   subtitle = framing copy
3. append explicit journeys:
     • Queued-for-later  (revisit queue — explicit intent, strong)
     • On-this-day       (temporal)
4. score = framingBase × neglect × recency [× affinity]   // affinity = #4
5. dedupe (title + ≥50% item overlap) → take N
```

One generator. No competing paths. Dedup becomes mostly unnecessary because there's a single grouping source, but it stays as a guard for the explicit journeys.

## 4. Migration — what each old generator becomes

| Old generator | Fate |
|---|---|
| memory goals (auto keyword) | **Retired** for topic grouping. Replaced by clusters. |
| memory goals (explicit queued/done intent) | **Kept** as the "Queued-for-later" journey — this is the strong [engagement-intent-engine] signal, not a keyword guess. |
| becauseYouSaved | **Becomes** the default "Still waiting" cluster framing. |
| forgotten gems | **Becomes** the "Forgotten gem" framing of a cluster (or a single old save). |
| never opened | **Retired** as a standalone grab-bag; "unopened" is now a per-cluster signal, not a topic-blind list. |
| on this day | **Kept**, unchanged. |

## 5. Coherence hardening (carry-overs + new)

- **Adaptive centroid core** — replace the fixed "keep top 60%" with a threshold: drop members whose cosine-to-centroid is below `mean − k·std` (k≈0.5). Heterogeneous clusters shed more; tight clusters keep nearly all. Fixes github/bird surviving in a food journey.
- **`isProcessingReady` filter** — already added; keep.
- **Content-derived titles** — already added; keep (cluster labels proven unreliable).

## 6. The Rediscover screen

`rediscover_screen.dart` has its own parallel shelves (goalShelf, interestShelf, …). Phase 4 points it at the **same** `buildRediscoverJourneys` output so the home carousel, the journey detail, and the triage screen are one consistent model — no third source of truth.

## 7. Phasing

1. **Unified cluster pipeline + framing** — replace generators 1/3/4/5 with one cluster-sourced builder that assigns Continue/Still-waiting/Forgotten-gem framings. Keep queued + on-this-day. (Biggest coherence win.)
2. **Adaptive centroid** (§5).
3. **Wire #4 affinity** into ranking (depends on the event log).
4. **Point `rediscover_screen.dart` at the same builder.**
5. **Connected-thread framing** (entity-overlap), completing the original 4 slots.

## 8. Decisions (resolved)

- **Auto memory-goals: retired.** The keyword-derived topic goals are dropped — clusters are the only topic grouping. Explicit user intent is kept but **folded into clusters** (queued saves boost their cluster's rank and lead its items) rather than getting a separate card.
- **Queued saves: folded into clusters** (not a standalone journey).
- **Journey count:** keep ~6 surfaced.
- **`k` for the adaptive centroid** (0.5 proposed) — tune once visible.

---

*This is a return to the original Engagement Engine spec's 4-slot model, with clusters as the grouping unit and behavioral affinity (#4) as the ranker. Phase 1 is the coherence unlock and can land before #4.*
