import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_application/screens/students_screen.dart';

void main() {
  testWidgets('StudentsTable displays lookup names for ID fields', (WidgetTester tester) async {
    final rows = [
      {'id': 1, 'Student_Name': 'Ali', 'Group_id': 10, 'Class_id': 20, 'Type_id': 30},
      {'id': 2, 'Student_Name': 'Sara', 'Group_id': 11, 'Class_id': 21, 'Type_id': 31},
    ];

    final groups = {10: 'Group A', 11: 'Group B'};
    final classNumbers = {20: 'C-20', 21: 'C-21'};
    final classes = {20: 'Class X', 21: 'Class Y'};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: StudentsTable(
              rows: rows,
              groupsMap: groups,
              typesMap: classNumbers,
              classesMap: classes,
            ),
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Expect to find the student names and the mapped group/class strings
  expect(find.text('Ali'), findsOneWidget);
  expect(find.text('Group A'), findsOneWidget);
  // Class mapping should show the classMap value for Class_id
  expect(find.text('Class X'), findsOneWidget);

  expect(find.text('Sara'), findsOneWidget);
  expect(find.text('Group B'), findsOneWidget);
  expect(find.text('Class Y'), findsOneWidget);
  });
}
