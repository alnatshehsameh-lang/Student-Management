import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_application/screens/students_screen.dart';

void main() {
  testWidgets('StudentsTable renders columns and rows', (WidgetTester tester) async {
    final rows = [
      {'id': 1, 'student_name': 'Alice', 'class_number': '101', 'Mobile_no': '12345'},
      {'id': 2, 'student_name': 'Bob', 'class_number': '102', 'Mobile_no': '67890'},
    ];

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudentsTable(rows: rows))));

  // Expect header labels (Arabic)
  expect(find.text('الرقم'), findsOneWidget);
  expect(find.text('اسم الطالب'), findsOneWidget);
  expect(find.text('الجوال'), findsOneWidget);

    // Expect a cell value
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });
}
