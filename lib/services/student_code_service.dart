import 'package:supabase_flutter/supabase_flutter.dart';

/// Prefix and fixed numeric suffix width of a student-code series, e.g.
/// prefix `H6` and width 4 produce codes such as `H60013`.
class StudentCodeFormat {
  final String prefix;
  final int suffixWidth;

  const StudentCodeFormat(this.prefix, this.suffixWidth);

  RegExp get pattern =>
      RegExp('^${RegExp.escape(prefix)}([0-9]{$suffixWidth})\$');
}

class StudentCodeGenerationException implements Exception {
  final String reason;
  const StudentCodeGenerationException(this.reason);

  @override
  String toString() => 'StudentCodeGenerationException: $reason';
}

class StudentCodeService {
  static const int pageSize = 1000;
  static const int maxRetries = 3;
  static const String uniqueConstraintName = 'Students_Student_Code_key';

  /// Groups whose codes belong to a confirmed series shared across groups
  /// (students keep their code when transferred). Every other group keeps the
  /// original per-group numbering in [buildLegacyNextCode].
  static const Map<int, StudentCodeFormat> seriesByGroupId = {
    14: StudentCodeFormat('H6', 4), // حصون٦
  };

  static StudentCodeFormat? seriesForGroup(dynamic groupId) {
    final id = groupId is int ? groupId : int.tryParse('$groupId');
    return id == null ? null : seriesByGroupId[id];
  }

  /// The original numbering logic, unchanged: highest numeric suffix among
  /// the given codes, incremented with the same prefix and padding. Returns
  /// null when no code has the letters-then-digits format.
  static String? buildLegacyNextCode(List<dynamic> existingCodes) {
    final pattern = RegExp(r'^([A-Za-z]+)(\d+)$');

    String? bestPrefix;
    int bestSequence = -1;
    int bestWidth = 0;

    for (final raw in existingCodes) {
      final code = (raw ?? '').toString().trim();
      if (code.isEmpty) continue;

      final match = pattern.firstMatch(code);
      if (match == null) continue;

      final prefix = match.group(1)!;
      final digits = match.group(2)!;
      final sequence = int.tryParse(digits);
      if (sequence == null) continue;

      if (sequence > bestSequence) {
        bestSequence = sequence;
        bestPrefix = prefix;
        bestWidth = digits.length;
      }
    }

    if (bestPrefix == null) {
      return null;
    }

    final nextSequence = bestSequence + 1;
    final nextDigits = nextSequence.toString().padLeft(bestWidth, '0');
    return '$bestPrefix$nextDigits';
  }

  /// Highest valid suffix + 1 for a series, zero-padded to its width. Codes
  /// not matching the exact prefix and suffix width are ignored.
  static String nextSeriesCode(StudentCodeFormat format, Iterable<String> codes) {
    final pattern = format.pattern;
    int? highest;
    for (final raw in codes) {
      final match = pattern.firstMatch(raw.trim());
      if (match == null) continue;
      final value = int.parse(match.group(1)!);
      if (highest == null || value > highest) highest = value;
    }
    if (highest == null) {
      throw const StudentCodeGenerationException('no existing codes in series');
    }

    var limit = 1;
    for (var i = 0; i < format.suffixWidth; i++) {
      limit *= 10;
    }
    final next = highest + 1;
    if (next >= limit) {
      throw const StudentCodeGenerationException('suffix width exhausted');
    }
    return '${format.prefix}${next.toString().padLeft(format.suffixWidth, '0')}';
  }

  /// Every Student_Code starting with [prefix], whatever the student's group,
  /// read page by page until the server returns no more rows.
  static Future<List<String>> fetchSeriesCodes(
    dynamic client,
    String prefix,
  ) async {
    final codes = <String>[];
    var offset = 0;
    while (true) {
      final response = await client
          .from('Students')
          .select('Student_Code')
          .like('Student_Code', '$prefix%')
          .order('Student_Code', ascending: true)
          .range(offset, offset + pageSize - 1);
      if (response is! List || response.isEmpty) break;
      for (final row in response) {
        final code = (row as Map)['Student_Code'];
        if (code != null) codes.add(code.toString());
      }
      offset += response.length;
    }
    return codes;
  }

  /// The original per-group query.
  static Future<List<dynamic>> fetchGroupCodes(
    dynamic client,
    dynamic groupId,
  ) async {
    final response = await client
        .from('Students')
        .select('Student_Code')
        .eq('Group_id', groupId);
    return response is List
        ? response.map((r) => (r as Map<String, dynamic>)['Student_Code']).toList()
        : <dynamic>[];
  }

  static bool isStudentCodeConflict(Object error) {
    if (error is! PostgrestException || error.code != '23505') return false;
    final text = '${error.message} ${error.details} ${error.hint}';
    return text.contains(uniqueConstraintName);
  }

  /// Inserts the student with an automatically generated code and returns it,
  /// or returns null (inserting nothing) when the group has no automatic
  /// numbering and the caller must ask for a manual code.
  ///
  /// If the insert fails on the Student_Code unique constraint, the candidate
  /// is recalculated from the latest codes (series groups) or advanced
  /// beyond the rejected codes (other groups), up to [maxRetries] times.
  /// Other errors are rethrown without retrying.
  static Future<String?> insertWithAutomaticCode({
    required dynamic client,
    required Map<String, dynamic> studentData,
    required dynamic groupId,
  }) async {
    final series = seriesForGroup(groupId);
    List<dynamic>? groupCodes;
    if (series == null) {
      groupCodes = await fetchGroupCodes(client, groupId);
      if (buildLegacyNextCode(groupCodes) == null) return null;
    }

    final rejected = <String>[];
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final String code;
      if (series != null) {
        code = nextSeriesCode(series, await fetchSeriesCodes(client, series.prefix));
      } else {
        if (attempt > 0) groupCodes = await fetchGroupCodes(client, groupId);
        final next = buildLegacyNextCode([...groupCodes!, ...rejected]);
        if (next == null) {
          throw const StudentCodeGenerationException('no numbering available');
        }
        code = next;
      }

      try {
        await client.from('Students').insert({
          ...studentData,
          'Student_Code': code,
        });
        return code;
      } on PostgrestException catch (error) {
        if (!isStudentCodeConflict(error)) rethrow;
        rejected.add(code);
      }
    }
    throw const StudentCodeGenerationException('retries exhausted');
  }
}
