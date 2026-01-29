import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'word_generator.dart';

/// Helper class for exporting attendance reports
class AttendanceExportHelper {
  /// Export attendance data to Word document with enhanced formatting and full Arabic support
  /// 
  /// Parameters:
  /// - reportTitle: Main title (e.g., "تقرير الحضور الشهري")
  /// - groupName: Group name
  /// - classNumber: Class number
  /// - typeName: Type name
  /// - supervisorName: Supervisor name
  /// - startDate: Report period start
  /// - endDate: Report period end
  /// - attendanceRecords: List of attendance records
  /// - stats: Map with keys: 'present', 'absent', 'excuse', 'total'
  /// - generatedBy: User name who generated the report
  /// - notes: Additional notes or remarks
  static Future<void> exportToWord({
    required String reportTitle,
    required String groupName,
    required String classNumber,
    required String typeName,
    required String supervisorName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> attendanceRecords,
    required Map<String, int> stats,
    String? generatedBy,
    String? notes,
    required BuildContext context,
  }) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري إنشاء تقرير Word...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Generate Word document
      final docxBytes = await AttendanceWordGenerator.generateAttendanceReport(
        reportTitle: reportTitle,
        groupName: groupName,
        classNumber: classNumber,
        typeName: typeName,
        supervisorName: supervisorName,
        startDate: startDate,
        endDate: endDate,
        attendanceRecords: attendanceRecords,
        stats: stats,
        generatedBy: generatedBy,
        notes: notes,
      );

      // Download/save Word document
      _downloadWord(docxBytes, reportTitle);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ تم تصدير التقرير بنجاح'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting Word: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التصدير: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Download Word document file
  static void _downloadWord(Uint8List bytes, String reportTitle) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${reportTitle}_$timestamp.docx';

    final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Compute statistics from attendance records
  /// Returns a map with keys: 'present', 'absent', 'excuse', 'total'
  static Map<String, int> computeStats(
    List<Map<String, dynamic>> records,
  ) {
    int present = 0;
    int absent = 0;
    int excuse = 0;

    for (final record in records) {
      if (record['Attend_flag'] == true || record['Attend_flag'] == 1) {
        present++;
      } else if (record['Absent_flag'] == true || record['Absent_flag'] == 1) {
        absent++;
      } else if (record['Execuse_flag'] == true || record['Execuse_flag'] == 1) {
        excuse++;
      }
    }

    return {
      'present': present,
      'absent': absent,
      'excuse': excuse,
      'total': present + absent + excuse,
    };
  }
}
