import 'package:flutter_test/flutter_test.dart';
import 'package:hosoon_academy/services/student_code_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_students_db.dart';

// Local tests only; the Supabase client is an in-memory fake.

// Verbatim copy of the numbering logic as it existed before this fix
// (lib/screens/students_screen.dart at HEAD), used as a reference oracle.
String? referenceNextCode(List<dynamic> existingCodes) {
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

// Student codes starting with H6 in the supplied production snapshot.
const _snapshotGroups = <int, List<String>>{
  9: ['H6', 'H60', 'H61', 'H65', 'H66', 'H69'],
  14: ['H60002', 'H60003', 'H60004', 'H60005', 'H60006', 'H60007'],
  15: ['H60008', 'H60009', 'H60011', 'H60012'],
  11: [
    'H601', 'H602', 'H603', 'H604', 'H605', 'H606', 'H609', 'H612', 'H614',
    'H618', 'H624', 'H626', 'H627', 'H628', 'H629', 'H631', 'H632', 'H633',
    'H636', 'H638', 'H640', 'H641', 'H642', 'H644', 'H645', 'H647', 'H648',
    'H650', 'H654', 'H659', 'H660', 'H661', 'H662', 'H6636', 'H664', 'H665',
    'H666', 'H668', 'H670', 'H673', 'H676', 'H678', 'H680', 'H681', 'H682',
    'H683', 'H684', 'H685', 'H687', 'H692',
  ],
};

List<Map<String, dynamic>> _snapshotRows() => [
  for (final entry in _snapshotGroups.entries)
    for (final code in entry.value)
      {'Group_id': entry.key, 'Student_Code': code},
];

const _h6 = StudentCodeFormat('H6', 4);

void main() {
  group('legacy (non-series) numbering is unchanged', () {
    final samples = <List<dynamic>>[
      [],
      [null, '', '  '],
      ['abc', '12', 'A-001'],
      ['A001', 'A002'],
      ['A009'],
      ['A099', 'B100'],
      ['H50009', 'H50012', 'H50007'],
      ['H40001', 'H40009', 'junk'],
      [' H40010 ', 'h40011'],
      ['AB0099', 'A00100'],
      ..._snapshotGroups.values,
      ['H60002', 'H60011', 'X99999999999999999999'],
    ];

    test('matches the original function for every sample', () {
      for (final codes in samples) {
        expect(
          StudentCodeService.buildLegacyNextCode(codes),
          referenceNextCode(codes),
          reason: '$codes',
        );
      }
    });

    test('keeps its characteristic results', () {
      expect(StudentCodeService.buildLegacyNextCode(['A001', 'A002']), 'A003');
      expect(StudentCodeService.buildLegacyNextCode([]), isNull);
      expect(StudentCodeService.buildLegacyNextCode(['H692']), 'H693');
      expect(StudentCodeService.buildLegacyNextCode(_snapshotGroups[9]!), 'H70');
      expect(StudentCodeService.buildLegacyNextCode(_snapshotGroups[11]!), 'H6637');
      expect(StudentCodeService.buildLegacyNextCode(_snapshotGroups[15]!), 'H60013');
      // The original group-only logic is what produced the duplicate for 14.
      expect(StudentCodeService.buildLegacyNextCode(_snapshotGroups[14]!), 'H60008');
    });
  });

  group('series configuration', () {
    test('only group 14 uses the shared H6 series', () {
      expect(StudentCodeService.seriesForGroup(14)?.prefix, 'H6');
      expect(StudentCodeService.seriesForGroup(14)?.suffixWidth, 4);
      expect(StudentCodeService.seriesForGroup('14')?.prefix, 'H6');
      for (final id in [1, 9, 11, 15, 13, 140, null, 'x']) {
        expect(StudentCodeService.seriesForGroup(id), isNull, reason: '$id');
      }
    });
  });

  group('series numbering', () {
    test('supplied H6 snapshot produces H60013', () async {
      final db = FakeStudentsDb(_snapshotRows());
      final codes = await StudentCodeService.fetchSeriesCodes(db, 'H6');
      expect(StudentCodeService.nextSeriesCode(_h6, codes), 'H60013');
    });

    test('counts codes of students transferred to another group', () {
      final codes = [..._snapshotGroups[14]!, ..._snapshotGroups[15]!];
      expect(StudentCodeService.nextSeriesCode(_h6, codes), 'H60013');
    });

    test('ignores other formats sharing the prefix', () {
      expect(
        StudentCodeService.nextSeriesCode(_h6, [
          'H6', 'H60', 'H69', 'H601', 'H692', 'H6636', 'H60002', 'H600123',
          'h60500', 'H6A001', ' H60003 ',
        ]),
        'H60004',
      );
    });

    test('uses the highest suffix across gaps and keeps zero padding', () {
      expect(
        StudentCodeService.nextSeriesCode(_h6, ['H60002', 'H60011', 'H60009']),
        'H60012',
      );
      expect(StudentCodeService.nextSeriesCode(_h6, ['H60099']), 'H60100');
      expect(StudentCodeService.nextSeriesCode(_h6, ['H60009']), 'H60010');
    });

    test('refuses to exceed the configured suffix width', () {
      expect(
        () => StudentCodeService.nextSeriesCode(_h6, ['H69999']),
        throwsA(isA<StudentCodeGenerationException>()),
      );
    });

    test('no valid code in the series is an error, not a guess', () {
      expect(
        () => StudentCodeService.nextSeriesCode(_h6, ['H692', 'H6']),
        throwsA(isA<StudentCodeGenerationException>()),
      );
    });

    test('series query leaves other prefixes out', () async {
      final db = FakeStudentsDb([
        {'Student_Code': 'H40002'},
        {'Student_Code': 'H50009'},
        {'Student_Code': 'H60012'},
      ]);
      expect(await StudentCodeService.fetchSeriesCodes(db, 'H6'), ['H60012']);
    });
  });

  group('pagination', () {
    List<Map<String, dynamic>> manyRows(int count) => [
      for (var i = 1; i <= count; i++)
        {'Student_Code': 'H6${i.toString().padLeft(4, '0')}'},
    ];

    test('reads every row when the total exceeds the page size', () async {
      final codes = await StudentCodeService.fetchSeriesCodes(
        FakeStudentsDb(manyRows(2500)),
        'H6',
      );
      expect(codes, hasLength(2500));
      expect(StudentCodeService.nextSeriesCode(_h6, codes), 'H62501');
    });

    test('reads every row when the server caps below the page size', () async {
      final codes = await StudentCodeService.fetchSeriesCodes(
        FakeStudentsDb(manyRows(450), maxRows: 100),
        'H6',
      );
      expect(codes, hasLength(450));
    });
  });

  group('insertion', () {
    final data = {'Student_Name': 'New', 'Group_id': 14};

    Future<String?> insert(FakeStudentsDb db, dynamic groupId) =>
        StudentCodeService.insertWithAutomaticCode(
          client: db,
          studentData: {...data, 'Group_id': groupId},
          groupId: groupId,
        );

    test('group 14 inserts H60013 from the supplied dataset', () async {
      final db = FakeStudentsDb(_snapshotRows());
      expect(await insert(db, 14), 'H60013');
      expect(db.insertCalls, 1);
    });

    test('other groups insert their original next code', () async {
      final db = FakeStudentsDb(_snapshotRows());
      expect(await insert(db, 9), 'H70');
      expect(await insert(db, 15), 'H60013');
      expect(db.rows.where((r) => r['Student_Code'] == 'H60013'), hasLength(1));
    });

    test('a group without any valid code returns null and inserts nothing', () async {
      final db = FakeStudentsDb([
        {'Group_id': 7, 'Student_Code': 'x-1'},
        {'Group_id': 8, 'Student_Code': 'A001'},
      ]);
      expect(await insert(db, 7), isNull);
      expect(db.insertCalls, 0);
      expect(db.rows, hasLength(2));
    });

    test('group 14 recalculates after a concurrent insert took its code', () async {
      final db = FakeStudentsDb(_snapshotRows());
      var raced = false;
      db.beforeInsert = (code) {
        if (raced) return;
        raced = true;
        db.rows.add({'Group_id': 14, 'Student_Code': code});
      };
      expect(await insert(db, 14), 'H60014');
      expect(db.insertCalls, 2);
    });

    test('other groups advance past a rejected code using their own convention', () async {
      final db = FakeStudentsDb([
        {'Group_id': 5, 'Student_Code': 'H50001'},
        {'Group_id': 5, 'Student_Code': 'H50002'},
      ]);
      // Another group already holds H50003 (e.g. a transferred student).
      db.rows.add({'Group_id': 99, 'Student_Code': 'H50003'});
      expect(await insert(db, 5), 'H50004');
      expect(db.insertCalls, 2);
      final codes = db.rows.map((r) => r['Student_Code']).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('gives up after three retries for series and other groups', () async {
      for (final group in [14, 5]) {
        final db = FakeStudentsDb([
          ..._snapshotRows(),
          {'Group_id': 5, 'Student_Code': 'H50001'},
        ]);
        db.beforeInsert = (code) =>
            db.rows.add({'Group_id': 99, 'Student_Code': code});
        await expectLater(
          insert(db, group),
          throwsA(isA<StudentCodeGenerationException>()),
          reason: 'group $group',
        );
        expect(db.insertCalls, 4, reason: 'group $group');
      }
    });

    test('unrelated errors and other constraints are not retried', () async {
      for (final error in [
        const PostgrestException(message: 'permission denied', code: '42501'),
        FakeStudentsDb.duplicate('Students_pkey'),
      ]) {
        for (final group in [14, 9]) {
          final db = FakeStudentsDb(_snapshotRows())..forcedError = error;
          await expectLater(
            insert(db, group),
            throwsA(isA<PostgrestException>()),
          );
          expect(db.insertCalls, 1);
        }
      }
    });

    test('recognises only the Student_Code unique violation', () {
      expect(
        StudentCodeService.isStudentCodeConflict(FakeStudentsDb.duplicate()),
        isTrue,
      );
      expect(
        StudentCodeService.isStudentCodeConflict(
          FakeStudentsDb.duplicate('Students_pkey'),
        ),
        isFalse,
      );
      expect(StudentCodeService.isStudentCodeConflict(Exception('x')), isFalse);
    });

    test('existing rows are never modified', () async {
      final db = FakeStudentsDb(_snapshotRows());
      final before = [for (final r in db.rows) {...r}];
      await insert(db, 14);
      await insert(db, 9);
      expect(db.rows.take(before.length).toList(), before);
    });
  });
}
