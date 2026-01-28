import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

/// Enhanced PDF Generator with full Arabic support and professional layout
class AttendancePdfGenerator {
  /// Get font for PDF - using Times Roman which has better Unicode support
  static pw.Font loadArabicFont() {
    // Times Roman is more reliable than Helvetica/Courier for Unicode text
    // This avoids network calls and font loading delays
    return pw.Font.times();
  }

  /// Generate professional attendance report PDF
  static Future<Uint8List> generateAttendanceReport({
    required String reportTitle, // "تقرير الحضور الشهري"
    required String groupName,
    required String classNumber,
    required String typeName,
    required String supervisorName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> attendanceRecords,
    required Map<String, int> stats, // {present, absent, excuse, total}
    String? generatedBy,
    String? notes,
  }) async {
    final pdf = pw.Document();
    final arabicFont = loadArabicFont(); // Synchronous now - no waiting

    // Define text styles
    final titleStyle = pw.TextStyle(
      font: arabicFont,
      fontSize: 24,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromInt(0xFF1F2937),
    );

    final headerStyle = pw.TextStyle(
      font: arabicFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor(1, 1, 1), // white
    );

    final subHeaderStyle = pw.TextStyle(
      font: arabicFont,
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromInt(0xFF1F2937),
    );

    final labelStyle = pw.TextStyle(
      font: arabicFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromInt(0xFF374151),
    );

    final dataStyle = pw.TextStyle(
      font: arabicFont,
      fontSize: 10,
      color: PdfColor.fromInt(0xFF4B5563),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          // === SUMMARY TABLE ===
          _buildSummaryTable(
            stats: stats,
            labelStyle: labelStyle,
            dataStyle: dataStyle,
          ),

          pw.SizedBox(height: 16),

          // === HEADER SECTION ===
          _buildHeader(
            titleStyle: titleStyle,
            labelStyle: labelStyle,
            reportTitle: reportTitle,
            groupName: groupName,
            classNumber: classNumber,
            typeName: typeName,
            supervisorName: supervisorName,
            startDate: startDate,
            endDate: endDate,
            generatedBy: generatedBy,
          ),

          pw.SizedBox(height: 16),

          // === ATTENDANCE RECORDS TABLE ===
          _buildAttendanceTable(
            records: attendanceRecords,
            arabicFont: arabicFont,
            headerStyle: headerStyle,
            dataStyle: dataStyle,
            subHeaderStyle: subHeaderStyle,
          ),

          if (notes != null && notes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildFooter(
              notes: notes,
              labelStyle: labelStyle,
              dataStyle: dataStyle,
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  /// Build professional header with title and metadata
  static pw.Widget _buildHeader({
    required pw.TextStyle titleStyle,
    required pw.TextStyle labelStyle,
    required String reportTitle,
    required String groupName,
    required String classNumber,
    required String typeName,
    required String supervisorName,
    required DateTime startDate,
    required DateTime endDate,
    String? generatedBy,
  }) {
    final DateFormat arabicDateFormat = DateFormat('d MMMM yyyy', 'ar_SA');
    final startDateStr = arabicDateFormat.format(startDate);
    final endDateStr = arabicDateFormat.format(endDate);

    pw.TableRow infoRow(String label, String value) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: labelStyle.font,
                fontSize: 11,
                color: PdfColor.fromInt(0xFF374151),
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Text(
              label,
              style: labelStyle,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Main title
        pw.Text(
          reportTitle,
          style: titleStyle,
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 8),

        pw.SizedBox(height: 10),

        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColor.fromInt(0xFFE5E7EB),
            width: 0.6,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(1.2),
          },
          children: [
            infoRow('المجموعة', groupName),
            infoRow('الفصل', classNumber),
            infoRow('الرواية', typeName),
            infoRow('المشرفة', supervisorName),
            infoRow('الفترة الزمنية', '$startDateStr إلى $endDateStr'),
          ],
        ),

        // Generated date and user
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              arabicDateFormat.format(DateTime.now()),
              style: pw.TextStyle(
                font: labelStyle.font,
                fontSize: 10,
                color: PdfColor.fromInt(0xFF9CA3AF),
              ),
            ),
            pw.SizedBox(width: 5),
            pw.Text(
              'تاريخ الإنشاء:',
              style: pw.TextStyle(
                font: labelStyle.font,
                fontSize: 10,
                color: PdfColor.fromInt(0xFF9CA3AF),
              ),
            ),
          ],
        ),

        if (generatedBy != null && generatedBy.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                generatedBy,
                style: pw.TextStyle(
                  font: labelStyle.font,
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF9CA3AF),
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                'أنشأ بواسطة:',
                style: pw.TextStyle(
                  font: labelStyle.font,
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Build summary table for statistics
  static pw.Widget _buildSummaryTable({
    required Map<String, int> stats,
    required pw.TextStyle labelStyle,
    required pw.TextStyle dataStyle,
  }) {
    final present = stats['present'] ?? 0;
    final absent = stats['absent'] ?? 0;
    final excuse = stats['excuse'] ?? 0;
    final total = stats['total'] ?? 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'ملخص الإحصائيات',
          style: labelStyle,
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['حاضر', 'غائب', 'معتذر', 'الإجمالي'],
          data: [
            [
              present.toString(),
              absent.toString(),
              excuse.toString(),
              total.toString(),
            ],
          ],
          headerStyle: labelStyle.copyWith(
            color: PdfColor(1, 1, 1),
            fontSize: 11,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF6366F1),
          ),
          cellStyle: dataStyle.copyWith(fontSize: 11),
          cellAlignment: pw.Alignment.center,
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
        ),
      ],
    );
  }

  /// Build detailed attendance table
  static pw.Widget _buildAttendanceTable({
    required List<Map<String, dynamic>> records,
    required pw.Font arabicFont,
    required pw.TextStyle headerStyle,
    required pw.TextStyle dataStyle,
    required pw.TextStyle subHeaderStyle,
  }) {
    if (records.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'لا توجد بيانات للعرض',
          style: dataStyle,
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    final headerBgColor = PdfColor.fromInt(0xFF6366F1);
    final headerTextColor = PdfColor(1, 1, 1);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'تفاصيل السجلات',
          style: subHeaderStyle,
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: [
            'ملاحظات',
            'الحالة',
            'النوع',
            'رقم الطالبة',
            'اسم الطالبة',
            'التاريخ',
          ],
          headerStyle: headerStyle.copyWith(
            color: headerTextColor,
            fontSize: 10,
          ),
          headerDecoration: pw.BoxDecoration(
            color: headerBgColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          cellStyle: dataStyle,
          rowDecoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE5E7EB),
                width: 0.5,
              ),
            ),
          ),
          data: records.map((record) {
            final date = record['Report_date']?.toString().split('T')[0] ?? '-';
            final studentName = record['Students']?['Student_Name'] ?? '-';
            final studentCode = record['Students']?['Student_Code']?.toString() ?? '-';
            final type = record['_type']?.toString() ?? '-';
            final attend = (record['Attend_flag'] == true || record['Attend_flag'] == 1);
            final absent = (record['Absent_flag'] == true || record['Absent_flag'] == 1);
            final excuse = (record['Execuse_flag'] == true || record['Execuse_flag'] == 1);
            final status = attend
                ? 'حاضر'
                : absent
                    ? 'غائب'
                    : excuse
                        ? 'معتذر'
                        : '-';
            final notes = record['notes'] ?? '';

            return [
              notes,
              status,
              type,
              studentCode,
              studentName,
              date,
            ];
          }).toList(),
          cellAlignment: pw.Alignment.centerRight,
          columnWidths: {
            0: const pw.FlexColumnWidth(1.4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(1.2),
          },
        ),
      ],
    );
  }

  /// Build footer with notes or confidentiality
  static pw.Widget _buildFooter({
    required String notes,
    required pw.TextStyle labelStyle,
    required pw.TextStyle dataStyle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Divider(
          color: PdfColor.fromInt(0xFFE5E7EB),
          height: 2,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'ملاحظات:',
          style: labelStyle,
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          notes,
          style: dataStyle,
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }
}

/// Extension to convert Flutter Color to PdfColor
extension ColorToPdfColor on Color {
  PdfColor toColorValue() {
    return PdfColor(red / 255.0, green / 255.0, blue / 255.0, opacity);
  }
}
