import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';

/// Enhanced PDF Generator with full Arabic support and professional layout
class AttendancePdfGenerator {
  /// Load Arabic TTF font from external source
  /// Tries multiple sources for reliability
  static Future<pw.Font> loadArabicFont() async {
    try {
      // Primary: Amiri font (excellent Arabic support)
      final response = await html.HttpRequest.request(
        'https://github.com/alif-type/amiri/raw/main/Amiri-Regular.ttf',
        responseType: 'arraybuffer',
      );
      final byteBuffer = response.response as ByteBuffer;
      final fontData = byteBuffer.asByteData();
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Amiri font failed: $e, trying Tajawal...');
      try {
        // Fallback: Tajawal font
        final response = await html.HttpRequest.request(
          'https://fonts.gstatic.com/s/tajawal/v9/Iurf6YBj_oCad4k1l_6gLrZjiLlJ-G0.ttf',
          responseType: 'arraybuffer',
        );
        final byteBuffer = response.response as ByteBuffer;
        final fontData = byteBuffer.asByteData();
        return pw.Font.ttf(fontData);
      } catch (e2) {
        debugPrint('Tajawal font failed: $e2, trying Scheherazade...');
        try {
          // Fallback: Scheherazade font (SIL Open Font)
          final response = await html.HttpRequest.request(
            'https://github.com/silnrsi/scheherazade/raw/master/font/Scheherazade-Regular.ttf',
            responseType: 'arraybuffer',
          );
          final byteBuffer = response.response as ByteBuffer;
          final fontData = byteBuffer.asByteData();
          return pw.Font.ttf(fontData);
        } catch (e3) {
          debugPrint('All Arabic fonts failed: $e3. Using fallback.');
          return pw.Font.helvetica();
        }
      }
    }
  }

  /// Generate professional attendance report PDF
  static Future<Uint8List> generateAttendanceReport({
    required String reportTitle, // "تقرير الحضور الشهري"
    required String departmentName, // "قسم القرآن الكريم"
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> attendanceRecords,
    required Map<String, int> stats, // {present, absent, excuse, total}
    String? generatedBy,
    String? notes,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await loadArabicFont();

    // Define colors
    const Color headerColor = Color(0xFF6366F1); // Purple
    const Color presentColor = Color(0xFF10B981); // Green
    const Color absentColor = Color(0xFFEF4444); // Red
    const Color excuseColor = Color(0xFFF59E0B); // Amber
    const Color borderColor = Color(0xFFE5E7EB); // Light gray

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

    final statValueStyle = pw.TextStyle(
      font: arabicFont,
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
      color: headerColor.toColorValue(),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        textDirection: pw.TextDirection.rtl,
        build: (context) {
          return pw.Column(
            children: [
              // === HEADER SECTION ===
              _buildHeader(
                titleStyle: titleStyle,
                labelStyle: labelStyle,
                reportTitle: reportTitle,
                departmentName: departmentName,
                startDate: startDate,
                endDate: endDate,
                generatedBy: generatedBy,
              ),

              pw.SizedBox(height: 20),

              // === STATISTICS SUMMARY SECTION ===
              _buildStatisticsSummary(
                stats: stats,
                statValueStyle: statValueStyle,
                labelStyle: labelStyle,
                dataStyle: dataStyle,
                presentColor: presentColor,
                absentColor: absentColor,
                excuseColor: excuseColor,
              ),

              pw.SizedBox(height: 20),

              // === ATTENDANCE RECORDS TABLE ===
              _buildAttendanceTable(
                records: attendanceRecords,
                arabicFont: arabicFont,
                headerStyle: headerStyle,
                dataStyle: dataStyle,
                subHeaderStyle: subHeaderStyle,
              ),

              pw.SizedBox(height: 20),

              // === FOOTER SECTION ===
              if (notes != null && notes.isNotEmpty)
                _buildFooter(
                  notes: notes,
                  labelStyle: labelStyle,
                  dataStyle: dataStyle,
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Build professional header with title and metadata
  static pw.Widget _buildHeader({
    required pw.TextStyle titleStyle,
    required pw.TextStyle labelStyle,
    required String reportTitle,
    required String departmentName,
    required DateTime startDate,
    required DateTime endDate,
    String? generatedBy,
  }) {
    final DateFormat arabicDateFormat = DateFormat('d MMMM yyyy', 'ar_SA');
    final startDateStr = arabicDateFormat.format(startDate);
    final endDateStr = arabicDateFormat.format(endDate);

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

        // Department
        pw.Text(
          departmentName,
          style: pw.TextStyle(
            font: titleStyle.font,
            fontSize: 13,
            color: PdfColor.fromInt(0xFF6B7280),
          ),
          textAlign: pw.TextAlign.right,
        ),
        pw.SizedBox(height: 12),

        // Date range
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              '$startDateStr إلى $endDateStr',
              style: labelStyle,
            ),
            pw.SizedBox(width: 5),
            pw.Text(
              'الفترة الزمنية:',
              style: labelStyle,
            ),
          ],
        ),

        // Generated date and user
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              '${arabicDateFormat.format(DateTime.now())}',
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

  /// Build statistics summary with colorful cards
  static pw.Widget _buildStatisticsSummary({
    required Map<String, int> stats,
    required pw.TextStyle statValueStyle,
    required pw.TextStyle labelStyle,
    required pw.TextStyle dataStyle,
    required Color presentColor,
    required Color absentColor,
    required Color excuseColor,
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
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              label: 'المجموع',
              value: total.toString(),
              color: PdfColor.fromInt(0xFF6B7280),
              valueStyle: statValueStyle,
              labelStyle: dataStyle,
            ),
            _buildStatCard(
              label: 'معتذر',
              value: excuse.toString(),
              color: excuseColor.toColorValue(),
              valueStyle: statValueStyle,
              labelStyle: dataStyle,
            ),
            _buildStatCard(
              label: 'غائب',
              value: absent.toString(),
              color: absentColor.toColorValue(),
              valueStyle: statValueStyle,
              labelStyle: dataStyle,
            ),
            _buildStatCard(
              label: 'حاضر',
              value: present.toString(),
              color: presentColor.toColorValue(),
              valueStyle: statValueStyle,
              labelStyle: dataStyle,
            ),
          ],
        ),
      ],
    );
  }

  /// Build individual stat card
  static pw.Widget _buildStatCard({
    required String label,
    required String value,
    required PdfColor color,
    required pw.TextStyle valueStyle,
    required pw.TextStyle labelStyle,
  }) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: valueStyle.copyWith(color: color),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: labelStyle,
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
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
            'معتذر',
            'غائب',
            'حاضر',
            'رقم الطالب',
            'اسم الطالب',
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
            final attend = (record['Attend_flag'] == true || record['Attend_flag'] == 1) ? '✓' : '';
            final absent = (record['Absent_flag'] == true || record['Absent_flag'] == 1) ? '✓' : '';
            final excuse =
                (record['Execuse_flag'] == true || record['Execuse_flag'] == 1) ? '✓' : '';
            final notes = record['notes'] ?? '';

            return [
              notes,
              excuse,
              absent,
              attend,
              studentCode,
              studentName,
              date,
            ];
          }).toList(),
          cellAlignment: pw.Alignment.centerRight,
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(0.8),
            3: const pw.FlexColumnWidth(0.8),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(2),
            6: const pw.FlexColumnWidth(1.2),
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
