// User session to store logged-in user info
class UserSession {
  final int? userId;
  final String? username;
  final int? classId;
  final bool isAdmin;

  UserSession({
    this.userId,
    this.username,
    this.classId,
    this.isAdmin = false,
  });

  bool get hasClassRestriction => !isAdmin && classId != null;
}
