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

  UserSession({
    this.userId,
    this.username,
    this.classId,
    this.role = UserRole.supervisor,
    this.assignedClassId,
    this.assignedGroupId,
    this.assignedTypeId,
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
  
  // Check if user can access a specific class/group/type
  bool canAccessClass(int? classId) {
    if (hasFullAccess) return true;
    if (assignedClassId == null) return true;
    return classId == assignedClassId;
  }
  
  bool canAccessGroup(int? groupId) {
    if (hasFullAccess) return true;
    if (assignedGroupId == null) return true;
    return groupId == assignedGroupId;
  }
  
  bool canAccessType(int? typeId) {
    if (hasFullAccess) return true;
    if (assignedTypeId == null) return true;
    return typeId == assignedTypeId;
  }
}
