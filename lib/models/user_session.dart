// User roles enum
enum UserRole {
  admin,    // Full access to everything
  manager,  // Almost full access (can view/edit all data)
  supervisor // Restricted to assigned classes only
}

// User session to store logged-in user info
class UserSession {
  final int? userId;
  final String? username;
  final int? classId;
  final UserRole role;
  
  // For supervisors: their assigned class/group/type IDs
  final int? assignedClassId;
  final int? assignedGroupId;
  final int? assignedTypeId;
  final List<Map<String, dynamic>> managerAssignments;

  UserSession({
    this.userId,
    this.username,
    this.classId,
    this.role = UserRole.supervisor,
    this.assignedClassId,
    this.assignedGroupId,
    this.assignedTypeId,
    this.managerAssignments = const [],
  });

  // Convenience getters
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isSupervisor => role == UserRole.supervisor;
  
  // Full access for admin and manager
  bool get hasFullAccess => isAdmin || isManager;
  
  // Has restrictions (supervisor only)
  bool get hasRestrictions => isSupervisor;
  
  // Legacy compatibility
  bool get hasClassRestriction => hasRestrictions && assignedClassId != null;

  bool get hasManagerAssignments => managerAssignments.isNotEmpty;

  bool canAccessScope({int? classId, int? groupId, int? typeId}) {
    if (hasFullAccess) return true;

    final assignments = managerAssignments.isNotEmpty
        ? managerAssignments
        : [
            {
              'Class_id': assignedClassId,
              'Group_id': assignedGroupId,
              'Type_id': assignedTypeId,
            },
          ];

    for (final assignment in assignments) {
      final assignedClassIdValue = _asInt(assignment['Class_id']);
      final assignedGroupIdValue = _asInt(assignment['Group_id']);
      final assignedTypeIdValue = _asInt(assignment['Type_id']);

      // Ignore empty assignment rows; they should not grant unrestricted access.
      if (assignedClassIdValue == null &&
          assignedGroupIdValue == null &&
          assignedTypeIdValue == null) {
        continue;
      }

      if (assignedClassIdValue != null && assignedClassIdValue != classId) {
        continue;
      }
      if (assignedGroupIdValue != null && assignedGroupIdValue != groupId) {
        continue;
      }
      if (assignedTypeIdValue != null && assignedTypeIdValue != typeId) {
        continue;
      }
      return true;
    }

    return false;
  }
  
  // Check if user can access a specific class/group/type
  bool canAccessClass(int? classId) {
    if (hasFullAccess) return true;
    if (!_hasAnyAssignedConstraint()) return false;
    if (assignedClassId == null) return true;
    return classId == assignedClassId;
  }
  
  bool canAccessGroup(int? groupId) {
    if (hasFullAccess) return true;
    if (!_hasAnyAssignedConstraint()) return false;
    if (assignedGroupId == null) return true;
    return groupId == assignedGroupId;
  }
  
  bool canAccessType(int? typeId) {
    if (hasFullAccess) return true;
    if (!_hasAnyAssignedConstraint()) return false;
    if (assignedTypeId == null) return true;
    return typeId == assignedTypeId;
  }

  bool _hasAnyAssignedConstraint() {
    if (managerAssignments.isNotEmpty) {
      for (final assignment in managerAssignments) {
        if (_asInt(assignment['Class_id']) != null ||
            _asInt(assignment['Group_id']) != null ||
            _asInt(assignment['Type_id']) != null) {
          return true;
        }
      }
      return false;
    }

    return assignedClassId != null || assignedGroupId != null || assignedTypeId != null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
