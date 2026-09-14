# Glimpse onboarding v2

## Current visual direction — 2026-09-14

The user rejected screenshots of text-heavy onboarding cards. Enrichment, Interests, and discovered items now use original, almost wordless editorial illustrations (`enrichment.webp`, `interests.webp`, `discovered.webp`). Each screen has one short supporting line, localized in all six languages; detailed image descriptions remain available to screen readers. The content group sits near the bottom action, with scrolling retained on small screens or at large text sizes. No mascot is displayed anywhere in onboarding.

Ask uses a shortened, source-backed example captured from the real chat components; Rediscover uses two captures of the real artwork cards. These are illustrations/prepared examples, not live AI results. Only these two chapters use localized raster UI: 36 lossless WebP layers across six locales and two brightnesses. Regenerate with `flutter test tool/render_onboarding_previews.dart`, then `python tool/optimize_onboarding_previews.py`. The renderer uses the subset Japanese font in `tool/fonts`, licensed under the bundled Noto OFL.

Enrichment reveals from the incoming link toward the knowledge folio; other scenes have gentle, one-time reveals, with staggered Rediscover cards. This is animated illustration presentation, not a simulated live enrichment operation. Reduced motion shows completed states immediately; navigation never waits for animation. Explore Pro is primary, Start with Free remains available, and existing Pro users continue normally. Published allowance definitions remain authoritative.

Validation: 25 flow/asset/motion tests plus 14 light/dark renders passed. 36 UI capture renders passed. Device frame timing and purchase acceptance were not run in this revision. Earlier sections below record the preceding design iterations and are superseded where they conflict.

Seven offline chapters show outcomes: keep discoveries, read useful context, discover interests and library items, search and Ask, return through connections or intentions, and understand Free/Pro. Serif headlines and warm, quiet copy remain. Onboarding follows the app's effective brightness and defaults to the system, with curated warm-ivory/sage and charcoal/sage palettes independent of dynamic accents. The underlying app theme remains unchanged. All text lives in the six existing ARB catalogs.

Published allowances use `UsageLimits.planAllowance`, independently of development test ceilings: unlimited ordinary saving; Free includes 30 lifetime AI-enriched saves, 30 monthly Ask questions, and 30 monthly searches; Pro includes 500 monthly AI-enriched saves and expanded Ask/search subject to fair use. The production enforcement path uses this same definition.

## Flow

Back and Skip remain available, except during the bounded completion write. A single PageView supports swipe and tap navigation; tap transitions use 280ms easeInOutCubic, with repeated taps coalesced during motion. Reduced-motion mode jumps immediately. Each page preserves its scroll position, Overview/Places selection, and library category. The primary button stays 8px above the bottom safe area, with the optional Pro action above it. Artwork is precached at the same decoding size used by its widget.

Completion writes local guidance and optional Pro intent before the existing completion flag. Demo insertion and analytics cannot hold up navigation. Resetting onboarding also resets the coordinator's completed-session state, fixing the disabled-buttons trap on replay. Completion controls recover after both success and failure while root routing updates. Skip does not insert an example. Existing completed installs are not forced through v2.

## Chapter details

1. The mascot introduces articles, recipes, places, and books.
2. The real France save preview shows In brief, three Key takeaways, and tappable extracted Places to visit. It uses the actual reader SectionHeader, editorial title, and body rhythm. Copy is a localized, shortened version of observed production enrichment, not a fabricated article.
3. Interests leads with the real ClusterCard component: a compact Top signal hero, Growing interests, and Quieter interests. Recipes & Cooking, Software & AI, Travel, and Movies are neutral examples. Compact sizing is opt-in; the real dashboard is unchanged.
4. Discovered Books/Movies/Music/Places and personal collections have their own screen.
5. A prepared synthesized answer and source reference are visible immediately, with no reveal button or AI request.
6. Product review confirmed both behaviors coexist in `glimpse_engine.dart`: automatic topic-pulse connections and queued revisit intentions. The user chose equal prominence. The scene shows a source-backed automatic connection with Why today and a separate chosen revisit, with optional device alerts.
7. Free/Pro uses published allowances, with store-owned pricing and existing entitlement handling.

