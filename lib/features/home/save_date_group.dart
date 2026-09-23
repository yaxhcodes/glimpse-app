enum SaveDateGroup {
  today,
  yesterday,
  lastSevenDays,
  lastThirtyDays,
  earlier;

  static SaveDateGroup forDate(DateTime savedAt, DateTime now) {
    final saved = savedAt.toLocal();
    final current = now.toLocal();
    final age = DateTime.utc(
      current.year,
      current.month,
      current.day,
    ).difference(DateTime.utc(saved.year, saved.month, saved.day)).inDays;
    if (age <= 0) return today;
    if (age == 1) return yesterday;
    if (age < 7) return lastSevenDays;
    if (age < 30) return lastThirtyDays;
    return earlier;
  }
}
