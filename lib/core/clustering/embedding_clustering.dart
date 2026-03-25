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

/// Merges clusters whose embedding centroids are very similar (reduces
/// over-splitting from greedy seed clustering).
List<List<int>> mergeClustersByCentroidCosine(
  List<List<int>> clusters,
  List<List<double>> embeddings, {
  double mergeThreshold = 0.60,
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

/// Threshold-based grouping: each cluster is built from seed [i] and all
/// unassigned [j] with similarity to [i] above [threshold].
///
/// [rows] must each include `embedding` as a [List] of numbers (isolate-safe).
/// Returns lists of indices into [rows], largest clusters first.
/// Singletons are kept (valid interests for small libraries).
List<List<int>> clusterUrlIndicesByCosine(List<Map<String, dynamic>> rows) {
  const threshold = 0.55;
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

  final clusters = <List<int>>[];
  final assigned = <int>{};
  final n = rows.length;

  for (var i = 0; i < n; i++) {
    if (assigned.contains(i)) continue;
    if (embeddings[i].isEmpty) continue;

    final cluster = <int>[i];
    assigned.add(i);
    for (var j = i + 1; j < n; j++) {
      if (assigned.contains(j)) continue;
      if (embeddings[j].isEmpty) continue;
      final sim = cosineSimilarityEmbedding(embeddings[i], embeddings[j]);
      if (sim > threshold) {
        cluster.add(j);
        assigned.add(j);
      }
    }
    clusters.add(cluster);
  }

  clusters.sort((a, b) => b.length.compareTo(a.length));
  return mergeClustersByCentroidCosine(clusters, embeddings);
}