Pro intent waits for authentication and Home, then opens the existing subscription screen. Incoming shares and launcher shortcuts cancel the optional Pro handoff. Store pricing, purchase, restore, and cancellation remain in the existing subscription flow. No price or trial claim is embedded in onboarding.

## First use and example data

Home's existing guide opens a localized sharing/paste explanation with a first-save action. Reader, Library, and Rediscover guidance is shown once for v2 installs when relevant content exists. The France example is labeled in both cards and Details and can be deleted through existing controls. It is removed after a real save, including the race where a real save arrives during seeding. A stale demo ID cannot delete a real save.

The example is bundled, localized, and never re-enriched. Sample-only Ask and Search remain local and unmetered. Sample-only library entities are excluded from remote backfill, and demo content is excluded from generated Glimpses and notifications. First-real-save and first-real-read events are distinct from tutorial interactions; existing session events support return-rate analysis.

## Notifications

Notification initialization registers handlers and channels without requesting permission. Only an explicit notification-enable or real revisit-intention action can request permission, after an explanation. Declining keeps the intention in-app. Already granted permission skips the prompt; blocked permission offers system settings. Returning from settings refreshes the effective permission state. Background enrichment initialization stays unchanged.

## Artwork

Generated using the built-in image tool, with `assets/mascot/home.webp` as the identity reference. The three optimized 768px WebP assets have verified alpha transparency and total about 127 KiB. The same softly lit, desaturated gray-sage artwork is shared by light and dark themes. Readable UI, labels, and source references are Flutter widgets, not image text.

- `assets/onboarding/welcome.webp`: exact cream curled ghost, glossy dark eyes with green reflections, holding a sage saved card; book, map, recipe bowl, and article card around it; spacious square composition; transparent background; premium soft clay; no text or interface.
- `assets/onboarding/reading.webp`: same mascot studying an open sage book, seated and quietly curious; generous margins; transparent background; soft ambient shadow; no text or other props.
- `assets/onboarding/wave.webp`: same mascot holding a small saved card and gently waving; quiet welcoming pose; generous margins; transparent background; no text, interface, or exclamation marks.
- Separate dark assets were removed after product review. Foreground shading remains in the shared artwork; the actual app surface supplies the background, with no opaque panel or floor.

## Verification

Focused tests cover seven-chapter navigation, retained previews, swipe/tap interpolation, repeated taps, replay after completion, skip, completion retries/idempotence, stalled optional seeding, Pro intent ordering, existing subscribers, all six locales in light/dark at 320px and 1.6x text, sample lifecycle/localization, and notification permission decisions. Fourteen rendered golden references cover all chapters in both themes. Separate progress tests exercise the authentication/external-intent handoff policy.

Verified locally on 2026-09-12: 57 onboarding/adjacent regression tests, three sample-access tests proving no quota or AI access, and six golden renders passed. Focused static analysis passed. Android `prodRelease` compilation succeeded with `ENV=prod`; deployment configuration was not supplied, so this APK is not an installable acceptance candidate for the user's configured environment.

Revision verification on 2026-09-13: 40 focused onboarding/sample/permission tests and 12 light/dark golden renders passed; focused static analysis passed. A separate `ENV=dev` run passed 35 onboarding and existing Interests tests, including the unchanged AMOLED dashboard golden. These are local widget/render checks, not device frame-timing or authenticated purchase acceptance evidence.

Device acceptance must use a configured release build and a cold launch. Check first sharing/capture, actual enrichment, permission enable/deny/settings return, and purchase-screen cancellation. A release compiled without deployment defines is compilation evidence only; it must not replace a configured user installation.

## Real-save review

The production app (`com.shinrinyoku.glimpse`) was inspected on the connected DN2101. The open TempleOS save showed the full reader structure but was too technical for the neutral introduction. After the user chose travel or food, the existing “Authentic France · Lesser-Known Travel Destinations” save by @monsieur.jim was selected.

Source: https://www.instagram.com/reel/Db_Y5A2KZcY/ (verified through Open Original). Its observed enrichment includes a summary, three takeaways about lesser-known travel and overcrowding, and extracted destinations including Gorges du Tarn, Cascade de l’Éventail, and Abbaye de Moissac. The source does not have a Full explanation section, so the preview does not invent one. The Ask answer and Rediscover connection remain explicitly prepared/illustrative. No creator thumbnail is fabricated or substituted with the Kyoto image.

