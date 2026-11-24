import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosoon_academy/models/user_session.dart';
import 'package:hosoon_academy/screens/students_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_students_db.dart';

// A minimal fake Postgrest-like builder to satisfy the chained calls used in StudentsScreen.
class FakeQuery {
  final String table;
  final FakeSupabaseClient client;
  List<Map<String, dynamic>> _data = [];
  final Map<String, dynamic> _filters = {};
  String? _ilikeField;
  String? _ilikeValue;
  String? _orderField;
  bool _ascending = true;

  FakeQuery(this.table, this.client) {
    _data = client._dataForTable(table);
  }

  // If columns is provided we treat select as a fetch and return a Future<List>.
  // If no columns are provided, return this to allow chaining (order/range/etc.)
  dynamic select([String? columns]) {
    if (columns == 'Student_Code') {
      return FakeStudentsTable(client.students).select('Student_Code');
    }
    if (columns != null) return Future<List<Map<String, dynamic>>>.value(_data);
    return this;
  }

  FakeQuery or(String filters) => this;

  Future<void> insert(Map<String, dynamic> data) =>
      FakeStudentsTable(client.students).insert(data);

  FakeQuery eq(String key, dynamic value) {
    _filters[key] = value;
    return this;
  }

  FakeQuery ilike(String field, String pattern) {
    _ilikeField = field;
    _ilikeValue = pattern.replaceAll('%', '');
    return this;
  }

  FakeQuery order(String field, {required bool ascending}) {
    _orderField = field;
    _ascending = ascending;
    return this;
  }

  Future<List<Map<String, dynamic>>> range(int from, int to) async {
    // apply filters
    var rows = _data.where((r) {
      for (final e in _filters.entries) {
        final key = e.key.replaceAll('"', '');
        if (r[key] != e.value) return false;
      }
      if (_ilikeField != null) {
        final key = _ilikeField!.replaceAll('"', '');
        final val = r[key]?.toString() ?? '';
        if (!val.contains(_ilikeValue!)) return false;
      }
      return true;
    }).toList();
    if (_orderField != null) {
      final key = _orderField!.replaceAll('"', '');
      rows.sort((a, b) => (a[key] as Comparable).compareTo(b[key] as Comparable));
      if (!_ascending) rows = rows.reversed.toList();
    }
    // simple pagination
    final slice = rows.skip(from).take(to - from + 1).toList();
    return slice;
  }

  FakeQuery gt(String field, dynamic value) {
    // store as a filter special marker
    _filters['gt:$field'] = value;
    return this;
  }
}

class FakeSupabaseClient {
  final Map<String, List<Map<String, dynamic>>> _tables;
  late final FakeStudentsDb students = FakeStudentsDb(
    _tables.putIfAbsent('Students', () => []),
  );
  FakeSupabaseClient(this._tables);

  List<Map<String, dynamic>> _dataForTable(String table) {
    return _tables[table] ?? [];
  }

  FakeQuery from(String table) => FakeQuery(table, this);
}

