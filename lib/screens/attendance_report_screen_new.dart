import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

class AttendanceReportScreenNew extends StatefulWidget {
  final UserSession userSession;
  const AttendanceReportScreenNew({super.key, required this.userSession});

  @override
  State<AttendanceReportScreenNew> createState() => _AttendanceReportScreenNewState();
}

class _AttendanceStats {
  final int attend;
  final int absent;
  final int excuse;

  const _AttendanceStats({required this.attend, required this.absent, required this.excuse});

  int get total => attend + absent + excuse;
}

class _AttendanceReportScreenNewState extends State<AttendanceReportScreenNew> {
  final _client = Supabase.instance.client;
  
  // Filters
  dynamic _selectedGroupId;
  dynamic _selectedTypeId;
  dynamic _selectedClassId;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Dropdown options
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _classes = [];
  
  // Report data
  List<Map<String, dynamic>> _reportData = [];
  bool _loading = false;
  bool _filtersLoading = true;
  
  // User restrictions
  int? _userGroupId;
  int? _userTypeId;
  int? _userClassId;

  @override
  void initState() {
    super.initState();
    _fetchUserRestrictions();
  }

  Future<void> _fetchUserRestrictions() async {
    if (widget.userSession.isAdmin || widget.userSession.userId == null) {
      _loadFilterOptions();
      return;
    }

    try {
      final response = await _client
          .from('Managers')
          .select('Class_id, Group_id, Type_id')
          .eq('User_id', widget.userSession.userId!)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _userClassId = response['Class_id'];
          _userGroupId = response['Group_id'];
          _userTypeId = response['Type_id'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch restrictions: $e');
    }
    
    if (mounted) _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    setState(() => _filtersLoading = true);
    try {
      // Load groups
      var groupsBuilder = _client.from('Groups').select('id, "Group_Name"');
      if (!widget.userSession.isAdmin && _userGroupId != null) {
        groupsBuilder = groupsBuilder.eq('id', _userGroupId!);
      }
      final groupsRes = await groupsBuilder.order('Group_Name');
      if (groupsRes is List) {
        _groups = List<Map<String, dynamic>>.from(groupsRes);
      }

      // Load types
      var typesBuilder = _client.from('Types').select('id, "Type"');
      if (!widget.userSession.isAdmin && _userTypeId != null) {
        typesBuilder = typesBuilder.eq('id', _userTypeId!);
      }
      final typesRes = await typesBuilder.order('Type');
      if (typesRes is List) {
        _types = List<Map<String, dynamic>>.from(typesRes);
      }

      // Load classes
      var classesBuilder = _client.from('Classes').select('id, "Class_Number"');
      if (!widget.userSession.isAdmin && _userClassId != null) {
        classesBuilder = classesBuilder.eq('id', _userClassId!);
      }
      final classesRes = await classesBuilder.order('Class_Number');
      if (classesRes is List) {
        _classes = List<Map<String, dynamic>>.from(classesRes);
      }

      if (mounted) setState(() => _filtersLoading = false);
    } catch (e) {
      debugPrint('Error loading filter options: $e');
      if (mounted) setState(() => _filtersLoading = false);
    }
  }

  Future<void> _generateReport() async {
    if (_selectedGroupId == null || _selectedTypeId == null || _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار جميع المرشحات')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نطاق التاريخ')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final startDateStr = _startDate!.toIso8601String().split('T')[0];
      final endDateStr = _endDate!.toIso8601String().split('T')[0];

      // Optimized query: get students with their attendance in one go
      final studentsRes = await _client
          .from('Students')
          .select('id, "Student_Name", "Student_Code"')
          .eq('Class_id', _selectedClassId)
          .eq('Group_id', _selectedGroupId)
          .eq('Type_id', _selectedTypeId);

      final students = (studentsRes is List)
          ? List<Map<String, dynamic>>.from(studentsRes)
          : <Map<String, dynamic>>[];

      if (students.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد طلاب مطابقين')),
          );
        }
        return;
      }

      final studentIds = students.map((s) => s['id']).toList();
      final studentMap = <dynamic, Map<String, dynamic>>{};
      for (final student in students) {
        studentMap[student['id']] = student;
      }

