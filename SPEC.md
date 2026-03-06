# URL Vault — Project Specification
> A Flutter mobile app for saving, auto-categorizing, and semantically searching URLs using an LLM.

---

## Overview

**URL Vault** lets users save any URL, then automatically categorizes it using an LLM (e.g., "🦎 Reptiles", "🌿 Plants", "🚀 Technology"). Users can also run semantic searches like *"show me everything about exotic pets"* and get relevant saved URLs back — even if the word "exotic pets" was never used.

Think of it as a smart bookmark manager with a brain.

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| **Framework** | Flutter (Dart) | Cross-platform iOS + Android, single codebase |
| **State Management** | Riverpod | Modern, testable, composable |
| **Local Database** | Isar (or Drift) | Fast local NoSQL/SQL with Flutter-first API |
| **LLM API** | Anthropic Claude API (`claude-haiku-4-5`) | Fast + cheap for categorization tasks |
| **HTTP** | Dio | Robust HTTP client with interceptors |
| **Embeddings / Semantic Search** | Anthropic embeddings or `voyage-3-lite` | Convert URL metadata → vectors for search |
| **Vector Storage** | SQLite + cosine similarity (local) | Keep it offline-friendly; no server needed |
| **Link Preview** | `any_link_preview` package | Fetch OG title, description, image from URL |
| **Navigation** | GoRouter | Declarative routing |

---

## Core Features

### 1. Save a URL
- User pastes or shares a URL into the app
- App fetches the page's Open Graph metadata (title, description, image)
- This metadata is sent to Claude for categorization
- URL is saved locally with: raw URL, title, description, thumbnail, category, tags, timestamp, embedding vector

### 2. Auto-Categorization (LLM)
- On save, send title + description to Claude with a prompt like:
  ```
  You are a content classifier. Given the title and description of a webpage, return:
  1. A short category label (e.g., "Plants", "Lizards", "Cooking", "Finance")
  2. An emoji that represents it
  3. 3–5 descriptive tags

  Title: {title}
  Description: {description}

  Respond in JSON only.
  ```
- Parse the JSON response and store: `category`, `emoji`, `tags[]`
- Categories are auto-generated — no fixed list. Claude decides.

### 3. Browse by Category
- Home screen shows grouped cards by category
- Tapping a category filters the list
- Each card shows: thumbnail, title, domain, tags, date saved

### 4. Semantic Search
- User types a natural language query: *"lizards that live in deserts"*
- The query is converted to an embedding vector
- Cosine similarity is computed against all stored URL embeddings
- Top N results are returned, ranked by relevance
- Works even if the query terms don't exactly match saved content

### 5. Manual Editing
- User can override the category/tags that Claude assigned
- User can add personal notes to any URL
- User can delete URLs

### 6. Share Sheet Integration (iOS & Android)
- Register the app as a share target
- User can share a URL from Safari/Chrome directly into URL Vault
- App opens, pre-fills the URL, and auto-processes it

---

## App Screens

```
/                   → HomeScreen (category grid + recent URLs)
/add                → AddUrlScreen (paste URL, trigger fetch + categorize)
/category/:name     → CategoryDetailScreen (filtered list)
/search             → SearchScreen (semantic query input + results)
/url/:id            → UrlDetailScreen (full info, notes, edit tags)
/settings           → SettingsScreen (API key input, theme, data export)
```

---

## Data Model

```dart
// isar / drift model
class SavedUrl {
  int id;
  String rawUrl;
  String domain;           // extracted from URL
  String title;            // from OG metadata
  String description;      // from OG metadata
  String? thumbnailUrl;    // from OG image
  String category;         // from Claude
  String categoryEmoji;    // from Claude
  List<String> tags;       // from Claude
  String? userNotes;       // user-added
  DateTime savedAt;
  List<double> embedding;  // vector for semantic search (e.g., 1024-dim)
}
```

---

## LLM Integration

### Categorization Flow
```
User pastes URL
    → fetch OG metadata (title + description)
    → POST to Claude API with structured prompt
    → parse JSON response { category, emoji, tags }
    → generate embedding for (title + description)
    → save all to local DB
```

