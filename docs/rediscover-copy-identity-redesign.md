# Rediscover Copy And Identity Redesign

## Philosophy

Rediscover should not name cards like categories. It should reconstruct a small story from the user's saves: what they were preparing for, what they paused, what they kept circling, and what might be useful today.

The copy system should use topics as evidence, not as the visible identity. "Protein recipes" can help choose a practical tone, but the card should read like "A Better Breakfast" or "Dinner You Already Planned." The user should recognize their own intent before they recognize the topic label.

Good Rediscover copy is:

- Specific without sounding generated.
- Short enough to scan.
- Behavioral before topical.
- Varied in rhythm across adjacent cards.
- Quiet and human, not poetic or motivational.

## Copy Pipeline

1. Start with a `RediscoverJourney`.
2. Infer a story domain from the journey title, primary save, categories, and tags.
3. Choose a `RediscoverMemoryPersonality` from the journey kind and domain.
4. Select a primary identity from a domain-specific writing bank using stable hashing.
5. Build the secondary description from save count, unopened count, domain noun, and the primary save.
6. Build the reason for today from behavior: recent momentum, forgotten intent, first-look gap, anniversary, or repeated pattern.
7. Build the suggested next step from the primary save and domain.
8. Render Home, Rediscover, notification, and future digest copy from the same identity object.

## How RediscoverMemory Influences Language

- `metadata.kind` decides the story shape: unfinished, forgotten, seasonal, goal, first look, or repeated pattern.
- `personality` decides the voice: practical memories sound useful, reflective memories sound quiet, adventurous memories sound open-ended, ambitious memories sound purposeful.
- `primaryTitle` gives the copy a concrete anchor.
- `saveCount` and `unopenedCount` support the description, not the headline.
- `topicKey` and `topicLabel` remain metadata and fallback context.

## Field Evaluation

Added:

- `RediscoverMemoryPersonality`: gives the renderer a durable voice signal.
- `RediscoverMemoryIdentity`: groups primary identity, secondary description, reason for today, and suggested next step.

Kept:

- `what`, `whyItMatters`, `whyNow`, and `encouragedAction` remain for compatibility, but now mirror the richer identity layers.
- `RediscoverMemoryEmotion` remains useful for ranking and coarse emotional intent.
- `RediscoverJourneyMetadata` remains the diagnostic and scoring source.

Not added yet:

- No LLM copy field. The local engine is deterministic, cheap, and testable.
- No persisted copy cache. The memory id is stable enough for deterministic variation.
- No user-editable card identity. That can come later if Rediscover supports explicit feedback.

## 100 Example Rediscover Titles

1. A Better Breakfast
2. Dinner You Already Planned
3. The Recipes You Nearly Tried
4. What You Meant to Cook
5. Quick Vegetarian Meals
6. Weeknight Meal Ideas
7. Indian Vegetarian Recipes
8. Easy Lunch Recipes
9. Healthy Dinner Recipes
10. Paneer Recipes
11. Flutter Development Notes
12. AI Engineering Notes
13. Local-First App Architecture
14. Offline Sync Notes
15. Riverpod Patterns
16. Startup Reading
17. Founder Advice
18. API Development Notes
19. Agent Skills
20. GenAI Career Notes
21. The Question Is Still Open
22. Understanding Consciousness
23. Stoic Principles
24. Critical Thinking Books
25. Argumentation Books
26. Hindu Philosophy
27. Independent Thought
28. Social Justice Critiques
29. Bhagavad Gita Notes
30. Personal Growth Ideas
31. Himalayan Treks
32. Himachal Travel
33. Ladakh Villages
34. Udaipur Heritage Walks
35. Nepal Travel
36. Kashmir Treks
37. Iceland Photography Spots
38. Offbeat India Travel
39. Weekend Treks
40. Mountain Travel
41. Natural Farming
42. Permaculture
43. Plant Biotechnology
44. Wildlife Notes
45. Wildlife Photography
46. Moose Documentaries
47. Animal Facts
48. Food Forests
49. Sustainable Agriculture
50. High-Protein Vegetarian Meals
51. Vegetarian Protein Sources
52. Better Breakfasts
53. Quick Wrap Recipes
54. Healthy Salads
55. Pantry Noodles
56. One-Pot Pasta
57. Indian Curry Recipes
58. Fitness Habits
59. Mental Health Habits
60. Nature for Anxiety
61. Photography References
62. Visual Design Notes
63. ASCII Art Tools
64. Writing Skills
65. Personal Branding
66. Content Marketing
67. Design Tools
68. Self-Education
69. Learning Reflections
70. Survivorship Bias
71. Quantum Mechanics
72. Human Adaptation
73. Natural History
74. Vedic Literature
75. Science Notes
76. Research References
77. Money Notes
78. Business Learning
79. GTM Career Notes
80. First 100 Users
81. Startup Launch Notes
82. Food Business Ideas
83. Manga To Read
84. Anime To Watch
85. Mind-Bending Movies
86. Netflix Movies
87. Rewatchable Films
88. Japanese Films
89. Bollywood Music
90. Movie Recommendations
91. Pogo Channel History
92. Life Advice for Your 20s
93. Career Development
94. Mindset Habits
95. Skill Development
96. Founder Growth
97. AI Sustainability
98. Data Center Water Use
99. Local AI Hardware
100. Open Source Agent Tools
