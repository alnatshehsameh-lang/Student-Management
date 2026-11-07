import 'package:flutter_test/flutter_test.dart';
import 'package:hosoon_academy/models/user_session.dart';

void main() {
  group('Attendance override permissions', () {
    test('admin can change attendance for any student', () {
      final user = UserSession(role: UserRole.admin);

      expect(user.canManageAttendanceForStudent({'Group_id': 10}), isTrue);
      expect(user.canManageAttendanceForStudent({'Group_id': 99}), isTrue);
    });

    test('group-level supervisor can change attendance only for their group', () {
      final user = UserSession(
        role: UserRole.supervisor,
        managerAssignments: [
          {'Group_id': 7, 'Class_id': null, 'Type_id': null},
        ],
      );

      expect(user.canManageAttendanceForStudent({'Group_id': 7}), isTrue);
      expect(user.canManageAttendanceForStudent({'Group_id': 8}), isFalse);
    });

    test('class-level supervisor cannot change attendance', () {
      final user = UserSession(
        role: UserRole.supervisor,
        managerAssignments: [
          {'Group_id': 7, 'Class_id': 3, 'Type_id': null},
        ],
      );

      expect(user.canManageAttendanceForStudent({'Group_id': 7}), isFalse);
    });

    test('supervisor with no group assignment cannot change attendance', () {
      final user = UserSession(
        role: UserRole.supervisor,
        managerAssignments: [
          {'Group_id': null, 'Class_id': null, 'Type_id': null},
        ],
      );

      expect(user.canManageAttendanceForStudent({'Group_id': 7}), isFalse);
    });

    test('other roles cannot change attendance', () {
      final managerUser = UserSession(role: UserRole.manager);
      expect(managerUser.canManageAttendanceForStudent({'Group_id': 7}), isFalse);

      final otherUser = UserSession(role: UserRole.supervisor);
      expect(otherUser.canManageAttendanceForStudent({'Group_id': 7}), isFalse);
    });

    test('class assignment does not grant attendance permission when a matching group assignment exists', () {
      final user = UserSession(
        role: UserRole.supervisor,
        managerAssignments: [
          {'Group_id': 7, 'Class_id': null, 'Type_id': null},
          {'Group_id': 7, 'Class_id': 3, 'Type_id': null},
        ],
      );

      expect(user.canManageAttendanceForStudent({'Group_id': 7}), isFalse);
    });
  });
}
