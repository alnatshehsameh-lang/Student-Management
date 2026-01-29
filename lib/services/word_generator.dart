import 'dart:typed_data';
import 'package:docx_template/docx_template.dart';
import 'package:intl/intl.dart';

/// Professional Word Document Generator with full Arabic support
class AttendanceWordGenerator {
  /// Generate professional attendance report as Word document
  static Future<Uint8List> generateAttendanceReport({
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
  }) async {
    // Create a new Word document
    final docx = DocxTemplate(
      archiveData: await _createBaseTemplate(),
    );

    // Format dates in Arabic
    final arabicDateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final startDateStr = arabicDateFormat.format(startDate);
    final endDateStr = arabicDateFormat.format(endDate);

    // Prepare table rows for attendance details
    final List<Map<String, dynamic>> attendanceRows = [];
    for (final record in attendanceRecords) {
      final date = record['Report_date']?.toString().split('T')[0] ?? '';
      final studentName = record['Students']?['Student_Name'] ?? '';
      final studentCode = record['Students']?['Student_Code']?.toString() ?? '';
      final type = record['_type'] ?? '';
      final attend = (record['Attend_flag'] == true || record['Attend_flag'] == 1) ? '✓' : '';
      final absent = (record['Absent_flag'] == true || record['Absent_flag'] == 1) ? '✓' : '';
      final excuse = (record['Execuse_flag'] == true || record['Execuse_flag'] == 1) ? '✓' : '';

      attendanceRows.add({
        'date': date,
        'student_name': studentName,
        'student_code': studentCode,
        'type': type,
        'attend': attend,
        'absent': absent,
        'excuse': excuse,
      });
    }

    // Create content for the template
    final content = Content();
    content
      ..add(TextContent('report_title', reportTitle))
      ..add(TextContent('group_name', groupName))
      ..add(TextContent('class_number', classNumber))
      ..add(TextContent('type_name', typeName))
      ..add(TextContent('supervisor_name', supervisorName))
      ..add(TextContent('start_date', startDateStr))
      ..add(TextContent('end_date', endDateStr))
      ..add(TextContent('present_count', stats['present']?.toString() ?? '0'))
      ..add(TextContent('absent_count', stats['absent']?.toString() ?? '0'))
      ..add(TextContent('excuse_count', stats['excuse']?.toString() ?? '0'))
      ..add(TextContent('total_count', stats['total']?.toString() ?? '0'))
      ..add(TextContent('generated_by', generatedBy ?? 'نظام الإدارة'))
      ..add(TextContent('notes', notes ?? ''))
      ..add(TableContent('attendance_table', attendanceRows));

    // Generate the document
    final generatedDoc = await docx.generate(content);
    return generatedDoc!;
  }

  /// Create base Word document template with proper formatting
  static Future<Uint8List> _createBaseTemplate() async {
    // This creates a minimal DOCX structure
    // For production, you'd create a proper template file with styling
    final template = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p><w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr>
        <w:t>{report_title}</w:t>
      </w:r>
    </w:p>
    
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>
    
    <w:tbl>
      <w:tblPr><w:tblW w:w="5000" w:type="pct"/></w:tblPr>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>المجموعة:</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{group_name}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>الفصل:</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{class_number}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>الرواية:</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{type_name}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>المشرفة:</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{supervisor_name}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>الفترة:</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{start_date} - {end_date}</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>
    
    <w:p><w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>ملخص الإحصائيات</w:t></w:r></w:p>
    
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>الحالة</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>العدد</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>حاضر</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{present_count}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>غائب</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{absent_count}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>معتذر</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{excuse_count}</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>المجموع</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{total_count}</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    
    <w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>
    
    <w:p><w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>تفاصيل الحضور</w:t></w:r></w:p>
    
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>التاريخ</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>اسم الطالب</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>رقم الطالب</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>النوع</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>حاضر</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>غائب</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>معتذر</w:t></w:r></w:p></w:tc>
      </w:tr>
      {#attendance_table}
      <w:tr>
        <w:tc><w:p><w:r><w:t>{date}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{student_name}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{student_code}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{type}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{attend}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{absent}</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>{excuse}</w:t></w:r></w:p></w:tc>
      </w:tr>
      {/attendance_table}
    </w:tbl>
    
  </w:body>
</w:document>
''';

    return Uint8List.fromList(template.codeUnits);
  }
}
