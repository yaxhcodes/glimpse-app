import 'package:flutter_test/flutter_test.dart';
import 'package:glimpse/features/home/save_date_group.dart';

void main() {
  test('groups by local calendar date at each boundary', () {
    final now = DateTime(2026, 9, 22, 0, 5);
    final cases = {
      0: SaveDateGroup.today,
      1: SaveDateGroup.yesterday,
      2: SaveDateGroup.lastSevenDays,
      6: SaveDateGroup.lastSevenDays,
      7: SaveDateGroup.lastThirtyDays,
      29: SaveDateGroup.lastThirtyDays,
      30: SaveDateGroup.earlier,
      -1: SaveDateGroup.today,
    };
    for (final entry in cases.entries) {
      expect(
        SaveDateGroup.forDate(DateTime(2026, 9, 22 - entry.key, 23, 59), now),
        entry.value,
      );
    }
  });
}
