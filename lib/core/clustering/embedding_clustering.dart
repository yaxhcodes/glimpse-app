import 'dart:math';

/// Cosine similarity for equal-length vectors (0.0 if degenerate).
double cosineSimilarityEmbedding(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0;
  double dot = 0, normA = 0, normB = 0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  if (denom == 0) return 0;
  return dot / denom;
}

List<double>? _centroidForIndices(
  List<int> indices,
  List<List<double>> embeddings,
) {
  if (indices.isEmpty) return null;
  var dim = 0;
  for (final i in indices) {
    final e = embeddings[i];
    if (e.isNotEmpty) {
      dim = e.length;
      break;
    }
  }
  if (dim == 0) return null;

  final sum = List<double>.filled(dim, 0);
  var n = 0;
  for (final i in indices) {
    final e = embeddings[i];
    if (e.length != dim) continue;
    for (var k = 0; k < dim; k++) {
      sum[k] += e[k];
    }
    n++;
  }
  if (n == 0) return null;
  return sum.map((v) => v / n).toList();
}

/// Merges clusters whose embedding centroids are very similar.
List<List<int>> _mergeByCentroidCosine(
  List<List<int>> clusters,
  List<List<double>> embeddings, {
  required double mergeThreshold,
}) {
  if (clusters.length <= 1) return clusters;

  final centroids = clusters
      .map((c) => _centroidForIndices(c, embeddings))
      .toList();
  final merged = List<bool>.filled(clusters.length, false);
  final result = <List<int>>[];

  for (var i = 0; i < clusters.length; i++) {
    if (merged[i]) continue;
    final ci = centroids[i];
    if (ci == null || ci.isEmpty) {
      result.add(List<int>.from(clusters[i]));
      continue;
    }

    final combined = List<int>.from(clusters[i]);
    for (var j = i + 1; j < clusters.length; j++) {
      if (merged[j]) continue;
      final cj = centroids[j];
      if (cj == null || cj.isEmpty) continue;
      if (cosineSimilarityEmbedding(ci, cj) > mergeThreshold) {
        combined.addAll(clusters[j]);
        merged[j] = true;
      }
    }
    result.add(combined);
  }

  result.sort((a, b) => b.length.compareTo(a.length));
  return result;
}

/// Top-level clustering.
///
/// Embeddings of short social-media posts (Reels/Shorts with terse titles) are
/// too generically similar for a cosine threshold to separate topics on its own
/// — that is why cooking links kept landing inside a Dev Tools cluster. So we
/// first **hard-partition by broad topic category** (the human-meaningful
/// `categoryBucket` carried on each row: Technology, Food & Cooking, Education,
/// …) and only cluster by embedding *within* each bucket. Two different
/// categories can therefore never share a cluster, while embeddings still split
/// a busy bucket like Technology into AI Agents / Dev Tools / Website Growth.
///
/// [rows] must each include `embedding` (a [List] of numbers) and ideally a
/// `categoryBucket` string (rows without one fall into an 'Other' bucket).
/// Isolate-safe. Returns lists of indices into [rows], largest clusters first.
List<List<int>> clusterUrlIndicesByCosine(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return [];

  final embeddings = <List<double>>[];
  for (final r in rows) {
    final raw = r['embedding'];
    if (raw is! List || raw.isEmpty) {
      embeddings.add(const []);
    } else {
      embeddings.add(raw.map((e) => (e as num).toDouble()).toList());
    }
  }

  // Bucket row indices by broad category (preserves ascending order).
  final buckets = <String, List<int>>{};
  for (var i = 0; i < rows.length; i++) {
    if (embeddings[i].isEmpty) continue;
    final raw = (rows[i]['categoryBucket'] as String?)?.trim();
    final key = (raw == null || raw.isEmpty) ? 'Other' : raw;
    buckets.putIfAbsent(key, () => <int>[]).add(i);
  }

  final result = <List<int>>[];
  for (final indices in buckets.values) {
    result.addAll(_clusterWithinBucket(indices, embeddings));
  }
  result.sort((a, b) => b.length.compareTo(a.length));
  return result;
}