void main() {
  testWidgets('StudentsScreen loads lookups and filters by Group', (WidgetTester tester) async {
    // fake data
    final fake = FakeSupabaseClient({
      'Groups': [
        {'id': 10, 'Group_Name': 'G A'},
        {'id': 11, 'Group_Name': 'G B'},
      ],
      'Classes': [
        {'id': 20, 'Class_Number': 'C20'},
      ],
      'Types': [
        {'id': 30, 'Type': 'T1'},
      ],
      'Students': [
        {'id': 1, 'Student_Name': 'Ali', 'Group_id': 10, 'Class_id': 20, 'Type_id': 30},
        {'id': 2, 'Student_Name': 'Sara', 'Group_id': 11, 'Class_id': 20, 'Type_id': 30},
      ],
    });

  await tester.pumpWidget(MaterialApp(home: StudentsScreen(client: fake as dynamic)));

    // Allow async init to complete
    await tester.pumpAndSettle();

    // We expect student names to be shown
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);

    // Open Group dropdown and select 'G A'
  // Ensure lookups loaded and mapped values are visible
  expect(find.text('G A'), findsOneWidget);
  });

  // Local widget tests: the Supabase client is replaced by an in-memory fake
  // that enforces the Student_Code unique constraint. No database is used.
  Map<String, dynamic> student(
    int id,
    int groupId,
    String code, {
    bool active = true,
  }) => {
    'id': id,
    'Student_Name': 'S$id',
    'Group_id': groupId,
    'Student_Code': code,
    'is_active': active,
  };

  // H6 snapshot: students transferred out of group 14 keep their codes.
  List<Map<String, dynamic>> h6Snapshot() {
    final rows = <Map<String, dynamic>>[];
    void add(int group, String code, {bool active = true}) =>
        rows.add(student(rows.length + 1, group, code, active: active));
    for (final code in ['H60002', 'H60003', 'H60004', 'H60005', 'H60006', 'H60007']) {
      add(14, code);
    }
    for (final code in ['H60008', 'H60009', 'H60011']) {
      add(15, code);
    }
    add(15, 'H60012', active: false);
    for (final code in ['H601', 'H609', 'H6636', 'H692']) {
      add(11, code);
    }
    for (final code in ['H6', 'H60', 'H69']) {
      add(9, code);
    }
    return rows;
  }

  Future<void> addStudent(
    WidgetTester tester,
    FakeSupabaseClient fake,
    int groupId, {
    String? manualCode,
  }) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = UserSession(
      managerAssignments: [
        {'Group_id': groupId},
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: StudentsScreen(client: fake, userSession: session)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, 'New student');
    if (manualCode != null) await tester.enterText(fields.at(2), manualCode);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
  }

  FakeSupabaseClient h6Client({List<Map<String, dynamic>>? students}) =>
      FakeSupabaseClient({
        'Groups': [
          {'id': 9, 'Group_Name': 'حصون١'},
          {'id': 11, 'Group_Name': 'حصون٣'},
          {'id': 14, 'Group_Name': 'حصون٦'},
          {'id': 15, 'Group_Name': 'جوهرة الحصون'},
          {'id': 20, 'Group_Name': 'مجموعة جديدة'},
        ],
        'Students': students ?? h6Snapshot(),
      });

  const generationFailed =
      'تعذر إنشاء كود الطالب تلقائياً، يرجى المحاولة مرة أخرى أو التواصل مع مسؤول النظام.';
  const addFailed =
      'تعذر إضافة الطالب، يرجى المحاولة مرة أخرى أو التواصل مع مسؤول النظام.';

  testWidgets(
    'حصون٦ numbering counts transferred and inactive students: H60012 -> H60013',
    (tester) async {
      final fake = h6Client();
      final before = [for (final r in fake.students.rows) {...r}];

      await addStudent(tester, fake, 14);

      final rows = fake.students.rows;
      expect(rows.last['Student_Code'], 'H60013');
      expect(rows.last['Group_id'], 14);
      expect(fake.students.insertCalls, 1);
      expect(find.text('تم إضافة الطالب بنجاح'), findsOneWidget);
      // Existing rows are untouched and codes remain unique.
      expect(rows.take(before.length).toList(), before);
      final codes = rows.map((r) => r['Student_Code']).toList();
      expect(codes.toSet().length, codes.length);
    },
  );

  testWidgets('consecutive creation in حصون٦ yields H60013 then H60014', (
    tester,
  ) async {
    final fake = h6Client();
    await addStudent(tester, fake, 14);
    await tester.pumpWidget(const SizedBox());
    await addStudent(tester, fake, 14);

    final created = fake.students.rows.reversed.take(2).toList();
    expect(created.map((r) => r['Student_Code']), ['H60014', 'H60013']);
  });

  for (final series in [
    (id: 12, name: 'حصون٤', member: 'H40001', existing: 'H40009', next: 'H40010'),
    (id: 13, name: 'حصون٥', member: 'H50001', existing: 'H50012', next: 'H50013'),
  ]) {
    testWidgets('${series.name} keeps its original per-group numbering', (
      tester,
    ) async {
      final fake = FakeSupabaseClient({
        'Groups': [
          {'id': series.id, 'Group_Name': series.name},
        ],
        'Students': [
          student(1, series.id, series.member),
          student(2, series.id, series.existing, active: false),
          student(3, 14, 'H60099'),
        ],
      });

      await addStudent(tester, fake, series.id);

      expect(fake.students.rows.last['Student_Code'], series.next);
      expect(fake.students.insertCalls, 1);
    });
  }

  for (final other in [
    (id: 9, expected: 'H70'),
    (id: 11, expected: 'H6637'),
    (id: 15, expected: 'H60013'),
  ]) {
    testWidgets('group ${other.id} keeps its original automatic code', (
      tester,
    ) async {
      final fake = h6Client();

      await addStudent(tester, fake, other.id);

      expect(fake.students.rows.last['Student_Code'], other.expected);
      expect(fake.students.insertCalls, 1);
    });
  }

  testWidgets('another group retries past a code taken by a transferred student', (
    tester,
  ) async {
    final fake = FakeSupabaseClient({
      'Groups': [
        {'id': 13, 'Group_Name': 'حصون٥'},
      ],
      'Students': [
        student(1, 13, 'H50001'),
        student(2, 13, 'H50002'),
      ],
    });
    var raced = false;
    fake.students.beforeInsert = (code) {
      if (raced) return;
      raced = true;
      fake.students.rows.add(student(900, 99, code));
    };

    await addStudent(tester, fake, 13);

    expect(fake.students.rows.last['Student_Code'], 'H50004');
    expect(fake.students.insertCalls, 2);
  });

  testWidgets('automatic code is recalculated after a concurrent insert', (
    tester,
  ) async {
    final fake = h6Client();
    var raced = false;
    fake.students.beforeInsert = (code) {
      if (raced) return;
      raced = true;
      fake.students.rows.add(student(900, 14, code));
    };

    await addStudent(tester, fake, 14);

    expect(fake.students.rows.last['Student_Code'], 'H60014');
    expect(fake.students.insertCalls, 2);
    expect(find.text('تم إضافة الطالب بنجاح'), findsOneWidget);
  });

  testWidgets('automatic code gives up after three retries with an Arabic message', (
    tester,
  ) async {
    final fake = h6Client();
    fake.students.beforeInsert = (code) =>
        fake.students.rows.add(student(900 + fake.students.rows.length, 14, code));

    await addStudent(tester, fake, 14);

    expect(fake.students.insertCalls, 4);
    expect(find.text(generationFailed), findsOneWidget);
    expect(find.textContaining('duplicate key'), findsNothing);
  });

  testWidgets('unrelated insert errors are not retried or shown raw', (
    tester,
  ) async {
    final fake = h6Client();
    fake.students.forcedError = const PostgrestException(
      message: 'private database error',
      code: '42501',
    );

    await addStudent(tester, fake, 14);

    expect(fake.students.insertCalls, 1);
    expect(find.text(addFailed), findsOneWidget);
    expect(find.textContaining('private database error'), findsNothing);
  });

  testWidgets('a manually entered duplicate code is rejected, not changed', (
    tester,
  ) async {
    // Group 20 has no valid code, so automatic numbering is unavailable and
    // the manual code path applies, exactly as before.
    final fake = h6Client();

    await addStudent(tester, fake, 20, manualCode: 'H60012');

    expect(fake.students.insertCalls, 1);
    expect(
      find.text('كود الطالب مستخدم مسبقاً، يرجى إدخال كود آخر.'),
      findsOneWidget,
    );
    expect(
      fake.students.rows.where((r) => r['Student_Code'] == 'H60012'),
      hasLength(1),
    );
  });

  testWidgets('a manually entered unused code is inserted as typed', (
    tester,
  ) async {
    final fake = h6Client();

    await addStudent(tester, fake, 20, manualCode: 'H60020');

    expect(fake.students.rows.last['Student_Code'], 'H60020');
    expect(fake.students.insertCalls, 1);
  });
}
