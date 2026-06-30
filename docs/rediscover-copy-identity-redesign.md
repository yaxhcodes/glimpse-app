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
5. A Small Dinner Rescue
6. The Meal Plan Taking Shape
7. The Kitchen Thread Continues
8. Meals Still on the Shelf
9. A Practical Meal Plan
10. The Food Thread You Started
11. The Project You Kept Preparing For
12. Your Build Notes Are Still Here
13. The Workbench Is Ready
14. The Idea You Parked
15. The Thing You Wanted to Make
16. A Build Goal With Receipts
17. The Stack You Were Studying
18. The Tools Keep Reappearing
19. The First Build Step
20. The Plan Is Still Usable
21. The Question Is Still Open
22. A Thought You Kept Following
23. The Questions You Put Down
24. A Thought Worth Picking Up
25. The Note That Still Asks Something
26. A Practice You Meant to Keep
27. Something You Were Wrestling With
28. The Questions You Kept Collecting
29. A Line of Thought
30. The Idea Trail
31. The Trip You Started Sketching
32. The Route Keeps Growing
33. Planning Another Way Out
34. A Route You Left Behind
35. The Place You Meant to Revisit
36. The First Stop Is Still There
37. A Map You Already Started
38. The Places Keep Lining Up
39. A Small Escape Plan
40. The Map in Your Saves
41. The Green Notebook Grows
42. Still Learning the Land
43. The Living Thread Continues
44. The Nature Notes You Forgot
45. A Quieter Kind of Research
46. The Field Notes Are Still Here
47. The Living Things Notebook
48. A Small Return to Nature
49. The Outdoor Thread
50. The Routine You Were Testing
51. A Health Plan With Evidence
52. The Stronger Week
53. The Routine You Put Aside
54. A Useful Reset
55. The Health Notes Waiting
56. A Better Baseline
57. The Experiment With Energy
58. The Training Thread
59. The Idea Still Has Shape
60. The Creative Thread Continues
61. Something You Could Make
62. The Idea You Almost Used
63. A Draft Still Waiting
64. The Reference Stack
65. A Spark You Saved
66. The Moodboard Has a Point
67. The Thing You Might Make
68. The Lesson Continues
69. You Were Building Context
70. The Study Trail Is Warm
71. The Lesson You Parked
72. A Useful Explainer Returned
73. The Research Stack
74. The Thing You Wanted to Understand
75. A Thread Worth Finishing
76. The Learning Curve
77. A More Boring Money Plan
78. The Practical Finance Stack
79. A Decision You Were Preparing For
80. The Money Notes You Saved
81. A Practical Check-In
82. The Decision File
83. The Watchlist With a Reason
84. What You Meant to Watch
85. A Story You Saved for Later
86. An Old Watchlist Note
87. Something You Once Wanted to See
88. The Story Came Back
89. The Next Thing to Watch
90. A Queue With Taste
91. The Story Thread
92. A Quiet Save Worth Opening
93. The Thing You Left for Later
94. A Small Return
95. The Thread You Were Building
96. This Was Becoming Something
97. You Were Onto Something Here
98. A Goal Hiding in Plain Sight
99. Saved, But Never Started
100. There Is a Pattern Here