/// Greedy single-seed cosine clustering restricted to [indices] (global indices
/// into [embeddings], ascending), followed by a centroid merge. Runs inside one
/// category bucket so it only ever groups same-category items.
List<List<int>> _clusterWithinBucket(
  List<int> indices,
  List<List<double>> embeddings,
) {
  const threshold = 0.55;
  final clusters = <List<int>>[];
  final assigned = <int>{};

  for (var a = 0; a < indices.length; a++) {
    final i = indices[a];
    if (assigned.contains(i) || embeddings[i].isEmpty) continue;

    final cluster = <int>[i];
    assigned.add(i);
    for (var b = a + 1; b < indices.length; b++) {
      final j = indices[b];
      if (assigned.contains(j) || embeddings[j].isEmpty) continue;
      if (cosineSimilarityEmbedding(embeddings[i], embeddings[j]) > threshold) {
        cluster.add(j);
        assigned.add(j);
      }
    }
    clusters.add(cluster);
  }

  clusters.sort((a, b) => b.length.compareTo(a.length));
  return _mergeByCentroidCosine(clusters, embeddings, mergeThreshold: 0.60);
}

// ─── Sub-clustering ───────────────────────────────────────────────────────────

/// Minimum parent cluster size to attempt sub-clustering.
const int kMinParentSizeForSubClustering = 4;

/// Minimum URLs per sub-cluster for it to be considered meaningful.
/// Raised to 3 so a single outlier never forms its own spurious sub-group.
const int kMinSubClusterSize = 3;

/// Minimum number of valid sub-clusters to expose sub-structure.
const int kMinSubClusterCount = 2;

/// Maximum sub-clusters to surface per parent (keeps UI manageable).
const int kMaxSubClusters = 5;

/// If the largest sub-cluster contains more than this fraction of the parent,
/// the split is not meaningful — it just recreates the parent.
const double kMaxSubClusterDominanceRatio = 0.85;

// ─── k-means style sub-clustering ────────────────────────────────────────────
//
// Greedy-seed clustering (used at the top level) works well when items vary
// widely in topic. Inside an already-homogeneous parent cluster the pairwise
// similarities are all relatively high, so a greedy seed at any threshold
// either lumps everything together or fragments into singletons.
//
// Instead we use a lightweight k-means variant:
//   1. Pick k seed centroids by spreading maximally (furthest-first seeding).
//   2. Assign every item to its nearest centroid.
//   3. Recompute centroids and re-assign (up to maxIter iterations).
//   4. Accept the split only if it passes quality guards.
//
// We try k = 2 … kMax and keep the k that maximises inter-centroid distance
// (i.e. the split that creates the most distinct sub-groups).

List<double> _normalise(List<double> v) {
  double norm = 0;
  for (final x in v) {
    norm += x * x;
  }
  norm = sqrt(norm);
  if (norm == 0) return v;
  return v.map((x) => x / norm).toList();
}

/// Assigns each local index to the nearest centroid (by cosine similarity).
/// Returns a list of length [localN] with centroid indices 0…k-1.
List<int> _assign(
  int localN,
  List<List<double>> localEmb,
  List<List<double>> centroids,
) {
  final assignments = List<int>.filled(localN, 0);
  for (var i = 0; i < localN; i++) {
    if (localEmb[i].isEmpty) continue;
    var best = -2.0;
    var bestK = 0;
    for (var k = 0; k < centroids.length; k++) {
      final sim = cosineSimilarityEmbedding(localEmb[i], centroids[k]);
      if (sim > best) {
        best = sim;
        bestK = k;
      }
    }
    assignments[i] = bestK;
  }
  return assignments;
}

