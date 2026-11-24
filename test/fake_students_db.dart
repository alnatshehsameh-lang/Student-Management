import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosoon_academy/services/student_code_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local test double only: models the Students table, its Student_Code unique
// constraint, the PostgREST row cap and a concurrent writer. No database is
// contacted.
class FakeStudentsDb {
  final List<Map<String, dynamic>> rows;
  int maxRows;
  int insertCalls = 0;
  void Function(String code)? beforeInsert;
  PostgrestException? forcedError;

  FakeStudentsDb(this.rows, {this.maxRows = 1000});

  static PostgrestException duplicate([
    String constraint = StudentCodeService.uniqueConstraintName,
  ]) => PostgrestException(
    message: 'duplicate key value violates unique constraint "$constraint"',
    code: '23505',
  );

  dynamic from(String table) {
    expect(table, 'Students');
    return FakeStudentsTable(this);
  }
}

class FakeStudentsTable {
  final FakeStudentsDb db;
  FakeStudentsTable(this.db);

  FakeStudentsQuery select(String columns) {
    expect(columns, 'Student_Code');
    return FakeStudentsQuery(db);
  }

  Future<void> insert(Map<String, dynamic> data) async {
    db.insertCalls++;
    final code = data['Student_Code'] as String;
    db.beforeInsert?.call(code);
    if (db.forcedError != null) throw db.forcedError!;
    if (db.rows.any((row) => row['Student_Code'] == code)) {
      throw FakeStudentsDb.duplicate();
    }
    db.rows.add({...data, 'id': db.rows.length + 1});
  }
}

// Awaiting the query directly (no range) behaves like an unpaged request.
class FakeStudentsQuery implements Future<List<Map<String, dynamic>>> {
  final FakeStudentsDb db;
  final List<bool Function(Map<String, dynamic>)> _filters = [];
  FakeStudentsQuery(this.db);

  Future<List<Map<String, dynamic>>> get _unpaged => range(0, 1 << 30);

  @override
  Stream<List<Map<String, dynamic>>> asStream() => _unpaged.asStream();

  @override
  Future<List<Map<String, dynamic>>> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => _unpaged.catchError(onError, test: test);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {
    Function? onError,
  }) => _unpaged.then(onValue, onError: onError);

  @override
  Future<List<Map<String, dynamic>>> timeout(
    Duration timeLimit, {
    FutureOr<List<Map<String, dynamic>>> Function()? onTimeout,
  }) => _unpaged.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<Map<String, dynamic>>> whenComplete(
    FutureOr<void> Function() action,
  ) => _unpaged.whenComplete(action);

  FakeStudentsQuery eq(String column, dynamic value) {
    _filters.add((row) => row[column] == value);
    return this;
  }

  FakeStudentsQuery like(String column, String pattern) {
    expect(pattern.endsWith('%'), isTrue);
    final prefix = pattern.substring(0, pattern.length - 1);
    _filters.add((row) => (row[column] ?? '').toString().startsWith(prefix));
    return this;
  }

  FakeStudentsQuery order(String column, {required bool ascending}) {
    expect(column, 'Student_Code');
    return this;
  }

  Future<List<Map<String, dynamic>>> range(int from, int to) async {
    final matching =
        db.rows.where((row) => _filters.every((f) => f(row))).toList()
          ..sort(
            (a, b) => (a['Student_Code'] ?? '').toString().compareTo(
              (b['Student_Code'] ?? '').toString(),
            ),
          );
    final count = (to - from + 1) < db.maxRows ? (to - from + 1) : db.maxRows;
    return matching
        .skip(from)
        .take(count)
        .map((row) => {'Student_Code': row['Student_Code']})
        .toList();
  }
}
