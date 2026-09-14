/// App-computed markbook math (not official Neptun KKI/GPA).
///
/// **Átlag / Average** = Σ(grade × credit) / Σ(credit) for completed subjects with grade ≥ 2.
/// **/30** = Σ(grade × credit) / 30 (same numerator — not átlag÷30).
class MarkbookMath {
  MarkbookMath._();

  /// Σ(grade × credit) for rows with grade ≥ 2 and credit > 0.
  static double gradeCreditNumerator({
    required Iterable<int> grades,
    required Iterable<int> credits,
  }) {
    final g = grades.toList();
    final c = credits.toList();
    assert(g.length == c.length);
    double numerator = 0;
    for (int i = 0; i < g.length; i++) {
      if (g[i] >= 2 && c[i] > 0) {
        numerator += g[i] * c[i];
      }
    }
    return numerator;
  }

  /// Σ(credit) for rows with grade ≥ 2 and credit > 0.
  static int countingCreditSum({
    required Iterable<int> grades,
    required Iterable<int> credits,
  }) {
    final g = grades.toList();
    final c = credits.toList();
    assert(g.length == c.length);
    int creditSum = 0;
    for (int i = 0; i < g.length; i++) {
      if (g[i] >= 2 && c[i] > 0) {
        creditSum += c[i];
      }
    }
    return creditSum;
  }

  /// Credit-weighted átlag = Σ(grade × credit) / Σ(credit).
  static double weightedAvg({
    required Iterable<int> grades,
    required Iterable<int> credits,
  }) {
    final creditSum = countingCreditSum(grades: grades, credits: credits);
    if (creditSum <= 0) return double.nan;
    return gradeCreditNumerator(grades: grades, credits: credits) / creditSum;
  }

  /// /30 index = Σ(grade × credit) / 30 (not átlag÷30).
  static double index30({
    required Iterable<int> grades,
    required Iterable<int> credits,
  }) {
    return gradeCreditNumerator(grades: grades, credits: credits) / 30.0;
  }

  /// Credit-weighted átlag and /30 from completed graded subjects.
  static ({double average, double per30, int creditSum}) fromCompleted({
    required Iterable<int> grades,
    required Iterable<int> credits,
  }) {
    final creditSum = countingCreditSum(grades: grades, credits: credits);
    final average = weightedAvg(grades: grades, credits: credits);
    final per30 = index30(grades: grades, credits: credits);
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

  /// Minimum integer grade in 2..5 on [subjectCredit] to reach [targetAvg]
  /// with the same weighted-átlag formula (grades &lt; 2 do not count).
  ///
  /// Returns:
  /// - `0` if already at/above target without this subject (or any counting grade works),
  /// - `2`–`5` for the minimum needed grade,
  /// - `null` if even a 5 cannot reach the target, or inputs are invalid.
  static int? minGradeForTargetAvg({
    required Iterable<int> otherGrades,
    required Iterable<int> otherCredits,
    required int subjectCredit,
    required double targetAvg,
  }) {
    if (subjectCredit <= 0 || targetAvg.isNaN || targetAvg <= 0) {
      return null;
    }
    final baseAvg = weightedAvg(grades: otherGrades, credits: otherCredits);
    if (!baseAvg.isNaN && baseAvg >= targetAvg) {
      return 0;
    }
    for (int grade = 2; grade <= 5; grade++) {
      final avg = weightedAvg(
        grades: [...otherGrades, grade],
        credits: [...otherCredits, subjectCredit],
      );
      if (!avg.isNaN && avg >= targetAvg) {
        return grade;
      }
    }
    return null;
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

/// Snapshot for ghost-grade what-if preview (popup mode 0).
/// Set from markbook before opening the ghost popup.
class GhostGradePopupData {
  static List<int> otherGrades = <int>[];
  static List<int> otherCredits = <int>[];
  static int subjectCredit = 0;
  static int existingGhostGrade = -1;

  static void set({
    required List<int> otherGrades,
    required List<int> otherCredits,
    required int subjectCredit,
    int existingGhostGrade = -1,
  }) {
    GhostGradePopupData.otherGrades = List<int>.from(otherGrades);
    GhostGradePopupData.otherCredits = List<int>.from(otherCredits);
    GhostGradePopupData.subjectCredit = subjectCredit;
    GhostGradePopupData.existingGhostGrade = existingGhostGrade;
  }

  static void clear() {
    otherGrades = <int>[];
    otherCredits = <int>[];
    subjectCredit = 0;
    existingGhostGrade = -1;
  }

  static ({double average, double per30}) previewForGrade(int grade) {
    return (
      average: MarkbookMath.weightedAvg(
        grades: [...otherGrades, grade],
        credits: [...otherCredits, subjectCredit],
      ),
      per30: MarkbookMath.index30(
        grades: [...otherGrades, grade],
        credits: [...otherCredits, subjectCredit],
      ),
    );
  }

  static int? minGradeForTarget(double targetAvg) {
    return MarkbookMath.minGradeForTargetAvg(
      otherGrades: otherGrades,
      otherCredits: otherCredits,
      subjectCredit: subjectCredit,
      targetAvg: targetAvg,
    );
  }
}
