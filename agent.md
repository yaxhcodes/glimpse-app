# Glimpse Agent Architecture

## Product Thesis

Glimpse is an intention-aware memory layer for the saved internet.

Users are not only saving information. They are saving possible futures: places they may visit, meals they may cook, skills they may learn, products they may buy, companies they may build, and identities they may move toward.

The agent layer should therefore optimize for intention recovery, rediscovery, and action readiness rather than bookmark filing.

## Core Agent Responsibilities

The Glimpse agent should do five jobs for every save:

1. Understand what the saved item is.
2. Infer why the user may have saved it.
3. Connect it to related saves, entities, goals, and interests.
4. Resurface it when it is likely to be useful again.
5. Help the user act on it without forcing manual organization.

## Memory Object Model

Every saved item should become a memory object.

```text
save_id
source_url
surface
content_type
title
summary
thumbnail
creator
source_metadata
transcript_or_caption
entities
topics
intent
life_area
actionability
time_horizon
effort_level
cost_level
difficulty
skill_level
location
tools
ingredients
steps
goal_candidates
resurfacing_hooks
why_saved_hypothesis
confidence_by_field
status
last_resurfaced_at
user_feedback_signals
```

## Intent Taxonomy

Intent is more important than category.

Initial supported intents:

- `learn`
- `visit`
- `cook`
- `build`
- `buy`
- `try`
- `watch_later`
- `read_later`
- `reference`
- `career_move`
- `health_change`
- `inspiration`
- `share`

The agent should treat intent as probabilistic. It can store a primary intent, secondary intents, and confidence scores.

## Goal Detection

Goals emerge when multiple saves share intent, entities, topics, or action patterns.

Examples:

- Saves about Queenstown, Milford Sound, and New Zealand road trips become `Visit New Zealand`.
- Saves about Flutter tutorials, Dart packages, and mobile UI patterns become `Learn Flutter`.
- Saves about healthy lunches, air fryer dinners, and high-protein breakfasts become `Cook healthier meals`.
- Saves about AI agents, startup funding, and product demos become `Build an AI startup`.

Goal clusters should include:

```text
goal_id
name
intent
life_area
supporting_save_ids
key_entities
confidence
recency
strength
status
next_useful_action
last_resurfaced_at
```

## Knowledge Graph

The graph should include more than saves.

Node types:

- Save
- Entity
- Topic
- Intent
- Goal
- Collection
- Creator
- Location
- Skill
- Recipe
- Tool
- Product
- Source
- Time Period
- User Action

Relationship examples:

```text
Save mentions Entity
Save implies Intent
Save supports Goal
Save belongs_to Collection
Save from Creator
Save about Location
Save requires Skill
Save similar_to Save
Goal contains Save
Goal related_to Interest
Interest strengthens_over_time
Interest decays_over_time
```

## Tag Architecture

Tags should be AI-generated, normalized, and split into two layers.

Visible tags:

- High-confidence.
- Human-readable.
- Limited in number.
- Useful for browsing and recognition.

Hidden semantic tags:

- Used for retrieval, clustering, and recommendations.
- Can include noisy or technical concepts users should not see.
- Should include aliases and canonical IDs.

Example:

```text
canonical_tag: japan_travel
visible_label: Japan travel
aliases:
  - tokyo trip
  - kyoto itinerary
  - japan itinerary
type: destination_interest
```

The agent should suppress platform fallback tags like `instagram`, `tiktok`, `x`, and `social` when they would pollute user-interest modeling.

## Categories

Categories should exist as infrastructure, not as the primary user-facing model.

Recommended broad categories:

- Learn
- Cook
- Travel
- Build
- Buy
- Watch
- Read
- Career
- Health
- Home
- Finance
- Inspiration
- Reference

The app should expose views and prompts derived from categories rather than asking users to manage categories directly.

## Rediscovery Agent

Rediscovery is a first-class product loop.

Daily rediscovery:

- One useful saved item.
- One short reason it matters now.
- One action.

Weekly rediscovery:

- Cluster-level recap.
- Repeated interests.
- Dormant goals with recent relevance.

Monthly rediscovery:

- Intent review.
- Growing and fading interests.
- Saves that became more relevant with time.

Long-forgotten rediscovery:

- Old saves resurfaced with context.
- Strongest when connected to a current interest or repeated pattern.

## Search Agent

Search should be hybrid:

- Keyword for exact matches.
- Semantic for vague memory.
- Structured filters for intent, content type, time, location, ingredients, and entities.
- Temporal reasoning for queries like `business ideas from 6 months ago`.

Search should return clustered, explainable results rather than only a flat list.

## Ask Agent

Ask Glimpse should support scoped modes:

- One selected save.
- One smart goal.
- One collection.
- All memory.

The selected-save mode should be focused and should not leak unrelated attached URL context into the conversation.

## Feedback Signals

The agent should learn from lightweight signals:

- Opened after resurfacing.
- Dismissed.
- Marked done.
- Added to collection.
- Asked about.
- Shared.
- Edited note.
- Repeated saves in a cluster.

Feedback should tune resurfacing and goal strength without forcing the user to manually curate the archive.

## Design Principle

The agent should never make the user feel like a librarian.

Its job is to quietly turn saved fragments into remembered intentions.
