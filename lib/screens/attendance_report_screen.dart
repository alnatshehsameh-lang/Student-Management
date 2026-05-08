import 'package:flutter/material.dart';

import '../models/user_session.dart';
import 'attendance_report_screen_new.dart';

class AttendanceReportScreen extends StatelessWidget {
  final UserSession userSession;

  const AttendanceReportScreen({super.key, required this.userSession});

  @override
  Widget build(BuildContext context) {
    return AttendanceReportScreenNew(userSession: userSession);
  }
}
