/// App-computed markbook math (not official Neptun KKI/GPA).
///
/// **Átlag / Average** = Σ(grade × credit) / Σ(credit) for completed subjects with grade ≥ 2.
/// **/30** = Σ(grade × credit) / 30 (same numerator — not átlag÷30).
class MarkbookMath {
  MarkbookMath._();

  /// Credit-weighted átlag and /30 from completed graded subjects.
  static ({double average, double per30, int creditSum}) fromCompleted({
    required Iterable<int> grades,
    required Iterable<int> credits,
  }) {
    final g = grades.toList();
    final c = credits.toList();
    assert(g.length == c.length);
    double numerator = 0;
    int creditSum = 0;
    for (int i = 0; i < g.length; i++) {
      if (g[i] >= 2 && c[i] > 0) {
        numerator += g[i] * c[i];
        creditSum += c[i];
      }
    }
    final average = creditSum > 0 ? numerator / creditSum : double.nan;
    final per30 = numerator / 30.0;
    return (average: average, per30: per30, creditSum: creditSum);
  }

  /// Same formulas; [effectiveGrade] already picks real grade or ghost for each row.
  static ({double average, double per30}) fromEffectiveGrades({
    required Iterable<int> effectiveGrades,
    required Iterable<int> credits,
  }) {
    final r = fromCompleted(grades: effectiveGrades, credits: credits);
    return (average: r.average, per30: r.per30);
  }

  /// Sum of completed credits across terms, deduped by [subjectCode]
  /// (non-empty codes preferred; empty codes counted separately by name+credit).
  static int accumulatedCompletedCredits(
    Iterable<({String subjectCode, String name, int credit, bool completed, int grade})> rows,
  ) {
    final seenCodes = <String>{};
    final seenNameless = <String>{};
    int total = 0;
    for (final row in rows) {
      if (!row.completed || row.credit <= 0) continue;
      // Prefer graded completes; still count completed with grade 0 (signed).
      final code = row.subjectCode.trim();
      if (code.isNotEmpty) {
        if (seenCodes.contains(code)) continue;
        seenCodes.add(code);
        total += row.credit;
      } else {
        final key = '${row.name}|${row.credit}';
        if (seenNameless.contains(key)) continue;
        seenNameless.add(key);
        total += row.credit;
      }
    }
    return total;
  }
}