      final combined = <Map<String, dynamic>>[];

      // Fetch Tadabur attendance
      final tadaburRes = await _client
          .from('Attendance_Tadabur')
          .select('*')
          .in_('Student_id', studentIds)
          .gte('Report_date', startDateStr)
          .lte('Report_date', endDateStr);

      if (tadaburRes is List) {
        for (final record in List<Map<String, dynamic>>.from(tadaburRes)) {
          final studentId = record['Student_id'];
          if (studentMap.containsKey(studentId)) {
            combined.add({
              ...record,
              'Students': studentMap[studentId],
              '_type': 'تدبر',
            });
          }
        }
      }

      // Fetch Sard attendance
      final sardRes = await _client
          .from('Attendance_Sard')
          .select('*')
          .in_('Student_id', studentIds)
          .gte('Report_date', startDateStr)
          .lte('Report_date', endDateStr);

      if (sardRes is List) {
        for (final record in List<Map<String, dynamic>>.from(sardRes)) {
          final studentId = record['Student_id'];
          if (studentMap.containsKey(studentId)) {
            combined.add({
              ...record,
              'Students': studentMap[studentId],
              '_type': 'سرد',
            });
          }
        }
      }

      // Sort by date descending
      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['Report_date'].toString()) ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['Report_date'].toString()) ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _reportData = combined;
          _loading = false;
        });
        
        if (combined.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد سجلات حضور للفترة المحددة')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }

    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['تقرير_الحضور'];

      // Add headers
      sheet.appendRow([
        excel_pkg.TextCellValue('التاريخ'),
        excel_pkg.TextCellValue('اسم الطالب'),
        excel_pkg.TextCellValue('رقم الطالب'),
        excel_pkg.TextCellValue('النوع'),
        excel_pkg.TextCellValue('حاضر'),
        excel_pkg.TextCellValue('غائب'),
        excel_pkg.TextCellValue('معتذر'),
      ]);

      // Add data rows
      for (final record in _reportData) {
        final date = record['Report_date']?.toString().split('T')[0] ?? '';
        final studentName = record['Students']?['Student_Name'] ?? '';
        final studentCode = record['Students']?['Student_Code']?.toString() ?? '';
        final type = record['_type'] ?? '';
        final attend = (record['Attend_flag'] == true || record['Attend_flag'] == 1) ? 'نعم' : 'لا';
        final absent = (record['Absent_flag'] == true || record['Absent_flag'] == 1) ? 'نعم' : 'لا';
        final excuse = (record['Execuse_flag'] == true || record['Execuse_flag'] == 1) ? 'نعم' : 'لا';

        sheet.appendRow([
          excel_pkg.TextCellValue(date),
          excel_pkg.TextCellValue(studentName),
          excel_pkg.TextCellValue(studentCode),
          excel_pkg.TextCellValue(type),
          excel_pkg.TextCellValue(attend),
          excel_pkg.TextCellValue(absent),
          excel_pkg.TextCellValue(excuse),
        ]);
      }

      // Save file
      final bytes = excel.encode();
      if (bytes != null) {
        final blob = html.Blob([Uint8List.fromList(bytes)]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'attendance_report_${DateTime.now().millisecondsSinceEpoch}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تصدير التقرير إلى Excel')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      // Load Arabic font from Google Fonts
      final arabicFontData = await _loadArabicFont();

      // Create Arabic-supporting text style with the custom font
      final arabicStyle = pw.TextStyle(
        fontSize: 12,
        font: arabicFontData,
      );
      
      final arabicHeaderStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        font: arabicFontData,
      );

      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير الحضور',
                style: arabicHeaderStyle,
                textDirection: pw.TextDirection.rtl,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'اسم الطالب', 'رقم الطالب', 'النوع', 'حاضر', 'غائب', 'معتذر'],
              headerStyle: arabicHeaderStyle,
              cellStyle: arabicStyle,
              data: _reportData.map((record) {
                final date = record['Report_date']?.toString().split('T')[0] ?? '';
                final studentName = record['Students']?['Student_Name'] ?? '';
                final studentCode = record['Students']?['Student_Code']?.toString() ?? '';
                final type = record['_type'] ?? '';
                final attend = (record['Attend_flag'] == true || record['Attend_flag'] == 1) ? 'نعم' : 'لا';
                final absent = (record['Absent_flag'] == true || record['Absent_flag'] == 1) ? 'نعم' : 'لا';
                final excuse = (record['Execuse_flag'] == true || record['Execuse_flag'] == 1) ? 'نعم' : 'لا';

                return [date, studentName, studentCode, type, attend, absent, excuse];
              }).toList(),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
          textDirection: pw.TextDirection.rtl,
        ),
      );

      final bytes = await pdf.save();
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'attendance_report_${DateTime.now().millisecondsSinceEpoch}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير التقرير إلى PDF')),
        );
      }
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: $e')),
        );
      }
    }
  }

  Future<pw.Font> _loadArabicFont() async {
    try {
      // Try Amiri font - a well-known Arabic font
      final response = await html.HttpRequest.request(
        'https://github.com/alif-type/amiri/raw/main/Amiri-Regular.ttf',
        responseType: 'arraybuffer',
      );
      final byteBuffer = response.response as ByteBuffer;
      final fontData = byteBuffer.asByteData();
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Error loading Amiri font, trying alternative: $e');
      try {
        // Fallback to Tajawal font
        final response = await html.HttpRequest.request(
          'https://fonts.gstatic.com/s/tajawal/v9/Iurf6YBj_oCad4k1l_6gLrZjiLlJ-G0.ttf',
          responseType: 'arraybuffer',
        );
        final byteBuffer = response.response as ByteBuffer;
        final fontData = byteBuffer.asByteData();
        return pw.Font.ttf(fontData);
      } catch (e2) {
        debugPrint('Error loading Tajawal font: $e2');
        // Last resort fallback
        return pw.Font.helvetica();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الحضور'),
        centerTitle: true,
        actions: [
          if (_reportData.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'تصدير Excel',
              onPressed: _exportToExcel,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
              onPressed: _exportToPDF,
            ),
          ],
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Compact Dashboard-style Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _filtersLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildFiltersRow(),
            ),
            // Report Results
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _reportData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'اختر المرشحات واضغط "عرض" لإنشاء التقرير',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : _buildReportAndCharts(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required dynamic value,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required String nameKey,
    required Function(dynamic) onChanged,
  }) {
    return DropdownButtonFormField<dynamic>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('الكل')),
        ...items.map((item) {
          return DropdownMenuItem(
            value: item[idKey],
            child: Text(item[nameKey]?.toString() ?? ''),
          );
        }),
      ],
    );
  }

  Widget _buildCompactDatePicker({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date == null ? 'اختر التاريخ' : date.toIso8601String().split('T')[0],
          style: TextStyle(
            color: date == null ? Colors.grey : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF6366F1).withOpacity(0.1)),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('اسم الطالب', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('رقم الطالب', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('النوع', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('حاضر', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('غائب', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('معتذر', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _reportData.map((record) {
            final date = record['Report_date']?.toString().split('T')[0] ?? '';
            final studentName = record['Students']?['Student_Name'] ?? '';
            final studentCode = record['Students']?['Student_Code']?.toString() ?? '';
            final type = record['_type'] ?? '';
            final attend = record['Attend_flag'] == true || record['Attend_flag'] == 1;
            final absent = record['Absent_flag'] == true || record['Absent_flag'] == 1;
            final excuse = record['Execuse_flag'] == true || record['Execuse_flag'] == 1;

            return DataRow(
              cells: [
                DataCell(Text(date)),
                DataCell(Text(studentName)),
                DataCell(Text(studentCode)),
                DataCell(Text(type)),
                DataCell(Icon(attend ? Icons.check_circle : Icons.remove_circle_outline, color: attend ? Colors.green : Colors.grey, size: 20)),
                DataCell(Icon(absent ? Icons.check_circle : Icons.remove_circle_outline, color: absent ? Colors.red : Colors.grey, size: 20)),
                DataCell(Icon(excuse ? Icons.check_circle : Icons.remove_circle_outline, color: excuse ? Colors.orange : Colors.grey, size: 20)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final filterControls = [
          SizedBox(
            width: isWide ? 180 : double.infinity,
            child: _buildCompactDropdown(
              label: 'المجموعة',
              value: _selectedGroupId,
              items: _groups,
              idKey: 'id',
              nameKey: 'Group_Name',
              onChanged: (value) {
                setState(() {
                  _selectedGroupId = value;
                  _reportData = [];
                });
              },
            ),
          ),
          SizedBox(
            width: isWide ? 180 : double.infinity,
            child: _buildCompactDropdown(
              label: 'الرواية',
              value: _selectedTypeId,
              items: _types,
              idKey: 'id',
              nameKey: 'Type',
              onChanged: (value) {
                setState(() {
                  _selectedTypeId = value;
                  _reportData = [];
                });
              },
            ),
          ),
          SizedBox(
            width: isWide ? 180 : double.infinity,
            child: _buildCompactDropdown(
              label: 'الحلقة',
              value: _selectedClassId,
              items: _classes,
              idKey: 'id',
              nameKey: 'Class_Number',
              onChanged: (value) {
                setState(() {
                  _selectedClassId = value;
                  _reportData = [];
                });
              },
            ),
          ),
          SizedBox(
            width: isWide ? 160 : double.infinity,
            child: _buildCompactDatePicker(
              label: 'من تاريخ',
              date: _startDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _startDate = picked;
                    _reportData = [];
                  });
                }
              },
            ),
          ),
          SizedBox(
            width: isWide ? 160 : double.infinity,
            child: _buildCompactDatePicker(
              label: 'إلى تاريخ',
              date: _endDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _endDate = picked;
                    _reportData = [];
                  });
                }
              },
            ),
          ),
          SizedBox(
            width: isWide ? 130 : double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generateReport,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('عرض'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];

        if (isWide) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ..._intersperse(filterControls, const SizedBox(width: 12)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._intersperse(filterControls, const SizedBox(height: 10)),
          ],
        );
      },
    );
  }

  List<Widget> _intersperse(List<Widget> items, Widget spacer) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) result.add(spacer);
    }
    return result;
  }

  _AttendanceStats _computeStats() {
    var attend = 0;
    var absent = 0;
    var excuse = 0;

    for (final record in _reportData) {
      if (record['Attend_flag'] == true || record['Attend_flag'] == 1) attend++;
      if (record['Absent_flag'] == true || record['Absent_flag'] == 1) absent++;
      if (record['Execuse_flag'] == true || record['Execuse_flag'] == 1) excuse++;
    }

    return _AttendanceStats(attend: attend, absent: absent, excuse: excuse);
  }

  Widget _buildReportAndCharts() {
    final stats = _computeStats();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        if (isNarrow) {
          return Column(
            children: [
              _buildChartsPanel(stats),
              const SizedBox(height: 12),
              Expanded(child: _buildReportTable()),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildReportTable()),
            const SizedBox(width: 16),
            SizedBox(width: 320, child: _buildChartsPanel(stats)),
          ],
        );
      },
    );
  }

  Widget _buildChartsPanel(_AttendanceStats stats) {
    final double total = stats.total == 0 ? 1.0 : stats.total.toDouble();
    final sections = _buildPieSections(stats, total);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ملخص الحضور',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: sections.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد بيانات للحساب',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildLegendRow('حضور', stats.attend, Colors.green),
                _buildLegendRow('غياب', stats.absent, Colors.red),
                _buildLegendRow('اعتذار', stats.excuse, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(_AttendanceStats stats, double total) {
    final items = <PieChartSectionData>[];

    void addSection(double value, Color color) {
      if (value <= 0) return;
      final percent = (value / total * 100).round();
      items.add(
        PieChartSectionData(
          color: color,
          value: value,
          title: '$percent%',
          radius: 70,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      );
    }

    addSection(stats.attend.toDouble(), Colors.green);
    addSection(stats.absent.toDouble(), Colors.red);
    addSection(stats.excuse.toDouble(), Colors.orange);

    return items;
  }

  Widget _buildLegendRow(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: $value'),
      ],
    );
  }
}
