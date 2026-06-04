import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_session.dart';
import '../widgets/searchable_lov_field.dart';

class ReportsDashboardScreen extends StatefulWidget {
  final UserSession userSession;

  const ReportsDashboardScreen({super.key, required this.userSession});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _StudentAttendanceStats {
  final int total;
  final int present;
  final int absent;

  const _StudentAttendanceStats({
    required this.total,
    required this.present,
    required this.absent,
  });

  double get percent => total == 0 ? 0 : (present / total) * 100;
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _filtersLoading = true;
  String? _error;

  DateTime? _startDate;
  DateTime? _endDate;
  dynamic _selectedClassId;
  dynamic _selectedGroupId;
  dynamic _selectedTypeId;
  String? _selectedStatus;
  String? _selectedBranch;

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _managerAssignments = [];

  final Map<dynamic, String> _classMap = {};
  final Map<dynamic, String> _groupMap = {};
  final Map<dynamic, String> _typeMap = {};

  Set<String> _studentColumns = {};
  String? _statusColumn;
  String? _branchColumn;
  String? _createdAtColumn;

  List<String> _schemaLimitations = [];

  int _totalStudents = 0;
  int? _newLast7Days;
  int? _newThisMonth;
  int _lowAttendanceStudents = 0;
  int _recentAbsentStudents = 0;
  int _incompleteStudents = 0;
  int _totalClasses = 0;
  int _totalGroups = 0;
  int _totalTypes = 0;
  double _attendanceAvgPercent = 0;

  Map<String, int> _studentsByClass = {};
  Map<String, int> _studentsByGroup = {};
  Map<String, int> _studentsByStatus = {};
  Map<String, int> _studentsByBranch = {};
  Map<String, int> _topClassesByStudent = {};
  Map<String, int> _lowAttendanceByClass = {};
  Map<String, int> _lowAttendanceByGroup = {};
  Map<String, double> _attendanceByClass = {};
  Map<String, double> _attendanceByGroup = {};
  Map<String, int> _registrationsByDate = {};
  Map<String, double> _attendanceTrendByDate = {};
  List<Map<String, dynamic>> _lowAttendanceList = [];
  List<Map<String, dynamic>> _recentStudents = [];

  @override
  void initState() {
    super.initState();
    _initData();
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

  String _resolveGroupLabel(Map<String, dynamic> student) {
    return (student['Group_Name']?.toString().trim().isNotEmpty == true)
        ? student['Group_Name'].toString()
        : (_groupMap[student['Group_id']] ??
              (student['Group_id']?.toString() ?? 'غير مصنف'));
  }

  String _resolveClassLabel(Map<String, dynamic> student) {
    return (student['Class_Number']?.toString().trim().isNotEmpty == true)
        ? student['Class_Number'].toString()
        : (_classMap[student['Class_id']] ??
              (student['Class_id']?.toString() ?? 'غير مصنف'));
  }

  String _resolveClassGroupLabel(Map<String, dynamic> student) {
    final groupLabel = _resolveGroupLabel(student);
    final classLabel = _resolveClassLabel(student);
    return '$groupLabel - $classLabel';
  }

  Future<void> _initData() async {
    await _fetchRestrictions();
    await _loadFilterOptions();
    await _discoverStudentSchema();
    await _loadDashboard();
  }

  Future<void> _fetchRestrictions() async {
    if (widget.userSession.hasFullAccess || widget.userSession.userId == null) {
      return;
    }

    try {
      final response = await _client
          .from('Managers')
          .select('Class_id, Group_id, Type_id')
          .eq('User_id', widget.userSession.userId!)
          .order('id');

      if (response is List && response.isNotEmpty) {
        _managerAssignments = List<Map<String, dynamic>>.from(response);
      }
    } catch (_) {
      _managerAssignments = [];
    }
  }

  Future<void> _loadFilterOptions() async {
    setState(() => _filtersLoading = true);
    try {
      final allowedClassIds = _managerAssignments
          .map((e) => e['Class_id'])
          .whereType<int>()
          .toSet()
          .toList();
      final allowedGroupIds = _managerAssignments
          .map((e) => e['Group_id'])
          .whereType<int>()
          .toSet()
          .toList();
      final allowedTypeIds = _managerAssignments
          .map((e) => e['Type_id'])
          .whereType<int>()
          .toSet()
          .toList();

      var groupsBuilder = _client.from('Groups').select('id, "Group_Name"');
      if (!widget.userSession.hasFullAccess && allowedGroupIds.isNotEmpty) {
        groupsBuilder = groupsBuilder.in_('id', allowedGroupIds);
      }
      final groupsRes = await groupsBuilder.order('Group_Name');
      _groups = groupsRes is List
          ? List<Map<String, dynamic>>.from(groupsRes)
          : <Map<String, dynamic>>[];

      var classesBuilder = _client.from('Classes').select('id, "Class_Number"');
      if (!widget.userSession.hasFullAccess && allowedClassIds.isNotEmpty) {
        classesBuilder = classesBuilder.in_('id', allowedClassIds);
      }
      final classesRes = await classesBuilder.order('Class_Number');
      _classes = classesRes is List
          ? List<Map<String, dynamic>>.from(classesRes)
          : <Map<String, dynamic>>[];
      _classes.sort(_compareClassRows);

      var typesBuilder = _client.from('Types').select('id, "Type"');
      if (!widget.userSession.hasFullAccess && allowedTypeIds.isNotEmpty) {
        typesBuilder = typesBuilder.in_('id', allowedTypeIds);
      }
      final typesRes = await typesBuilder.order('Type');
      _types = typesRes is List
          ? List<Map<String, dynamic>>.from(typesRes)
          : <Map<String, dynamic>>[];

      _classMap
        ..clear()
        ..addEntries(_classes.map((e) => MapEntry(e['id'], (e['Class_Number'] ?? '').toString())));
      _groupMap
        ..clear()
        ..addEntries(_groups.map((e) => MapEntry(e['id'], (e['Group_Name'] ?? '').toString())));
      _typeMap
        ..clear()
        ..addEntries(_types.map((e) => MapEntry(e['id'], (e['Type'] ?? '').toString())));

      _totalClasses = _classes.length;
      _totalGroups = _groups.length;
      _totalTypes = _types.length;
    } catch (e) {
      _error = 'فشل تحميل المرشحات: $e';
    } finally {
      if (mounted) {
        setState(() => _filtersLoading = false);
      }
    }
  }

  Future<void> _discoverStudentSchema() async {
    _schemaLimitations = [];
    try {
      final sample = await _client.from('Students').select('*').limit(1);
      if (sample is List && sample.isNotEmpty && sample.first is Map<String, dynamic>) {
        _studentColumns = Set<String>.from((sample.first as Map<String, dynamic>).keys);
      } else {
        _studentColumns = {
          'id',
          'created_at',
          'Student_Name',
          'Student_Code',
          'Mobile_No',
          'Class_Number',
          'Group_Name',
          'Type',
          'Class_id',
          'Group_id',
          'Type_id',
        };
      }
    } catch (_) {
      _studentColumns = {
        'id',
        'created_at',
        'Student_Name',
        'Student_Code',
        'Mobile_No',
        'Class_Number',
        'Group_Name',
        'Type',
        'Class_id',
        'Group_id',
        'Type_id',
      };
    }

    _statusColumn = _firstExisting(['status', 'Status', 'Student_Status']);
    _branchColumn = _firstExisting(['Branch', 'branch', 'Location', 'location']);
    _createdAtColumn = _firstExisting(['created_at', 'Created_at', 'CreatedAt']) ?? 'created_at';

    if (_statusColumn == null) {
      _schemaLimitations.add('حقل حالة الطالب غير موجود في المخطط الحالي (status / is_active).');
    }
    if (_branchColumn == null) {
      _schemaLimitations.add('حقل الفرع/الموقع غير موجود في المخطط الحالي.');
    }
    if (_createdAtColumn == null) {
      _schemaLimitations.add('حقل تاريخ التسجيل غير متوفر (created_at).');
    }
  }

  String? _firstExisting(List<String> candidates) {
    for (final col in candidates) {
      if (_studentColumns.contains(col)) return col;
    }
    return null;
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await _loadStudents();
      final attendance = await _loadAttendanceForStudents(students);
      _computeMetrics(students, attendance);
    } catch (e) {
      _error = 'فشل تحميل لوحة التقارير: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadStudents() async {
    final selectColumns = <String>{
      'id',
      'created_at',
      'Student_Name',
      'Student_Code',
      'Mobile_No',
      'Class_Number',
      'Group_Name',
      'Type',
      'Class_id',
      'Group_id',
      'Type_id',
    };

    for (final optional in [
      _statusColumn,
      _branchColumn,
      _createdAtColumn,
    ]) {
      if (optional != null) selectColumns.add(optional);
    }

    final columnsCsv = selectColumns.join(', ');
    const pageSize = 1000;
    var from = 0;
    final results = <Map<String, dynamic>>[];

    while (true) {
      var query = _client.from('Students').select(columnsCsv);

      if (_selectedClassId != null) {
        query = query.eq('Class_id', _selectedClassId);
      }
      if (_selectedGroupId != null) {
        query = query.eq('Group_id', _selectedGroupId);
      }
      if (_selectedTypeId != null) {
        query = query.eq('Type_id', _selectedTypeId);
      }
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty && _statusColumn != null) {
        query = query.eq(_statusColumn!, _selectedStatus!);
      }
      if (_selectedBranch != null && _selectedBranch!.isNotEmpty && _branchColumn != null) {
        query = query.eq(_branchColumn!, _selectedBranch!);
      }
      if (_startDate != null && _createdAtColumn != null) {
        query = query.gte(_createdAtColumn!, _startDate!.toIso8601String());
      }
      if (_endDate != null && _createdAtColumn != null) {
        query = query.lte(
          _createdAtColumn!,
          _endDate!.add(const Duration(days: 1)).toIso8601String(),
        );
      }

      final page = await query.range(from, from + pageSize - 1);
      if (page is! List || page.isEmpty) {
        break;
      }

      results.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < pageSize) {
        break;
      }
      from += pageSize;

      if (results.length > 25000) {
        break;
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> _loadAttendanceForStudents(
    List<Map<String, dynamic>> students,
  ) async {
    if (students.isEmpty) return [];

    final studentIds = students.map((s) => s['id']).where((id) => id != null).toList();
    if (studentIds.isEmpty) return [];

    final result = <Map<String, dynamic>>[];
    const chunkSize = 200;

    Future<void> fetchTable(String table, String sourceLabel) async {
      for (var i = 0; i < studentIds.length; i += chunkSize) {
        final end = (i + chunkSize > studentIds.length) ? studentIds.length : i + chunkSize;
        final chunk = studentIds.sublist(i, end);

        var query = _client
            .from(table)
            .select('Student_id, Attend_flag, Absent_flag, Execuse_flag, Report_date')
            .in_('Student_id', chunk);

        if (_startDate != null) {
          query = query.gte('Report_date', _startDate!.toIso8601String().split('T')[0]);
        }
        if (_endDate != null) {
          query = query.lte('Report_date', _endDate!.toIso8601String().split('T')[0]);
        }

        final rows = await query;
        if (rows is List) {
          for (final r in List<Map<String, dynamic>>.from(rows)) {
            result.add({...r, '_source': sourceLabel});
          }
        }
      }
    }

    await fetchTable('Attendance_Tadabur', 'تدبر');
    await fetchTable('Attendance_Sard', 'سرد');

    return result;
  }

  void _computeMetrics(
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> attendance,
  ) {
    _totalStudents = students.length;

    _studentsByClass = {};
    _studentsByGroup = {};
    _studentsByStatus = {};
    _studentsByBranch = {};
    _topClassesByStudent = {};
    _lowAttendanceByClass = {};
    _lowAttendanceByGroup = {};
    _attendanceByClass = {};
    _attendanceByGroup = {};
    _registrationsByDate = {};
    _attendanceTrendByDate = {};
    _lowAttendanceList = [];
    _recentStudents = [];

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    var new7 = 0;
    var newMonth = 0;
    var incomplete = 0;

    final statusCounts = <String, int>{};
    final branchCounts = <String, int>{};
    final classCounts = <String, int>{};
    final groupCounts = <String, int>{};

    final studentById = <dynamic, Map<String, dynamic>>{};
    for (final s in students) {
      studentById[s['id']] = s;
      final classLabel = _resolveClassGroupLabel(s);
      final groupLabel = _resolveGroupLabel(s);
      classCounts[classLabel] = (classCounts[classLabel] ?? 0) + 1;
      groupCounts[groupLabel] = (groupCounts[groupLabel] ?? 0) + 1;

      final code = (s['Student_Code'] ?? '').toString().trim();
      final name = (s['Student_Name'] ?? '').toString().trim();
      final mobile = (s['Mobile_No'] ?? '').toString().trim();
      final hasMissingAssignment =
          s['Class_id'] == null || s['Group_id'] == null || s['Type_id'] == null;
      if (code.isEmpty || name.isEmpty || mobile.isEmpty || hasMissingAssignment) {
        incomplete++;
      }

      if (_statusColumn != null) {
        final status = (s[_statusColumn!] ?? '').toString().trim();
        if (status.isNotEmpty) {
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }
      }

      if (_branchColumn != null) {
        final branch = (s[_branchColumn!] ?? '').toString().trim();
        if (branch.isNotEmpty) {
          branchCounts[branch] = (branchCounts[branch] ?? 0) + 1;
        }
      }

      if (_createdAtColumn != null && s[_createdAtColumn!] != null) {
        final parsed = DateTime.tryParse(s[_createdAtColumn!].toString());
        if (parsed != null) {
          if (parsed.isAfter(sevenDaysAgo)) {
            new7++;
          }
          if (!parsed.isBefore(monthStart)) {
            newMonth++;
          }
          final key = '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
          _registrationsByDate[key] = (_registrationsByDate[key] ?? 0) + 1;
        }
      }
    }

    final perStudent = <dynamic, _StudentAttendanceStats>{};
    final perDateTotals = <String, List<int>>{}; // [present,total]
    final absentRecently = <dynamic>{};

    for (final rec in attendance) {
      final sid = rec['Student_id'];
      if (!studentById.containsKey(sid)) continue;

      final attended = rec['Attend_flag'] == true || rec['Attend_flag'] == 1;
      final absent = rec['Absent_flag'] == true || rec['Absent_flag'] == 1;
      final excuse = rec['Execuse_flag'] == true || rec['Execuse_flag'] == 1;
      final considered = attended || absent || excuse;
      if (!considered) continue;

      final old = perStudent[sid] ?? const _StudentAttendanceStats(total: 0, present: 0, absent: 0);
      perStudent[sid] = _StudentAttendanceStats(
        total: old.total + 1,
        present: old.present + (attended ? 1 : 0),
        absent: old.absent + (absent ? 1 : 0),
      );

      final dateRaw = rec['Report_date']?.toString();
      final parsed = dateRaw == null ? null : DateTime.tryParse(dateRaw);
      if (parsed != null) {
        final dateKey = '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
        final current = perDateTotals[dateKey] ?? [0, 0];
        if (attended) current[0] += 1;
        current[1] += 1;
        perDateTotals[dateKey] = current;

        if (absent && parsed.isAfter(sevenDaysAgo)) {
          absentRecently.add(sid);
        }
      }
    }

    var overallTotal = 0;
    var overallPresent = 0;

    for (final entry in perStudent.entries) {
      final sid = entry.key;
      final stats = entry.value;
      overallTotal += stats.total;
      overallPresent += stats.present;

      final student = studentById[sid] ?? {};
        final classLabel = _resolveClassGroupLabel(student);
        final groupLabel = _resolveGroupLabel(student);

      final classStat = _attendanceByClass[classLabel] ?? 0;
      final groupStat = _attendanceByGroup[groupLabel] ?? 0;
      // Build as sum of percentages first; normalized below by class student count with attendance.
      _attendanceByClass[classLabel] = classStat + stats.percent;
      _attendanceByGroup[groupLabel] = groupStat + stats.percent;

      if (stats.total >= 3 && stats.percent < 75) {
        _lowAttendanceList.add({
          'student': student,
          'percent': stats.percent,
          'total': stats.total,
          'absent': stats.absent,
          'classLabel': classLabel,
          'groupLabel': groupLabel,
        });
        _lowAttendanceByClass[classLabel] = (_lowAttendanceByClass[classLabel] ?? 0) + 1;
        _lowAttendanceByGroup[groupLabel] = (_lowAttendanceByGroup[groupLabel] ?? 0) + 1;
      }
    }

    final classAttendanceCounter = <String, int>{};
    final groupAttendanceCounter = <String, int>{};
    for (final e in perStudent.entries) {
      final student = studentById[e.key] ?? {};
      final classLabel = _resolveClassGroupLabel(student);
      final groupLabel = _resolveGroupLabel(student);
      classAttendanceCounter[classLabel] = (classAttendanceCounter[classLabel] ?? 0) + 1;
      groupAttendanceCounter[groupLabel] = (groupAttendanceCounter[groupLabel] ?? 0) + 1;
    }
    _attendanceByClass = _attendanceByClass.map((key, value) {
      final count = classAttendanceCounter[key] ?? 1;
      return MapEntry(key, value / count);
    });
    _attendanceByGroup = _attendanceByGroup.map((key, value) {
      final count = groupAttendanceCounter[key] ?? 1;
      return MapEntry(key, value / count);
    });

    _attendanceTrendByDate = {};
    for (final e in perDateTotals.entries) {
      final present = e.value[0].toDouble();
      final total = e.value[1].toDouble();
      _attendanceTrendByDate[e.key] = total == 0 ? 0 : (present / total) * 100;
    }

    _studentsByClass = classCounts;
    _studentsByGroup = groupCounts;
    _topClassesByStudent = Map.fromEntries(
      classCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..removeRange(classCounts.length > 5 ? 5 : classCounts.length, classCounts.length),
    );

    _studentsByStatus = statusCounts;
    _studentsByBranch = branchCounts;

    _attendanceAvgPercent = overallTotal == 0 ? 0 : (overallPresent / overallTotal) * 100;
    _lowAttendanceStudents = _lowAttendanceList.length;
    _recentAbsentStudents = absentRecently.length;
    _incompleteStudents = incomplete;

    if (_createdAtColumn != null) {
      _newLast7Days = new7;
      _newThisMonth = newMonth;
      _recentStudents = List<Map<String, dynamic>>.from(students)
        ..sort((a, b) {
          final da = DateTime.tryParse((a[_createdAtColumn!] ?? '').toString()) ?? DateTime(2000);
          final db = DateTime.tryParse((b[_createdAtColumn!] ?? '').toString()) ?? DateTime(2000);
          return db.compareTo(da);
        });
      if (_recentStudents.length > 8) {
        _recentStudents = _recentStudents.sublist(0, 8);
      }
    } else {
      _newLast7Days = null;
      _newThisMonth = null;
      _recentStudents = [];
    }

    _lowAttendanceList.sort((a, b) => (a['percent'] as double).compareTo(b['percent'] as double));
    if (_lowAttendanceList.length > 10) {
      _lowAttendanceList = _lowAttendanceList.sublist(0, 10);
    }
  }

  List<SearchableLovItem<dynamic>> _buildLookupItems(
    List<Map<String, dynamic>> rows,
    String valueKey,
    String labelKey,
  ) {
    return [
      const SearchableLovItem<dynamic>(value: null, label: 'الكل'),
      ...rows.map((r) {
        return SearchableLovItem<dynamic>(
          value: r[valueKey],
          label: (r[labelKey] ?? '').toString(),
        );
      }),
    ];
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
      _loadDashboard();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
      _loadDashboard();
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(String title, Map<String, int> data, {Color? color}) {
    if (data.isEmpty) {
      return _buildEmptyCard(title, 'لا توجد بيانات كافية');
    }

    final entries = data.entries.toList();
    if (entries.length > 8) {
      entries.sort((a, b) => b.value.compareTo(a.value));
      entries.removeRange(8, entries.length);
    }

    final maxY = entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY <= 0 ? 1 : maxY * 1.2,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        final text = entries[i].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 62,
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < entries.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: entries[i].value.toDouble(),
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                          color: color ?? const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(String title, Map<String, int> data) {
    if (data.isEmpty) {
      return _buildEmptyCard(title, 'لا توجد بيانات كافية');
    }

    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.length > 6) entries.removeRange(6, entries.length);

    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 32,
                sectionsSpace: 2,
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    PieChartSectionData(
                      value: entries[i].value.toDouble(),
                      color: colors[i % colors.length],
                      radius: 58,
                      title: entries[i].value.toString(),
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (var i = 0; i < entries.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${entries[i].key} (${entries[i].value})'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(String title, Map<String, double> data) {
    if (data.isEmpty) {
      return _buildEmptyCard(title, 'لا توجد بيانات كافية');
    }

    final entries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.length > 20) {
      entries.removeRange(0, entries.length - 20);
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 20,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: entries.length > 6 ? (entries.length / 6).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                        final text = entries[i].key.length >= 10 ? entries[i].key.substring(5) : entries[i].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(text, style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final statuses = _statusColumn == null
        ? <String>[]
        : (_studentsByStatus.keys.toList()..sort((a, b) => a.compareTo(b)));
    final branches = _branchColumn == null
        ? <String>[]
        : (_studentsByBranch.keys.toList()..sort((a, b) => a.compareTo(b)));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _filtersLoading
          ? const Center(child: CircularProgressIndicator())
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 170,
                  child: SearchableLovField<dynamic>(
                    value: _selectedClassId,
                    labelText: 'الحلقة',
                    items: _buildLookupItems(_classes, 'id', 'Class_Number'),
                    onChanged: (v) {
                      setState(() => _selectedClassId = v);
                      _loadDashboard();
                    },
                    decoration: const InputDecoration(
                      labelText: 'الحلقة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: SearchableLovField<dynamic>(
                    value: _selectedGroupId,
                    labelText: 'المجموعة',
                    items: _buildLookupItems(_groups, 'id', 'Group_Name'),
                    onChanged: (v) {
                      setState(() => _selectedGroupId = v);
                      _loadDashboard();
                    },
                    decoration: const InputDecoration(
                      labelText: 'المجموعة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: SearchableLovField<dynamic>(
                    value: _selectedTypeId,
                    labelText: 'الرواية',
                    items: _buildLookupItems(_types, 'id', 'Type'),
                    onChanged: (v) {
                      setState(() => _selectedTypeId = v);
                      _loadDashboard();
                    },
                    decoration: const InputDecoration(
                      labelText: 'الرواية',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (statuses.isNotEmpty)
                  SizedBox(
                    width: 170,
                    child: SearchableLovField<dynamic>(
                      value: _selectedStatus,
                      labelText: 'حالة الطالب',
                      items: [
                        const SearchableLovItem<dynamic>(value: null, label: 'الكل'),
                        ...statuses.map((s) => SearchableLovItem<dynamic>(value: s, label: s)),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedStatus = v?.toString());
                        _loadDashboard();
                      },
                      decoration: const InputDecoration(
                        labelText: 'حالة الطالب',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                if (branches.isNotEmpty)
                  SizedBox(
                    width: 170,
                    child: SearchableLovField<dynamic>(
                      value: _selectedBranch,
                      labelText: 'الفرع/الموقع',
                      items: [
                        const SearchableLovItem<dynamic>(value: null, label: 'الكل'),
                        ...branches.map((b) => SearchableLovItem<dynamic>(value: b, label: b)),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedBranch = v?.toString());
                        _loadDashboard();
                      },
                      decoration: const InputDecoration(
                        labelText: 'الفرع/الموقع',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 150,
                  child: InkWell(
                    onTap: _pickStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'من تاريخ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _startDate == null
                            ? 'اختر'
                            : _startDate!.toIso8601String().split('T')[0],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: InkWell(
                    onTap: _pickEndDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'الى تاريخ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _endDate == null
                            ? 'اختر'
                            : _endDate!.toIso8601String().split('T')[0],
                      ),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                ),
              ],
            ),
    );
  }

  Widget _buildLowAttendanceTable() {
    if (_lowAttendanceList.isEmpty) {
      return _buildEmptyCard('طلاب منخفضو الحضور', 'لا توجد حالات منخفضة الحضور بناء على المرشحات');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طلاب منخفضو الحضور',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الطالب')),
                  DataColumn(label: Text('الحلقة')),
                  DataColumn(label: Text('نسبة الحضور')),
                  DataColumn(label: Text('عدد السجلات')),
                ],
                rows: _lowAttendanceList.map((item) {
                  final student = item['student'] as Map<String, dynamic>;
                  return DataRow(
                    cells: [
                      DataCell(Text((student['Student_Name'] ?? '-').toString())),
                      DataCell(
                        Text(
                          '${(item['classLabel'] ?? '-').toString()} / ${(item['groupLabel'] ?? '-').toString()}',
                        ),
                      ),
                      DataCell(Text('${(item['percent'] as double).toStringAsFixed(1)}%')),
                      DataCell(Text((item['total'] ?? 0).toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStudents() {
    if (_recentStudents.isEmpty) {
      return _buildEmptyCard('اخر الطلاب المسجلين', 'لا توجد بيانات تسجيل حديثة');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اخر الطلاب المسجلين',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: _recentStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = _recentStudents[index];
                final created = _createdAtColumn == null
                    ? '-'
                    : (s[_createdAtColumn!] ?? '').toString().split('T').first;
                final classGroupLabel = _resolveClassGroupLabel(s);
                return ListTile(
                  dense: true,
                  title: Text((s['Student_Name'] ?? '-').toString()),
                  subtitle: Text('الكود: ${s['Student_Code'] ?? '-'} | الحلقة/المجموعة: $classGroupLabel'),
                  trailing: Text(created),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard التحليلات'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading && !_filtersLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                    if (_schemaLimitations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ملاحظات على بنية البيانات',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            for (final note in _schemaLimitations)
                              Text('- $note', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      int columns = 5;
                                      if (constraints.maxWidth < 1400) columns = 4;
                                      if (constraints.maxWidth < 1100) columns = 3;
                                      if (constraints.maxWidth < 800) columns = 2;
                                      if (constraints.maxWidth < 520) columns = 1;

                                      return GridView.count(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        crossAxisCount: columns,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: 1.7,
                                        children: [
                                          _buildKpiCard(
                                            title: 'اجمالي الطلاب',
                                            value: _totalStudents.toString(),
                                            icon: Icons.people,
                                            color: const Color(0xFF6366F1),
                                          ),
                                          _buildKpiCard(
                                            title: 'تسجيل اخر 7 ايام',
                                            value: _newLast7Days?.toString() ?? '-',
                                            icon: Icons.timeline,
                                            color: const Color(0xFF3B82F6),
                                          ),
                                          _buildKpiCard(
                                            title: 'تسجيل هذا الشهر',
                                            value: _newThisMonth?.toString() ?? '-',
                                            icon: Icons.calendar_month,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                          _buildKpiCard(
                                            title: 'متوسط الحضور',
                                            value: '${_attendanceAvgPercent.toStringAsFixed(1)}%',
                                            icon: Icons.fact_check,
                                            color: const Color(0xFF06B6D4),
                                          ),
                                          _buildKpiCard(
                                            title: 'حلقات/مجموعات/انواع',
                                            value: '$_totalClasses / $_totalGroups / $_totalTypes',
                                            icon: Icons.account_tree,
                                            color: const Color(0xFF8B5CF6),
                                          ),
                                          _buildKpiCard(
                                            title: 'منخفضو الحضور',
                                            value: _lowAttendanceStudents.toString(),
                                            icon: Icons.warning_amber,
                                            color: const Color(0xFFEF4444),
                                          ),
                                          _buildKpiCard(
                                            title: 'غياب حديث',
                                            value: _recentAbsentStudents.toString(),
                                            icon: Icons.event_busy,
                                            color: const Color(0xFFF97316),
                                          ),
                                          _buildKpiCard(
                                            title: 'ملفات غير مكتملة',
                                            value: _incompleteStudents.toString(),
                                            icon: Icons.assignment_late,
                                            color: const Color(0xFFDC2626),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final narrow = constraints.maxWidth < 980;
                                      if (narrow) {
                                        return Column(
                                          children: [
                                            SizedBox(height: 320, child: _buildBarChart('عدد الطلاب حسب الحلقة/المجموعة', _studentsByClass)),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 320, child: _buildPieChart('توزيع الطلاب حسب الحالة', _studentsByStatus)),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 320, child: _buildBarChart('افضل الحلقات/المجموعات بعدد الطلاب', _topClassesByStudent, color: const Color(0xFF10B981))),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 320, child: _buildLineChart('اتجاه نسبة الحضور اليومي', _attendanceTrendByDate)),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 320, child: _buildBarChart('الطلاب منخفضو الحضور حسب الحلقة/المجموعة', _lowAttendanceByClass, color: const Color(0xFFEF4444))),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 320, child: _buildLineChart('مقارنة الحضور بين الحلقة/المجموعة (%)', _attendanceByClass)),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 320, child: _buildBarChart('نمو التسجيل عبر الوقت', _registrationsByDate, color: const Color(0xFF3B82F6))),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 340, child: _buildLowAttendanceTable()),
                                            const SizedBox(height: 10),
                                            SizedBox(height: 340, child: _buildRecentStudents()),
                                          ],
                                        );
                                      }

                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: SizedBox(height: 320, child: _buildBarChart('عدد الطلاب حسب الحلقة/المجموعة', _studentsByClass))),
                                              const SizedBox(width: 10),
                                              Expanded(child: SizedBox(height: 320, child: _buildPieChart('توزيع الطلاب حسب الحالة', _studentsByStatus))),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(child: SizedBox(height: 320, child: _buildBarChart('افضل الحلقات/المجموعات بعدد الطلاب', _topClassesByStudent, color: const Color(0xFF10B981)))),
                                              const SizedBox(width: 10),
                                              Expanded(child: SizedBox(height: 320, child: _buildBarChart('الطلاب حسب المجموعة', _studentsByGroup, color: const Color(0xFF8B5CF6)))),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(child: SizedBox(height: 320, child: _buildLineChart('اتجاه نسبة الحضور اليومي', _attendanceTrendByDate))),
                                              const SizedBox(width: 10),
                                              Expanded(child: SizedBox(height: 320, child: _buildBarChart('الطلاب منخفضو الحضور حسب الحلقة/المجموعة', _lowAttendanceByClass, color: const Color(0xFFEF4444)))),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(child: SizedBox(height: 320, child: _buildLineChart('مقارنة الحضور بين الحلقة/المجموعة (%)', _attendanceByClass))),
                                              const SizedBox(width: 10),
                                              Expanded(child: SizedBox(height: 320, child: _buildLineChart('مقارنة الحضور بين المجموعات (%)', _attendanceByGroup))),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(child: SizedBox(height: 320, child: _buildBarChart('نمو التسجيل عبر الوقت', _registrationsByDate, color: const Color(0xFF3B82F6)))),
                                              const SizedBox(width: 10),
                                              Expanded(child: SizedBox(height: 320, child: _buildBarChart('الطلاب منخفضو الحضور حسب المجموعة', _lowAttendanceByGroup, color: const Color(0xFFF97316)))),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(child: SizedBox(height: 340, child: _buildLowAttendanceTable())),
                                              const SizedBox(width: 10),
                                              Expanded(child: SizedBox(height: 340, child: _buildRecentStudents())),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
