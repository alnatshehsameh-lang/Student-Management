import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class AttendanceReportScreen extends StatefulWidget {
  final UserSession userSession;
  const AttendanceReportScreen({super.key, required this.userSession});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
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
        const SnackBar(content: Text('يرجى اختيار المجموعة والرواية والحلقة')),
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
      // Get students in this class, group, and type
      final studentsRes = await _client
          .from('Students')
          .select('id, "Student_Name", "Student_Code"')
          .eq('Class_id', _selectedClassId)
          .eq('Group_id', _selectedGroupId)
          .eq('Type_id', _selectedTypeId)
          .range(0, 10000);

      final students = (studentsRes is List)
          ? List<Map<String, dynamic>>.from(studentsRes)
          : <Map<String, dynamic>>[];

      if (students.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد طلاب في هذه الحلقة مع المجموعة والرواية المحددة')),
          );
        }
        debugPrint('No students found for Class: $_selectedClassId, Group: $_selectedGroupId, Type: $_selectedTypeId');
        return;
      }

      debugPrint('Found ${students.length} students for report generation');
      final startDateStr = _startDate!.toIso8601String().split('T')[0];
      final endDateStr = _endDate!.toIso8601String().split('T')[0];
      debugPrint('Date range: $startDateStr to $endDateStr');

      // Create a map of student IDs to their info for quick lookup
      final studentMap = <dynamic, Map<String, dynamic>>{};
      for (final student in students) {
        studentMap[student['id']] = student;
      }

      final combined = <Map<String, dynamic>>[];

      // Fetch attendance records for Tadabur
      final tadaburRes = await _client
          .from('Attendance_Tadabur')
          .select('*')
          .gte('Report_date', startDateStr)
          .lte('Report_date', endDateStr)
          .range(0, 10000);

      debugPrint('Tadabur records count: ${tadaburRes is List ? (tadaburRes as List).length : 0}');

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

      // Fetch attendance records for Sard
      final sardRes = await _client
          .from('Attendance_Sard')
          .select('*')
          .gte('Report_date', startDateStr)
          .lte('Report_date', endDateStr)
          .range(0, 10000);

      debugPrint('Sard records count: ${sardRes is List ? (sardRes as List).length : 0}');

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

      debugPrint('Combined records after filtering: ${combined.length}');

      // Sort by report date
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
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في توليد التقرير: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الحضور'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معاملات البحث',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _filtersLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                // Group dropdown
                                DropdownButtonFormField<dynamic>(
                                  initialValue: _selectedGroupId,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGroupId = value;
                                      _reportData = [];
                                    });
                                  },
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('اختر المجموعة'),
                                    ),
                                    ..._groups.map((group) {
                                      return DropdownMenuItem(
                                        value: group['id'],
                                        child: Text(group['Group_Name'] ?? ''),
                                      );
                                    }),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'المجموعة',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Type dropdown
                                DropdownButtonFormField<dynamic>(
                                  initialValue: _selectedTypeId,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTypeId = value;
                                      _reportData = [];
                                    });
                                  },
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('اختر الرواية'),
                                    ),
                                    ..._types.map((type) {
                                      return DropdownMenuItem(
                                        value: type['id'],
                                        child: Text(type['Type'] ?? ''),
                                      );
                                    }),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'الرواية',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Class dropdown
                                DropdownButtonFormField<dynamic>(
                                  initialValue: _selectedClassId,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedClassId = value;
                                      _reportData = [];
                                    });
                                  },
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('اختر الحلقة'),
                                    ),
                                    ..._classes.map((cls) {
                                      return DropdownMenuItem(
                                        value: cls['id'],
                                        child: Text(cls['Class_Number']?.toString() ?? ''),
                                      );
                                    }),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'الحلقة',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Start Date
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      locale: const Locale('ar'),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _startDate = picked;
                                        _reportData = [];
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _startDate == null
                                              ? 'اختر تاريخ البداية'
                                              : 'من: ${_startDate!.toIso8601String().split('T')[0]}',
                                          style: TextStyle(
                                            color: _startDate == null ? Colors.grey : Colors.black,
                                          ),
                                        ),
                                        const Icon(Icons.calendar_today),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // End Date
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                      locale: const Locale('ar'),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _endDate = picked;
                                        _reportData = [];
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[400]!),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _endDate == null
                                              ? 'اختر تاريخ النهاية'
                                              : 'إلى: ${_endDate!.toIso8601String().split('T')[0]}',
                                          style: TextStyle(
                                            color: _endDate == null ? Colors.grey : Colors.black,
                                          ),
                                        ),
                                        const Icon(Icons.calendar_today),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _generateReport,
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('عرض التقرير'),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Report Results
                if (_reportData.isNotEmpty) ...[
                  Text(
                    'نتائج التقرير',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildReportTable(),
                ] else if (!_loading && _reportData.isEmpty && (_selectedGroupId != null && _selectedTypeId != null && _selectedClassId != null && _startDate != null && _endDate != null))
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد بيانات حضور للفترة المحددة',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    // Group data by report date
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    
    for (final record in _reportData) {
      final date = record['Report_date']?.toString().split('T')[0] ?? 'غير محدد';
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(record);
    }

    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedDates.map((date) {
        final records = groupedByDate[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'التاريخ: $date',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('اسم الطالب')),
                  DataColumn(label: Text('رقم الطالب')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('حاضر')),
                  DataColumn(label: Text('غائب')),
                  DataColumn(label: Text('معتذر')),
                ],
                rows: records.map((record) {
                  final studentName = record['Students']?['Student_Name'] ?? 'غير معروف';
                  final studentCode = record['Students']?['Student_Code'] ?? '';
                  final type = record['_type'] ?? '';
                  final attend = record['Attend_flag'] == true || record['Attend_flag'] == 1;
                  final absent = record['Absent_flag'] == true || record['Absent_flag'] == 1;
                  final excuse = record['Execuse_flag'] == true || record['Execuse_flag'] == 1;

                  return DataRow(
                    cells: [
                      DataCell(Text(studentName.toString())),
                      DataCell(Text(studentCode.toString())),
                      DataCell(Text(type)),
                      DataCell(
                        Center(
                          child: Icon(
                            attend ? Icons.check_circle : Icons.close,
                            color: attend ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      DataCell(
                        Center(
                          child: Icon(
                            absent ? Icons.check_circle : Icons.close,
                            color: absent ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                      DataCell(
                        Center(
                          child: Icon(
                            excuse ? Icons.check_circle : Icons.close,
                            color: excuse ? Colors.orange : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }
}
