/*
/// EXAMPLE: How to integrate the enhanced PDF export into AttendanceReportScreen
/// 
/// This file shows the exact changes needed to your attendance_report_screen.dart
/// Copy the relevant sections and adapt to your code.

// ============================================================================
// ADD THIS IMPORT AT THE TOP
// ============================================================================
import '../services/export_helper.dart';

// ============================================================================
// REPLACE THE _exportToPDF() FUNCTION WITH THIS
// ============================================================================

/// Export attendance report to PDF with enhanced Arabic support
Future<void> _exportToPDF() async {
  if (_reportData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا توجد بيانات للتصدير')),
    );
    return;
  }

  try {
    // Determine report title based on selected filters
    final reportTitle = _determineReportTitle();
    
    // Get department/class name
    final departmentName = _getDepartmentName();

    // Compute statistics from report data
    final stats = AttendanceExportHelper.computeStats(_reportData);

    // Prepare additional notes
    final notes = _prepareNotes(stats);

    // Call enhanced export function
    await AttendanceExportHelper.exportToPDF(
      reportTitle: reportTitle,
      departmentName: departmentName,
      startDate: _startDate ?? DateTime.now(),
      endDate: _endDate ?? DateTime.now(),
      attendanceRecords: _reportData,
      stats: stats,
      generatedBy: widget.userSession.userName ?? 'نظام الإدارة',
      notes: notes,
      context: context,
    );
  } catch (e) {
    debugPrint('Error in _exportToPDF: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }
}

/// Helper: Determine report title based on filters
String _determineReportTitle() {
  if (_selectedTypeId != null && _selectedClassId != null) {
    return 'تقرير الحضور - الفصل المختار';
  } else if (_selectedTypeId != null) {
    return 'تقرير الحضور - الرواية المختارة';
  } else if (_selectedGroupId != null) {
    return 'تقرير الحضور - المجموعة المختارة';
  } else {
    return 'تقرير الحضور الشامل';
  }
}

/// Helper: Get department/class name
String _getDepartmentName() {
  // Find the selected class/group name from your data
  if (_selectedClassId != null) {
    final classData = _classes.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => {'Class_Number': 'غير محدد'},
    );
    return 'الفصل: ${classData['Class_Number'] ?? 'غير محدد'}';
  } else if (_selectedGroupId != null) {
    final groupData = _groups.firstWhere(
      (g) => g['id'] == _selectedGroupId,
      orElse: () => {'Group_Name': 'غير محدد'},
    );
    return 'المجموعة: ${groupData['Group_Name'] ?? 'غير محدد'}';
  } else {
    return 'نظام إدارة الحضور';
  }
}

/// Helper: Prepare notes for the report
String _prepareNotes(Map<String, int> stats) {
  final total = stats['total'] ?? 0;
  final present = stats['present'] ?? 0;
  final absent = stats['absent'] ?? 0;
  final excuse = stats['excuse'] ?? 0;

  String attendancePercentage = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : '0';

  return '''ملخص الإحصائيات:
• إجمالي السجلات: $total
• الحاضرات: $present (${attendancePercentage}%)
• الغائبات: $absent
• المعتذرات: $excuse

تم إنشاء هذا التقرير من نظام إدارة الحضور الالكتروني''';
}

// ============================================================================
// OPTIONAL: SHOW LOADING STATE
// ============================================================================

/// Add this to your state class for better UX
bool _exportingPDF = false;

/// Update your export button to show loading:
@override
Widget build(BuildContext context) {
  return Scaffold(
    // ... existing code ...
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _exportingPDF ? null : _exportToPDFWithLoadingState,
      icon: _exportingPDF
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.picture_as_pdf),
      label: Text(_exportingPDF ? 'جاري الإنشاء...' : 'تصدير PDF'),
    ),
  );
}

/// Enhanced export with loading state
Future<void> _exportToPDFWithLoadingState() async {
  setState(() => _exportingPDF = true);
  try {
    await _exportToPDF();
  } finally {
    if (mounted) setState(() => _exportingPDF = false);
  }
}

// ============================================================================
// COMPLETE EXAMPLE INTEGRATION
// ============================================================================

// Here's a complete code snippet showing the integration:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';
import '../services/export_helper.dart'; // ADD THIS

class AttendanceReportScreen extends StatefulWidget {
  final UserSession userSession;
  const AttendanceReportScreen({required this.userSession});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _reportData = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _classes = [];
  bool _exportingPDF = false;

  dynamic _selectedGroupId;
  dynamic _selectedTypeId;
  dynamic _selectedClassId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    // Load your filter data...
  }

  // YOUR NEW EXPORT FUNCTION
  Future<void> _exportToPDF() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }

    try {
      final stats = AttendanceExportHelper.computeStats(_reportData);

      await AttendanceExportHelper.exportToPDF(
        reportTitle: 'تقرير الحضور',
        departmentName: 'نظام إدارة الحضور',
        startDate: _startDate ?? DateTime.now(),
        endDate: _endDate ?? DateTime.now(),
        attendanceRecords: _reportData,
        stats: stats,
        generatedBy: widget.userSession.userName,
        notes: 'تم إنشاء هذا التقرير من النظام الالكتروني',
        context: context,
      );
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: _exportingPDF ? null : () async {
              setState(() => _exportingPDF = true);
              try {
                await _exportToPDF();
              } finally {
                if (mounted) setState(() => _exportingPDF = false);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: _exportingPDF
            ? const CircularProgressIndicator()
            : const Text('Report Screen'),
      ),
    );
  }
}
```

*/
