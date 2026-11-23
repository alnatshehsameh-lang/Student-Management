import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../models/user_session.dart';
import '../widgets/responsive_table_container.dart';
import '../widgets/searchable_lov_field.dart';

class MonthlyAttendanceSummaryScreen extends StatefulWidget {
  final UserSession userSession;

  const MonthlyAttendanceSummaryScreen({
    super.key,
    required this.userSession,
  });

  @override
  State<MonthlyAttendanceSummaryScreen> createState() =>
      _MonthlyAttendanceSummaryScreenState();
}

class _MonthlyStudentSummary {
  final dynamic studentId;
  final String studentName;
  final String studentCode;
  int present;
  int absent;
  int excused;
  int other;

  _MonthlyStudentSummary({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    this.present = 0,
    this.absent = 0,
    this.excused = 0,
    this.other = 0,
  });

  int get total => present + absent + excused;

  String get percentageText {
    final denominator = total;
    if (denominator == 0) return '—';
    final percent = (present / denominator) * 100;
    return '${percent.toStringAsFixed(1)}%';
  }
}

class _PdfFonts {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font bold;

  _PdfFonts({
    required this.regular,
    required this.medium,
    required this.bold,
  });
}

class _MonthlyAttendanceSummaryScreenState
    extends State<MonthlyAttendanceSummaryScreen> {
  final _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _groups = [];
  final List<Map<String, dynamic>> _types = [];
  final List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _classes = [];

  final List<Map<String, dynamic>> _managerAssignments = [];

  int? _selectedGroupId;
  int? _selectedClassId;
  int? _selectedTypeId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  bool _filtersLoading = true;
  bool _loading = false;

  String _reportGroupName = 'الكل';
  String _reportClassName = 'الكل';
  String _reportTypeName = 'الكل';
  String _reportSupervisorName = 'الكل';
  DateTime _reportGeneratedAt = DateTime.now();

  List<_MonthlyStudentSummary> _rows = [];

  static const Map<int, String> _monthNames = {
    1: 'يناير',
    2: 'فبراير',
    3: 'مارس',
    4: 'أبريل',
    5: 'مايو',
    6: 'يونيو',
    7: 'يوليو',
    8: 'أغسطس',
    9: 'سبتمبر',
    10: 'أكتوبر',
    11: 'نوفمبر',
    12: 'ديسمبر',
  };

  @override
  void initState() {
    super.initState();
    _initFilters();
  }

  int _extractClassNumberForSort(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 1 << 30;
    final direct = int.tryParse(trimmed);
    if (direct != null) return direct;
    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? (1 << 30);
    }
    return 1 << 30;
  }

  int _compareClassRows(Map<String, dynamic> a, Map<String, dynamic> b) {
    final labelA = (a['Class_Number'] ?? '').toString();
    final labelB = (b['Class_Number'] ?? '').toString();
    final numA = _extractClassNumberForSort(labelA);
    final numB = _extractClassNumberForSort(labelB);
    final hasNumA = numA != (1 << 30);
    final hasNumB = numB != (1 << 30);
    if (hasNumA && hasNumB && numA != numB) return numA.compareTo(numB);
    if (hasNumA && !hasNumB) return -1;
    if (!hasNumA && hasNumB) return 1;
    return labelA.compareTo(labelB);
  }

  Future<void> _initFilters() async {
    setState(() => _filtersLoading = true);
    await _fetchUserRestrictions();
    await _loadFilterOptions();
    if (mounted) {
      setState(() => _filtersLoading = false);
    }
  }

  Future<void> _fetchUserRestrictions() async {
    if (widget.userSession.hasFullAccess || widget.userSession.userId == null) {
      return;
    }

    _managerAssignments
      ..clear()
      ..addAll(widget.userSession.managerAssignments);

    if (_managerAssignments.isNotEmpty) {
      return;
    }

    try {
      final response = await _client
          .from('Managers')
          .select(
            'id, Managers_Lines(Class_id, Group_id, Type_id, is_active, effective_from, effective_to)',
          )
          .eq('User_id', widget.userSession.userId!)
          .order('id');

      if (response is List && response.isNotEmpty) {
        final now = DateTime.now();
        for (final managerRow in List<Map<String, dynamic>>.from(response)) {
          final linesRaw = managerRow['Managers_Lines'];
          if (linesRaw is! List) continue;
          for (final line in List<Map<String, dynamic>>.from(linesRaw)) {
            final isActive = line['is_active'] == true;
            if (!isActive) continue;

            final fromDate = line['effective_from'] == null
                ? null
                : DateTime.tryParse(line['effective_from'].toString());
            final toDate = line['effective_to'] == null
                ? null
                : DateTime.tryParse(line['effective_to'].toString());

            if (fromDate != null && fromDate.isAfter(now)) continue;
            if (toDate != null && toDate.isBefore(now)) continue;

            _managerAssignments.add({
              'Class_id': line['Class_id'],
              'Group_id': line['Group_id'],
              'Type_id': line['Type_id'],
            });
          }
        }
      }
    } catch (_) {
      _managerAssignments.clear();
    }
  }

  List<int> _allowedIds(String key) {
    return _managerAssignments
        .map((e) => e[key])
        .whereType<int>()
        .toSet()
        .toList();
  }

  Future<void> _loadFilterOptions() async {
    final allowedGroupIds = _allowedIds('Group_id');
    final allowedTypeIds = _allowedIds('Type_id');
    final allowedClassIds = _allowedIds('Class_id');

    var groupsBuilder = _client.from('Groups').select('id, "Group_Name"');
    if (!widget.userSession.hasFullAccess) {
      if (allowedGroupIds.isNotEmpty) {
        groupsBuilder = groupsBuilder.in_('id', allowedGroupIds);
      } else if (widget.userSession.assignedGroupId != null) {
        groupsBuilder = groupsBuilder.eq('id', widget.userSession.assignedGroupId!);
      }
    }
    final groupsRes = await groupsBuilder.order('Group_Name');
    _groups
      ..clear()
      ..addAll(groupsRes is List ? List<Map<String, dynamic>>.from(groupsRes) : []);

    var typesBuilder = _client.from('Types').select('id, "Type"');
    if (!widget.userSession.hasFullAccess) {
      if (allowedTypeIds.isNotEmpty) {
        typesBuilder = typesBuilder.in_('id', allowedTypeIds);
      } else if (widget.userSession.assignedTypeId != null) {
        typesBuilder = typesBuilder.eq('id', widget.userSession.assignedTypeId!);
      }
    }
    final typesRes = await typesBuilder.order('Type');
    _types
      ..clear()
      ..addAll(typesRes is List ? List<Map<String, dynamic>>.from(typesRes) : []);

    var classesBuilder = _client.from('Classes').select('id, "Class_Number"');
    if (!widget.userSession.hasFullAccess) {
      if (allowedClassIds.isNotEmpty) {
        classesBuilder = classesBuilder.in_('id', allowedClassIds);
      } else if (widget.userSession.assignedClassId != null) {
        classesBuilder = classesBuilder.eq('id', widget.userSession.assignedClassId!);
      }
    }
    final classesRes = await classesBuilder.order('Class_Number');
    _allClasses
      ..clear()
      ..addAll(
        classesRes is List ? List<Map<String, dynamic>>.from(classesRes) : <Map<String, dynamic>>[],
      );
    _allClasses.sort(_compareClassRows);

    await _refreshClassesForGroup();
  }

  Future<void> _refreshClassesForGroup() async {
    if (_selectedGroupId == null) {
      _classes = List<Map<String, dynamic>>.from(_allClasses)..sort(_compareClassRows);
      if (_selectedClassId != null && !_classes.any((e) => e['id'] == _selectedClassId)) {
        _selectedClassId = null;
      }
      if (mounted) setState(() {});
      return;
    }

    final allowedClassIds = _allowedIds('Class_id');
    var builder = _client
        .from('Students')
        .select('Class_id, Classes(id, "Class_Number")')
        .eq('Group_id', _selectedGroupId!);

    if (_selectedTypeId != null) {
      builder = builder.eq('Type_id', _selectedTypeId!);
    }

    if (!widget.userSession.hasFullAccess && allowedClassIds.isNotEmpty) {
      builder = builder.in_('Class_id', allowedClassIds);
    }

    final rows = await builder;
    final byId = <int, Map<String, dynamic>>{};

    if (rows is List) {
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final classId = row['Class_id'];
        if (classId is! int) continue;
        String classNumber = '';
        if (row['Classes'] is List && (row['Classes'] as List).isNotEmpty) {
          final classRow = (row['Classes'] as List).first;
          classNumber = (classRow['Class_Number'] ?? '').toString();
        }
        final fallback = _allClasses
            .where((c) => c['id'] == classId)
            .cast<Map<String, dynamic>>()
            .toList();
        if (classNumber.isEmpty && fallback.isNotEmpty) {
          classNumber = (fallback.first['Class_Number'] ?? '').toString();
        }
        byId[classId] = {
          'id': classId,
          'Class_Number': classNumber,
        };
      }
    }

    _classes = byId.values.toList()..sort(_compareClassRows);
    if (_selectedClassId != null && !_classes.any((e) => e['id'] == _selectedClassId)) {
      _selectedClassId = null;
    }
    if (mounted) setState(() {});
  }

  bool _isAllowedByRestriction({
    dynamic groupId,
    dynamic classId,
    dynamic typeId,
  }) {
    if (widget.userSession.hasFullAccess) return true;

    if (_managerAssignments.isEmpty) {
      return widget.userSession.canAccessScope(
        groupId: groupId as int?,
        classId: classId as int?,
        typeId: typeId as int?,
      );
    }

    bool matches(dynamic assigned, dynamic selected) {
      if (selected == null) return true;
      if (assigned == null) return true;
      return assigned == selected;
    }

    return _managerAssignments.any((assignment) {
      return matches(assignment['Group_id'], groupId) &&
          matches(assignment['Class_id'], classId) &&
          matches(assignment['Type_id'], typeId);
    });
  }

  Future<void> _generateReport() async {
    if (!_isAllowedByRestriction(
      groupId: _selectedGroupId,
      classId: _selectedClassId,
      typeId: _selectedTypeId,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('النطاق المحدد غير مسموح به لهذا المستخدم')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final monthStart = DateTime(_selectedYear, _selectedMonth, 1);
      final monthEnd = DateTime(_selectedYear, _selectedMonth + 1, 0);
      final startStr =
          '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}-${monthStart.day.toString().padLeft(2, '0')}';
      final endStr =
          '${monthEnd.year}-${monthEnd.month.toString().padLeft(2, '0')}-${monthEnd.day.toString().padLeft(2, '0')}';

      var studentsBuilder = _client.from('Students').select(
            'id, "Student_Name", "Student_Code", "Class_id", "Group_id", "Type_id"',
          );

      if (_selectedGroupId != null) {
        studentsBuilder = studentsBuilder.eq('Group_id', _selectedGroupId!);
      }
      if (_selectedClassId != null) {
        studentsBuilder = studentsBuilder.eq('Class_id', _selectedClassId!);
      }
      if (_selectedTypeId != null) {
        studentsBuilder = studentsBuilder.eq('Type_id', _selectedTypeId!);
      }

      if (!widget.userSession.hasFullAccess) {
        final allowedGroups = _allowedIds('Group_id');
        final allowedClasses = _allowedIds('Class_id');
        final allowedTypes = _allowedIds('Type_id');

        if (_selectedGroupId == null && allowedGroups.isNotEmpty) {
          studentsBuilder = studentsBuilder.in_('Group_id', allowedGroups);
        }
        if (_selectedClassId == null && allowedClasses.isNotEmpty) {
          studentsBuilder = studentsBuilder.in_('Class_id', allowedClasses);
        }
        if (_selectedTypeId == null && allowedTypes.isNotEmpty) {
          studentsBuilder = studentsBuilder.in_('Type_id', allowedTypes);
        }
      }

      final studentsRes = await studentsBuilder;
      final students = studentsRes is List
          ? List<Map<String, dynamic>>.from(studentsRes)
          : <Map<String, dynamic>>[];

      if (students.isEmpty) {
        if (mounted) {
          setState(() {
            _rows = [];
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد طالبات مطابقات للمرشحات المحددة')),
          );
        }
        return;
      }

      final studentMap = <dynamic, Map<String, dynamic>>{};
      for (final student in students) {
        studentMap[student['id']] = student;
      }
      final studentIds = studentMap.keys.whereType<int>().toList();

      bool toBool(dynamic value) => value == true || value == 1;

      bool matchesContext(Map<String, dynamic> record, Map<String, dynamic> student) {
        final recordGroup = record['Attend_Group_id'];
        final recordClass = record['Attend_Class_id'];
        final recordType = record['Attend_Type_id'];

        final hasRecordContext =
            recordGroup != null || recordClass != null || recordType != null;

        final effectiveGroup = hasRecordContext ? recordGroup : student['Group_id'];
        final effectiveClass = hasRecordContext ? recordClass : student['Class_id'];
        final effectiveType = hasRecordContext ? recordType : student['Type_id'];

        if (_selectedGroupId != null && effectiveGroup != _selectedGroupId) {
          return false;
        }
        if (_selectedClassId != null && effectiveClass != _selectedClassId) {
          return false;
        }
        if (_selectedTypeId != null && effectiveType != _selectedTypeId) {
          return false;
        }

        return _isAllowedByRestriction(
          groupId: effectiveGroup,
          classId: effectiveClass,
          typeId: effectiveType,
        );
      }

      final summaryByStudent = <dynamic, _MonthlyStudentSummary>{};
      final seenRecordKeys = <String>{};

      Future<void> collectFromTable(String tableName) async {
        if (studentIds.isEmpty) return;

        final recordsRes = await _client
            .from(tableName)
            .select(
              'id, Student_id, Report_date, Attend_flag, Absent_flag, Execuse_flag, Attend_Group_id, Attend_Class_id, Attend_Type_id',
            )
            .in_('Student_id', studentIds)
            .gte('Report_date', startStr)
            .lte('Report_date', endStr);

        if (recordsRes is! List) return;

        for (final record in List<Map<String, dynamic>>.from(recordsRes)) {
          final studentId = record['Student_id'];
          final student = studentMap[studentId];
          if (student == null) continue;
          if (!matchesContext(record, student)) continue;

          final id = record['id'];
          final dedupeKey = id == null
              ? '$tableName:${record['Student_id']}:${record['Report_date']}:'
                    '${record['Attend_flag']}:${record['Absent_flag']}:${record['Execuse_flag']}'
              : '$tableName:$id';
          if (!seenRecordKeys.add(dedupeKey)) {
            continue;
          }

          final row = summaryByStudent.putIfAbsent(
            studentId,
            () => _MonthlyStudentSummary(
              studentId: studentId,
              studentName: (student['Student_Name'] ?? '').toString(),
              studentCode: (student['Student_Code'] ?? '').toString(),
            ),
          );

          final present = toBool(record['Attend_flag']);
          final absent = toBool(record['Absent_flag']);
          final excused = toBool(record['Execuse_flag']);

          if (present) {
            row.present += 1;
          } else if (absent) {
            row.absent += 1;
          } else if (excused) {
            row.excused += 1;
          } else {
            row.other += 1;
          }
        }
      }

      await collectFromTable('Attendance_Tadabur');
      await collectFromTable('Attendance_Sard');

      final generatedRows = summaryByStudent.values.toList()
        ..sort((a, b) {
          final byName = a.studentName.compareTo(b.studentName);
          if (byName != 0) return byName;
          return a.studentId.toString().compareTo(b.studentId.toString());
        });

      _reportGroupName = _resolveName(
        _groups,
        _selectedGroupId,
        'Group_Name',
      );
      _reportClassName = _resolveName(
        _classes,
        _selectedClassId,
        'Class_Number',
      );
      _reportTypeName = _resolveName(
        _types,
        _selectedTypeId,
        'Type',
      );
      _reportSupervisorName = await _resolveClassSupervisorName();
      _reportGeneratedAt = DateTime.now();

      if (mounted) {
        setState(() {
          _rows = generatedRows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء التقرير: $e')),
        );
      }
    }
  }

  String _resolveName(
    List<Map<String, dynamic>> source,
    int? selectedId,
    String key,
  ) {
    if (selectedId == null) return 'الكل';
    final row = source.where((e) => e['id'] == selectedId).cast<Map<String, dynamic>>().toList();
    if (row.isEmpty) return 'غير محدد';
    final name = (row.first[key] ?? '').toString().trim();
    return name.isEmpty ? 'غير محدد' : name;
  }

  Future<String> _resolveClassSupervisorName() async {
    if (_selectedGroupId == null || _selectedClassId == null) {
      return 'الكل';
    }

    try {
      final rows = await _client
          .from('Managers')
          .select(
            'full_name, Managers_Lines(Group_id, Class_id, is_active, effective_from, effective_to)',
          )
          .order('id');

      if (rows is List) {
        final now = DateTime.now();
        for (final manager in List<Map<String, dynamic>>.from(rows)) {
          final linesRaw = manager['Managers_Lines'];
          if (linesRaw is! List) continue;

          for (final line in List<Map<String, dynamic>>.from(linesRaw)) {
            final isActive = line['is_active'] == true;
            if (!isActive) continue;
            if (line['Group_id'] != _selectedGroupId) continue;
            if (line['Class_id'] != _selectedClassId) continue;

            final fromDate = line['effective_from'] == null
                ? null
                : DateTime.tryParse(line['effective_from'].toString());
            final toDate = line['effective_to'] == null
                ? null
                : DateTime.tryParse(line['effective_to'].toString());
            if (fromDate != null && fromDate.isAfter(now)) continue;
            if (toDate != null && toDate.isBefore(now)) continue;

            final name = (manager['full_name'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              return name;
            }
          }
        }
      }
    } catch (_) {}

    return 'غير محدد';
  }

  Future<pw.Font> _loadFontAsset(String assetPath) async {
    final fontData = await rootBundle.load(assetPath);
    return pw.Font.ttf(fontData);
  }

  Future<_PdfFonts> _loadPdfFonts() async {
    final regular = await _loadFontAsset('assets/fonts/Tajawal-Regular.ttf');

    pw.Font medium;
    try {
      medium = await _loadFontAsset('assets/fonts/Tajawal-Medium.ttf');
    } catch (_) {
      medium = regular;
    }

    pw.Font bold;
    try {
      bold = await _loadFontAsset('assets/fonts/Tajawal-Bold.ttf');
    } catch (_) {
      bold = medium;
    }

    return _PdfFonts(regular: regular, medium: medium, bold: bold);
  }

  Future<void> _exportToPdf() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }

    try {
      final fonts = await _loadPdfFonts();
      final pdf = pw.Document();

      final headerTitleStyle = pw.TextStyle(
        font: fonts.bold,
        fontSize: 20,
        color: PdfColors.white,
      );
      final headerSubtitleStyle = pw.TextStyle(
        font: fonts.medium,
        fontSize: 12,
        color: PdfColors.white,
      );
      final labelStyle = pw.TextStyle(
        font: fonts.bold,
        fontSize: 10,
        color: PdfColor.fromInt(0xFF111111),
      );
      final valueStyle = pw.TextStyle(
        font: fonts.medium,
        fontSize: 11,
        color: PdfColor.fromInt(0xFF000000),
      );
      final tableHeaderStyle = pw.TextStyle(
        font: fonts.bold,
        fontSize: 10,
        color: PdfColor.fromInt(0xFF111111),
      );
      final tableCellStyle = pw.TextStyle(
        font: fonts.medium,
        fontSize: 9,
        color: PdfColor.fromInt(0xFF000000),
      );

      final monthName = _monthNames[_selectedMonth] ?? _selectedMonth.toString();
      final generatedAt = _formatDateTime(_reportGeneratedAt);

      final dataRows = _rows.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final row = entry.value;
        return [
          index.toString(),
          row.studentName,
          row.studentCode,
          row.present.toString(),
          row.absent.toString(),
          row.excused.toString(),
          row.total.toString(),
          row.percentageText,
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          textDirection: pw.TextDirection.rtl,
          footer: (context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'تاريخ الإصدار: $generatedAt | صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: pw.TextStyle(font: fonts.regular, fontSize: 8),
              ),
            );
          },
          build: (_) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0F172A),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ملخص الحضور الشهري', style: headerTitleStyle),
                  pw.SizedBox(height: 4),
                  pw.Text('Monthly Attendance Summary', style: headerSubtitleStyle),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pdfInfoBox('المجموعة', _reportGroupName, labelStyle, valueStyle),
                _pdfInfoBox('الحلقة', _reportClassName, labelStyle, valueStyle),
                _pdfInfoBox('النوع', _reportTypeName, labelStyle, valueStyle),
                _pdfInfoBox('مشرف الحلقة', _reportSupervisorName, labelStyle, valueStyle),
                _pdfInfoBox('الشهر', monthName, labelStyle, valueStyle),
                _pdfInfoBox('السنة', _selectedYear.toString(), labelStyle, valueStyle),
                _pdfInfoBox('تاريخ إصدار التقرير', generatedAt, labelStyle, valueStyle),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: const [
                'م',
                'اسم الطالب',
                'رقم الطالب',
                'حاضر',
                'غائب',
                'معتذر',
                'الإجمالي',
                'نسبة الحضور',
              ],
              data: dataRows,
              headerStyle: tableHeaderStyle,
              cellStyle: tableCellStyle,
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFD1D5DB)),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE5E7EB),
              ),
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(2.4),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(0.9),
                5: const pw.FlexColumnWidth(0.9),
                6: const pw.FlexColumnWidth(0.9),
                7: const pw.FlexColumnWidth(1.1),
              },
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'monthly_attendance_summary_${DateTime.now().millisecondsSinceEpoch}.pdf',
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تصدير التقرير إلى PDF')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تصدير PDF: $e')),
        );
      }
    }
  }

  pw.Widget _pdfInfoBox(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Container(
      constraints: const pw.BoxConstraints(minWidth: 140, minHeight: 52),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD1D5DB)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: labelStyle),
          pw.SizedBox(height: 4),
          pw.Text(value, style: valueStyle),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMonthField() {
    return SearchableLovField<int>(
      value: _selectedMonth,
      labelText: 'الشهر',
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedMonth = value;
          _rows = [];
        });
      },
      items: _monthNames.entries
          .map(
            (entry) => SearchableLovItem<int>(
              value: entry.key,
              label: entry.value,
            ),
          )
          .toList(),
    );
  }

  Widget _buildYearField() {
    final current = DateTime.now().year;
    final years = List<int>.generate(8, (index) => current - 5 + index);

    return SearchableLovField<int>(
      value: _selectedYear,
      labelText: 'السنة',
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedYear = value;
          _rows = [];
        });
      },
      items: years
          .map((year) => SearchableLovItem<int>(value: year, label: year.toString()))
          .toList(),
    );
  }

  Widget _buildLookupField({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required String labelKey,
    required ValueChanged<int?> onChanged,
    bool includeAll = true,
  }) {
    return SearchableLovField<int?>(
      value: value,
      labelText: label,
      onChanged: onChanged,
      items: [
        if (includeAll)
          const SearchableLovItem<int?>(value: null, label: 'الكل'),
        ...items.map(
          (item) => SearchableLovItem<int?>(
            value: item['id'] as int?,
            label: (item[labelKey] ?? '').toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return ResponsiveTableContainer(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          const Color(0xFF0F172A).withOpacity(0.08),
        ),
        columns: const [
          DataColumn(label: Text('م')),
          DataColumn(label: Text('اسم الطالب')),
          DataColumn(label: Text('رقم الطالب')),
          DataColumn(label: Text('حاضر')),
          DataColumn(label: Text('غائب')),
          DataColumn(label: Text('معتذر')),
          DataColumn(label: Text('الإجمالي')),
          DataColumn(label: Text('نسبة الحضور')),
        ],
        rows: _rows.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final row = entry.value;
          return DataRow(
            color: WidgetStateProperty.resolveWith(
              (states) => index.isEven ? Colors.grey[50] : Colors.white,
            ),
            cells: [
              DataCell(Text(index.toString())),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(row.studentName),
                ),
              ),
              DataCell(Text(row.studentCode)),
              DataCell(Text(row.present.toString())),
              DataCell(Text(row.absent.toString())),
              DataCell(Text(row.excused.toString())),
              DataCell(Text(row.total.toString())),
              DataCell(Text(row.percentageText)),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ملخص الحضور الشهري'),
        centerTitle: true,
        actions: [
          if (_rows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
              onPressed: _exportToPdf,
            ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;
                        final controls = [
                          SizedBox(width: isWide ? 160 : double.infinity, child: _buildMonthField()),
                          SizedBox(width: isWide ? 130 : double.infinity, child: _buildYearField()),
                          SizedBox(
                            width: isWide ? 170 : double.infinity,
                            child: _buildLookupField(
                              label: 'المجموعة',
                              value: _selectedGroupId,
                              items: _groups,
                              labelKey: 'Group_Name',
                              onChanged: (value) async {
                                setState(() {
                                  _selectedGroupId = value;
                                  _rows = [];
                                });
                                await _refreshClassesForGroup();
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 170 : double.infinity,
                            child: _buildLookupField(
                              label: 'الحلقة',
                              value: _selectedClassId,
                              items: _classes,
                              labelKey: 'Class_Number',
                              onChanged: (value) {
                                setState(() {
                                  _selectedClassId = value;
                                  _rows = [];
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 170 : double.infinity,
                            child: _buildLookupField(
                              label: 'النوع',
                              value: _selectedTypeId,
                              items: _types,
                              labelKey: 'Type',
                              onChanged: (value) async {
                                setState(() {
                                  _selectedTypeId = value;
                                  _rows = [];
                                });
                                await _refreshClassesForGroup();
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 120 : double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _generateReport,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.search),
                              label: const Text('عرض'),
                            ),
                          ),
                        ];

                        if (isWide) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _intersperse(controls, const SizedBox(width: 10)),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _intersperse(controls, const SizedBox(height: 10)),
                        );
                      },
                    ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? Center(
                          child: Text(
                            'اختر المرشحات ثم اضغط عرض لإنشاء ملخص الحضور الشهري',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ملخص الحضور الشهري',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _metaChip('المجموعة', _reportGroupName),
                                        _metaChip('الحلقة', _reportClassName),
                                        _metaChip('النوع', _reportTypeName),
                                        _metaChip('مشرف الحلقة', _reportSupervisorName),
                                        _metaChip('الشهر', _monthNames[_selectedMonth] ?? ''),
                                        _metaChip('السنة', _selectedYear.toString()),
                                        _metaChip('تاريخ إصدار التقرير', _formatDateTime(_reportGeneratedAt)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTable(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
}
