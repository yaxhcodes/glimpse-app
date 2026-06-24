import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/memory_goal_service.dart';
import '../home/home_provider.dart';

final memoryGoalsProvider = FutureProvider<List<MemoryGoal>>((ref) async {
  ref.watch(
    urlStreamProvider.select(
      (async) => async.whenOrNull(data: (urls) => urls.length),
    ),
  );

  final urls = await ref.read(urlStreamProvider.future);
  return MemoryGoalService.buildGoals(urls);
});
