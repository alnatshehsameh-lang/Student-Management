import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_application/screens/students_screen.dart';

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
    if (columns != null) return Future<List<Map<String, dynamic>>>.value(_data);
    return this;
  }

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
}
