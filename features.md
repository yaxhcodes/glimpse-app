# Glimpse Feature Architecture

## Already Implemented

These features already exist in some form and should be preserved while the memory system evolves.

- Save URLs from across the internet.
- Support for Instagram Reels, TikToks, YouTube videos, X posts, articles, recipes, GitHub repositories, and websites.
- AI enrichment with title, summary, category, tags, thumbnail, source metadata, creator metadata, transcript, or caption when available.
- Saved URL detail screens.
- Add URL flow with duplicate handling.
- Share-menu save flow.
- Background enrichment after capture.
- Notification path for saved URL capture and enrichment.
- Recipe-aware enrichment and detail behavior.
- Ask Glimpse for saved content.
- Collections and add-to-collection flows.
- Selection mode and bulk actions for saved items.
- Tag-based search and related-save routing.

## Immediate Implementation

These are the highest-leverage features to build next.

### 1. Intent Extraction

Add a durable intent layer to every enriched save.

Initial fields:

```text
primary_intent
secondary_intents
intent_confidence
life_area
why_saved_hypothesis
```

Example:

```text
primary_intent: visit
secondary_intents: [inspiration]
life_area: travel
why_saved_hypothesis: The user may be considering a future New Zealand trip.
```

### 2. Specialized Content Metadata

Extend enrichment beyond generic summaries.

Add metadata where applicable:

```text
actionability
time_required
cost_level
difficulty
skill_level
location
ingredients
tools
steps
creator_type
freshness_sensitivity
evergreen_score
```

This should support recipes, travel, learning resources, business ideas, GitHub repositories, and product/tool recommendations.

### 3. Smart Goal Clusters

Create AI-assisted clusters from repeated saves.

Examples:

- `Visit Japan`
- `Learn Flutter`
- `Cook healthier meals`
- `Build an AI startup`
- `Explore wildlife conservation`

Cluster inputs:

- intent
- semantic similarity
- entities
- tags
- recency
- repeated source patterns
- user interactions

### 4. Rediscovery Loop

Build a daily and weekly resurfacing system.

Daily resurfacing:

- One save.
- One reason.
- One action.

Weekly resurfacing:

- Cluster recap.
- Dormant goal prompt.
- Repeated-interest insight.

Example copy:

```text
You saved 4 Japan ideas this month. This Kyoto itinerary is the most actionable one.
```

### 5. Hybrid Search

Upgrade search to combine:

- keyword match
- semantic match
- intent filters
- content-type filters
- entity filters
- time parsing

Target queries:

- `Wildlife`
- `Things I wanted to learn`
- `That recipe with mushrooms`
- `Business ideas from 6 months ago`

### 6. Canonical Tag Normalization

Normalize synonymous AI tags into canonical concepts.

Example:

```text
ai startup
startup idea
agent startup
```

Canonical concept:

```text
build_ai_startup
```

Visible tags should remain clean and few. Hidden semantic tags can stay rich and retrieval-oriented.

### 7. Focused Ask Modes

Make Ask Glimpse explicitly scoped.

Modes:

- Ask about this save.
- Ask about this goal.
- Ask about this collection.
- Ask across all saves.

This prevents broad memory retrieval from weakening focused answers.

### 8. Memory Lifecycle State

Track the state of each save.

```text
captured
understood
clustered
resurfaced
acted_on
dismissed
archived
```

This helps Glimpse distinguish saved content that is still useful from content that should fade into the background.

## Implement Later

These are valuable, but should wait until the intent and rediscovery loops are working.

### Advanced Graph Visualization

A visual knowledge graph could become compelling once the graph has enough high-quality nodes and relationships. It should not be built before the underlying graph is useful.

### Calendar Integration

Useful for travel planning, recipes, events, learning plans, and reminders. This should come after goal clusters and lifecycle states.

### Public Collection Publishing

Useful for creators and power users, but risky before private memory quality is strong.

### Imports

Potential importers:

- Pocket
- Raindrop
- Notion
- Pinterest
- browser bookmarks

Imports are useful for growth, but can flood the system with low-intent legacy data if built too early.

### Collaborative Collections

Useful for trips, meal planning, research, and shared projects. This should come after single-user collections and smart clusters feel excellent.

### Annual Memory Review

Create a reflective yearly summary of saved intentions, recurring interests, trips, skills, recipes, and ideas.

### Browser Extension Power Workflows

Useful for desktop-heavy users, especially researchers and founders. Mobile/social capture should remain the core wedge.

## Never Build

These features may look attractive but would weaken the product.

- Folder trees as the primary organization model.
- User-managed category taxonomies.
- Tag editing as a central workflow.
- Inbox-zero mechanics for saved content.
- Generic AI chat over all saves without clear scope.
- Public social feeds.
- Follower graphs.
- Gamified streaks for processing saves.
- Complex dashboards before rediscovery is useful.
- Automatic save-everything capture before trust and relevance are solved.

## Implementation Order

Recommended first sequence:

1. Add intent and life-area metadata to enrichment.
2. Store hidden semantic metadata in the durable enrichment payload.
3. Build canonical tag normalization.
4. Create first-pass goal cluster detection.
5. Add daily rediscovery from goal clusters and high-actionability saves.
6. Upgrade search to understand intent, entities, content type, and time.
7. Add focused Ask modes for save, goal, collection, and all memory.

The implementation should favor hidden metadata and quiet product intelligence before adding heavy new UI.
