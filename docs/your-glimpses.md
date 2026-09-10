# Your Glimpses

Rediscover remains the main `/rediscover` destination, with its established
artwork cards and a detail hierarchy of Why today, Start here, and supporting
saves. Home's artwork cards use the same local selection. Single-save cards and
notifications open their source directly; multi-save notifications open the
persisted selection above Home. Inbox rows have Clear with Undo.

Your Glimpses at `/glimpses/history` is the secondary personal history. It shows
monthly activity and ranked topics without repeating them in a summary banner.
The chart initially selects the most recent day with saves. Past weekly editions
are available below the activity view.

## Content

- Connections reuse the existing topic-pulse detector. Strong evidence is
  required for an automatic notification; broad category overlap is insufficient.
- Saved ideas prefer a highlight or personal note, then an existing summary.
  Summaries are labelled as summaries and are not rendered as source quotations.
- Explicit revisit intentions retain their due date and single-save Done action.
- Day, week and month briefs use local calendar boundaries. Completed saves
  remain available in historical briefs. Deleted sources are removed.
- A weekly review replaces the daily/weekly/monthly brief list. It offers a
  starting save, preferring a selected highlight or note, and an independently
  supported older connection when available. Completed starting saves and weak
  connections are excluded. Activity counts remain in personal history.
- Weekly evidence first covers distinct subjects, then adds distinct ideas
  within recurring subjects, with a maximum of six excerpts.
- The month capsule provides a daily saving chart, up to five ranked topics,
  and twelve months of navigation. Day and topic selections open their matching
  saves. Future dates have no recorded activity. Existing topic artwork is reused.
- Monthly activity describes recorded returns, notes and completed intentions.
  It does not infer reading completion, mastery, beliefs or personality.

Candidate construction runs in an isolate. Content changes at a stable save
count, date rollover and foreground resume invalidate the shared presentation.
Rebuilds preserve interaction state, and requests arriving during a build trigger
a subsequent build from current data.

## Persistence and delivery

`GlimpseRecord` is an additive Isar collection. Versioned source content is stored
separately from opened, retired, snoozed and delivery receipts. Database write
transactions arbitrate worker claims. A ten-minute lease recovers from interrupted
workers; stable Android IDs and `onlyAlertOnce` prevent retry alerts.

Automatic notifications use a separate normal-importance Android channel:
`glimpse_insights_v1`. Save-status notifications keep their existing channel and
do not offer Done/Later. Historical single-save action payloads remain supported.

Default automatic limits are three posts in a rolling seven days, at least 48
hours apart, with quiet hours from 21:00 through 08:59. A previously promoted
source is excluded for 14 days. Sunday evening is reserved for a useful weekly
brief. A connection waits at least an hour after enrichment and expires after
seven days. Sparse or unsupported content stays in-app without an automatic push.

Explicit reminders and requested Later returns are outside the automatic budget,
retain quiet hours, and are separated by at least 20 hours. Delivery is best
effort through WorkManager, not an exact-time alarm. Missed weekly editions do
not produce catch-up bursts.

Got it retires the glimpse, not its sources. Done changes intent only for a
single explicit reminder. Later postpones for three days without recording an
open reward or topic dislike. In-app actions also reconcile the tray and history.

## Optional AI

Automatic selection and local review content require no model calls. An optional,
off-by-default setting in Your Glimpses allows a written review of the latest
completed week when Rediscover is opened. Its consent dialog explains cloud
processing and the Ask allowance before enabling it. Selected summaries and
highlights may be sent; personal notes are always excluded.

Preparation attempts are limited to one per weekly edition in the foreground.
There is no backfill of editions older than a week, no generation for an unfinished
week, and no request when fewer than two eligible excerpts exist. Offline opens
keep the local review. Failed attempts do not automatically spend additional
requests on retries. Disabling the setting prevents future preparation; already
prepared content remains readable.

The existing transport and entitlement-aware Ask allowance are reused. Written
reviews appear inline when ready, with no Expand button. Paragraphs support
multiple source citations; every quoted passage must match an input excerpt.
Connections between sources must cite both in the generation contract. Citation
validation does not guarantee semantic correctness, and prose remains labelled
as AI output from selected excerpts. Notification copy uses cached prose when
available or a concrete saved excerpt, not repeated activity counts.

Results are cached by source content, operation context, locale and note consent.
Editing or deleting evidence invalidates the result; ranking-only updates do not.
Failures and allowance limits leave local content available. User-facing labels
are localized in en, de, es, fr, ja and pt-BR; existing source content is unchanged.

## Validation

Focused tests cover calendar periods, weak/strong connections, same-count edits,
deletion, concurrent worker claims, quotas, source cooldowns, snooze replay,
legacy actions, notification channel configuration and failure receipts, Home's
existing card/loading behavior, large translated text, and Home-backed routing.
Light and dark screen renders are in `test/goldens/glimpses_*.png`.

The repository's existing code generators use an older analyzer that cannot parse
some unrelated modern Dart syntax in URL Details. Glimpse schema generation is
targeted; Dart analysis and Flutter compilation validate the generated output.

Glimpse records and AI caches are derived device-local state and are not added to
exported backups. Save content and existing intentions keep their existing backup
behavior. Monthly activity is limited to the locally retained engagement history.