/// Recomputes the centroid for each cluster from current assignments.
List<List<double>?> _recomputeCentroids(
  int k,
  int localN,
  List<List<double>> localEmb,
  List<int> assignments,
) {
  final dim = localEmb.firstWhere((e) => e.isNotEmpty, orElse: () => []).length;
  if (dim == 0) return List.filled(k, null);

  final sums = List.generate(k, (_) => List<double>.filled(dim, 0));
  final counts = List<int>.filled(k, 0);

  for (var i = 0; i < localN; i++) {
    if (localEmb[i].length != dim) continue;
    final ki = assignments[i];
    for (var d = 0; d < dim; d++) {
      sums[ki][d] += localEmb[i][d];
    }
    counts[ki]++;
  }

  return List.generate(k, (ki) {
    if (counts[ki] == 0) return null;
    final c = sums[ki].map((v) => v / counts[ki]).toList();
    return _normalise(c);
  });
}

/// Furthest-first seeding: pick the first seed randomly (index 0 for
/// determinism), then each subsequent seed is the point furthest from
/// all already-chosen seeds.
List<List<double>> _kmeansPlusSeeds(
  int k,
  List<List<double>> localEmb,
  List<int> validIndices,
) {
  final seeds = <List<double>>[];
  seeds.add(_normalise(List<double>.from(localEmb[validIndices[0]])));

  while (seeds.length < k) {
    var worstSim = 2.0; // lower = further from all seeds
    var worstIdx = validIndices[0];

    for (final i in validIndices) {
      if (localEmb[i].isEmpty) continue;
      // Similarity to nearest existing seed
      var nearestSim = -2.0;
      for (final seed in seeds) {
        final s = cosineSimilarityEmbedding(localEmb[i], seed);
        if (s > nearestSim) nearestSim = s;
      }
      if (nearestSim < worstSim) {
        worstSim = nearestSim;
        worstIdx = i;
      }
    }
    seeds.add(_normalise(List<double>.from(localEmb[worstIdx])));
  }

  return seeds;
}

/// Runs k-means for a fixed k on the local embeddings.
/// Returns groups as local indices, or null if the run is degenerate.
List<List<int>>? _kmeansRun(
  int k,
  List<List<double>> localEmb,
  List<int> validIndices, {
  int maxIter = 10,
}) {
  if (validIndices.length < k) return null;

  var centroids = _kmeansPlusSeeds(k, localEmb, validIndices);
  var assignments = _assign(localEmb.length, localEmb, centroids);

  for (var iter = 0; iter < maxIter; iter++) {
    final newCentroidsNullable = _recomputeCentroids(
      k,
      localEmb.length,
      localEmb,
      assignments,
    );
    // If any centroid collapsed (empty group), abort this k.
    if (newCentroidsNullable.any((c) => c == null)) return null;
    final newCentroids = newCentroidsNullable.cast<List<double>>();

    final newAssignments = _assign(localEmb.length, localEmb, newCentroids);

    // Converged?
    var changed = false;
    for (var i = 0; i < assignments.length; i++) {
      if (assignments[i] != newAssignments[i]) {
        changed = true;
        break;
      }
    }
    centroids = newCentroids;
    assignments = newAssignments;
    if (!changed) break;
  }

  // Build groups.
  final groups = List.generate(k, (_) => <int>[]);
  for (var i = 0; i < localEmb.length; i++) {
    if (localEmb[i].isEmpty) continue;
    groups[assignments[i]].add(i);
  }

  return groups;
}

/// Mean pairwise inter-centroid distance (1 - cosine similarity) for a set
/// of groups. Higher = more distinct sub-clusters.
double _interCentroidDiversity(
  List<List<int>> groups,
  List<List<double>> localEmb,
) {
  final centroids = groups
      .map((g) => _centroidForIndices(g, localEmb))
      .whereType<List<double>>()
      .toList();
  if (centroids.length < 2) return 0;

  double total = 0;
  int pairs = 0;
  for (var i = 0; i < centroids.length; i++) {
    for (var j = i + 1; j < centroids.length; j++) {
      total += 1.0 - cosineSimilarityEmbedding(centroids[i], centroids[j]);
      pairs++;
    }
  }
  return pairs == 0 ? 0 : total / pairs;
}