The bundled source has a unique demo fragment; saving the original URL is still a real user save. Existing Kyoto demo URLs remain recognized for labeling, quota isolation, and removal. Creator attribution is bundled with the sample. The shared transparent welcome artwork has softer ivory highlights for use on both light and dark canvases.

Real-save revision validation: 35 onboarding/sample/progress tests, 12 updated light/dark golden renders, focused static analysis, and diff whitespace checks passed. The existing production save was inspected on-device; the updated onboarding itself was verified through widget renders, not installed over the production app.

## Editorial spacing revision

Interests and discovered library items now have separate chapters, keeping organization before Search/Ask. Page gutters are 20px; preview surfaces are borderless with 18px insets. The primary action sits at the bottom safe area without a blank secondary-action row. Progress indicators use the same 280ms easing as navigation and respect reduced motion. Rediscover gives automatic connections and chosen revisits equal, simpler surfaces without repeated source metadata. Ask uses a conversational question in all six locales.

Editorial revision validation: 23 flow tests passed, including safe-area button placement across all seven chapters and retained category selection. All 14 light/dark golden renders were regenerated; focused analysis passed after removing the unused scene-spacing parameter. Device frame timing was not measured in this revision.

## Pinterest-inspired editorial direction

A working visual prototype establishes opening, reader, and Rediscover layouts. The common theme and larger, regular-weight Newsreader headlines apply across all seven chapters; other product scenes retain their existing structure. Reader and Rediscover use unboxed editorial sections. The opening uses a framed painted still life and a small existing mascot signature. No new motion or device performance claim is made in this pass.

Artwork: `assets/onboarding/editorial.webp`, generated with the built-in image tool, resized to 1100px and encoded as WebP. The original remains in the generated-images directory. This is decorative artwork, not a photograph of the France source. Existing mascot files are preserved. `assets/fonts/Newsreader-Regular.ttf` comes from the official Google Fonts newsreader directory, with its OFL in `assets/licenses/newsreader-OFL.txt`, and is bundled for offline rendering.

Generation prompt:

> Create one premium editorial illustration for Glimpse, a reflective save-and-rediscover app. Landscape 3:2 composition, no text, no lettering, no UI, no logos. A sophisticated Pinterest-worthy mixed-media gouache and colored-pencil still life, printed on subtly textured warm ivory paper: an open unlettered book and two closed moss-sage books in the lower left, a small ochre ceramic bowl with a pear on the right, a slender leafy branch arching gently across the upper area, and a rectangular miniature painted landscape print resting behind the books showing a quiet blue-green river among softly layered hills. These are physical objects arranged naturally on a table, NOT floating icons. Restrained palette of dusty sage, warm ivory, muted olive, charcoal ink and tiny warm apricot details. Beautiful visible brushwork, tactile paper grain, asymmetrical composition, confident simple shapes, calm light and generous breathing room. Contemporary independent literary magazine cover illustration, tasteful and art-directed, not generic vector art, not photorealistic, no 3D clay, no ornate decoration, no borders. Artwork fills canvas naturally, no device mockup. It must work as a framed artwork against either a dark charcoal sage app canvas or a light cream app canvas. Supporting artwork only, not a depiction of a specific saved source.

Validation: 23 flow tests plus 14 light/dark renders passed, including six locales at large text sizes. Focused analysis passed. Review the opening, reader, and Rediscover renders as a visual direction; no updated APK was installed in this pass.

Placement/caption refinement: all 39 flow and visual checks passed; focused analysis passed. New installs default to the existing Lime app accent while persisted accent choices remain authoritative. Onboarding retains its curated sage palettes.


### Final composition refinement
Opening uses the new full-height portrait collage. Ask has a decorative still-life lead-in above the genuine conversation preview. Interests has small localized annotations over the three illustrated clusters. The second Rediscover card shows a chosen cooking revisit, distinct from the automatic Travel connection. Existing chapter order, footer, and plan behavior are preserved.