### Embedding + Semantic Search Flow
```
User types search query
    → generate embedding for query text
    → load all URL embeddings from DB
    → compute cosine similarity for each
    → sort descending, return top 10
    → display results
```

### Cosine Similarity (Dart)
```dart
double cosineSimilarity(List<double> a, List<double> b) {
  double dot = 0, normA = 0, normB = 0;
  for (int i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dot / (sqrt(normA) * sqrt(normB));
}
```

---

## Project Structure

```
lib/
├── main.dart
├── app.dart                        # GoRouter setup, theme, Riverpod ProviderScope
│
├── features/
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── home_provider.dart
│   ├── add_url/
│   │   ├── add_url_screen.dart
│   │   └── add_url_provider.dart   # orchestrates fetch + LLM + save
│   ├── categories/
│   │   ├── category_screen.dart
│   │   └── category_provider.dart
│   ├── search/
│   │   ├── search_screen.dart
│   │   └── search_provider.dart    # handles semantic search logic
│   └── url_detail/
│       ├── url_detail_screen.dart
│       └── url_detail_provider.dart
│
├── core/
│   ├── models/
│   │   └── saved_url.dart          # data model
│   ├── database/
│   │   └── isar_service.dart       # CRUD + query methods
│   ├── services/
│   │   ├── llm_service.dart        # Claude API calls (categorize + embed)
│   │   ├── link_preview_service.dart  # OG metadata fetching
│   │   └── search_service.dart     # cosine similarity + ranking
│   └── providers/
│       └── service_providers.dart  # Riverpod providers for services
│
└── shared/
    ├── widgets/
    │   ├── url_card.dart
    │   ├── category_chip.dart
    │   └── loading_indicator.dart
    └── theme/
        └── app_theme.dart
```

---

## Key Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Database
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0

  # HTTP
  dio: ^5.4.0

  # Link preview
  any_link_preview: ^3.0.0

  # Navigation
  go_router: ^13.0.0

  # Utils
  url_launcher: ^6.2.0
  share_plus: ^7.2.0          # for share sheet
  receive_sharing_intent: ^1.8.0  # receive shared URLs

dev_dependencies:
  isar_generator: ^3.1.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
```

---

## Settings Screen

- **API Key input**: Store the Anthropic API key securely using `flutter_secure_storage`
- **Theme**: Light / Dark / System
- **Export data**: Export all saved URLs as JSON or CSV
- **Clear all data**: Wipe local DB

---

## Error Handling

| Scenario | Behavior |
|---|---|
| No internet when saving | Show error, allow retry; save without metadata as fallback |
| LLM API fails | Save URL with category = "Uncategorized", allow user to re-run categorization later |
| Invalid URL | Show inline validation error on input |
| OG metadata missing | Use domain name as title fallback |

---

## Phase 1 MVP (Build First)

1. ✅ Save URL manually (paste input)
2. ✅ Fetch OG metadata
3. ✅ Claude categorization
4. ✅ Local DB with Isar
5. ✅ Home screen with category groups
6. ✅ URL detail screen
7. ✅ Basic keyword search (SQLite LIKE query)

## Phase 2

8. ⬜ Embedding-based semantic search
9. ⬜ Share sheet integration
10. ⬜ Manual tag/category override

## Phase 3

11. ⬜ Collections / folders (user-defined groups)
12. ⬜ Bulk import (paste multiple URLs)
13. ⬜ iCloud / Google Drive sync
14. ⬜ Widget (iOS/Android) for quick-add

---

## Notes for Copilot

- Always use `AsyncValue` from Riverpod for loading/error/data states in providers
- Use `@riverpod` code generation annotations where possible
- Claude API key should never be hardcoded — read from `flutter_secure_storage`
- All Claude API calls go through `LlmService` — no direct API calls in UI layer
- Isar collections require `@collection` annotation and code generation via `build_runner`
- Embeddings are stored as `List<double>` — Isar supports this natively
- Use `compute()` for cosine similarity over large URL sets to avoid blocking the UI thread
- The `any_link_preview` package may fail on some URLs — always wrap in try/catch and use fallbacks