/// Attempts to find meaningful sub-groups within a parent cluster using
/// a k-means approach.
///
/// [parentIndices] are global indices into [allEmbeddings].
/// Returns a list of lists of **global indices**, or `null` when no valid
/// sub-structure exists.
///
/// This function is isolate-safe (no Flutter imports).
List<List<int>>? subClusterIndices({
  required List<int> parentIndices,
  required List<List<double>> allEmbeddings,
}) {
  if (parentIndices.length < kMinParentSizeForSubClustering) return null;

  final localEmb = [for (final gi in parentIndices) allEmbeddings[gi]];
  final validIndices = [
    for (var i = 0; i < localEmb.length; i++)
      if (localEmb[i].isNotEmpty) i,
  ];

  if (validIndices.length < kMinParentSizeForSubClustering) return null;

  // Try k = 2 up to kMax; keep the split with the highest inter-centroid
  // diversity that still passes the size guards.
  final kMax = min(kMaxSubClusters, validIndices.length ~/ 2);
  if (kMax < kMinSubClusterCount) return null;

  List<List<int>>? bestGroups;
  var bestDiversity = 0.0;

  for (var k = kMinSubClusterCount; k <= kMax; k++) {
    // Run k-means a couple of times with different seeds (we use deterministic
    // furthest-first, so run once; more runs would need randomness).
    final groups = _kmeansRun(k, localEmb, validIndices);
    if (groups == null) continue;

    // Filter to groups with enough members.
    final valid = groups.where((g) => g.length >= kMinSubClusterSize).toList();
    if (valid.length < kMinSubClusterCount) continue;

    // Dominance guard: reject if one group eats almost everything.
    final maxSize = valid.map((g) => g.length).reduce(max);
    if (maxSize / parentIndices.length > kMaxSubClusterDominanceRatio) continue;

    // Quality: prefer the k with the most distinct centroids.
    final diversity = _interCentroidDiversity(valid, localEmb);
    if (diversity > bestDiversity) {
      bestDiversity = diversity;
      bestGroups = valid;
    }
  }

  if (bestGroups == null) return null;

  // Minimum diversity threshold: sub-clusters must be meaningfully different.
  // 0.08 = centroids must differ by ≥8% in cosine distance.
  // This prevents geographic sub-topics (e.g. Karnataka vs Himalayan) from
  // being split into separate sub-clusters when their embeddings are still
  // very close — they will be merged by the Gemini reassignment step instead.
  if (bestDiversity < 0.08) return null;

  // Convert local indices back to global indices.
  return [
    for (final group in bestGroups) [for (final li in group) parentIndices[li]],
  ];
}

// ─── Isolate entry point ──────────────────────────────────────────────────────

/// Isolate-safe entry point for sub-clustering all top-level clusters in one
/// compute() call.
///
/// Payload shape:
/// ```
/// {
///   'embeddings': List<List<double>>,  // one per URL (global index)
///   'clusters':   List<List<int>>,     // global indices per top-level cluster
/// }
/// ```
/// Returns `List<List<List<int>>?>` — outer list aligned with input clusters.
/// A null entry means no valid sub-structure was found for that cluster.
List<List<List<int>>?> computeSubClusters(Map<String, dynamic> payload) {
  final rawEmb = payload['embeddings'] as List<dynamic>;
  final embeddings = rawEmb
      .map(
        (e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
      )
      .toList();

  final rawClusters = payload['clusters'] as List<dynamic>;
  final clusters = rawClusters
      .map((c) => (c as List<dynamic>).map((i) => i as int).toList())
      .toList();

  return [
    for (final parentIndices in clusters)
      subClusterIndices(
        parentIndices: parentIndices,
        allEmbeddings: embeddings,
      ),
  ];
}
