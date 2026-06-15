import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import '../models/user_session.dart';
import '../widgets/responsive_table_container.dart';
import '../widgets/searchable_lov_field.dart';

class StudentsScreen extends StatefulWidget {
  // allow injecting a SupabaseClient for tests
  final dynamic client;
  final UserSession? userSession;
  const StudentsScreen({super.key, this.client, this.userSession});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
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

    int _compareClassOptionIds(dynamic a, dynamic b) {
      final labelA = (_classesMap[a] ?? a?.toString() ?? '').toString();
      final labelB = (_classesMap[b] ?? b?.toString() ?? '').toString();
      final numA = _extractClassNumberForSort(labelA);
      final numB = _extractClassNumberForSort(labelB);
      final hasNumA = numA != (1 << 30);
      final hasNumB = numB != (1 << 30);
      if (hasNumA && hasNumB && numA != numB) return numA.compareTo(numB);
      if (hasNumA && !hasNumB) return -1;
      if (!hasNumA && hasNumB) return 1;
      return labelA.compareTo(labelB);
    }
  late final dynamic _client = widget.client ?? Supabase.instance.client;
  bool _loading = true;
  bool _exporting = false;
  List<Map<String, dynamic>> _rows = [];
  bool _lookupsLoading = true;
  dynamic _filterType;
  dynamic _filterClassNumber;
  dynamic _filterClass;
  List<dynamic> _typeOptions = [];
  List<dynamic> _classOptions = [];
  List<dynamic> _groupOptions = [];
  final Map<dynamic, String> _groupsMap = {};
  final Map<dynamic, String> _classesMap = {};
  final Map<dynamic, String> _typesMap = {};
  // search debounce for name (optional)
  Timer? _debounce;
  String? _searchName;

  // pagination
  final int _limit = 20;
  int _pageIndex = 0;
  final Map<int, List<Map<String, dynamic>>> _pageCache = {};
  final Map<int, bool> _pageHasNext = {};
  int _totalRows = 0;

  // User's restrictions (fetched from Managers table)
  int? _userClassId;
  int? _userGroupId;
  int? _userTypeId;

  @override
  void initState() {
    super.initState();
    // load lookups then students
    Future(() async {
      await _fetchUserRestrictions();
      await _loadFilterOptions();
      await _fetchStudents();
    });
  }

  Future<void> _fetchUserRestrictions() async {
    // Skip if admin or no userId or no userSession
    if (widget.userSession == null || widget.userSession!.hasFullAccess) {
      return;
    }

    setState(() {
      _userClassId = widget.userSession!.assignedClassId;
      _userGroupId = widget.userSession!.assignedGroupId;
      _userTypeId = widget.userSession!.assignedTypeId;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    _lookupsLoading = true;
    setState(() {});
    try {
      // fetch distinct-ish lists for each filter column separately and deduplicate
      // Try to load lookup tables; if not present, fall back to infer from Students
      await _loadLookupTable('Groups', 'Group_Name', _groupsMap);
      await _loadLookupTable('Classes', 'Class_Number', _classesMap);
      await _loadLookupTable('Types', 'Type', _typesMap);

      if (_groupsMap.isNotEmpty ||
          _classesMap.isNotEmpty ||
          _typesMap.isNotEmpty) {
        // populate options from lookup maps
        _groupOptions = _groupsMap.keys.whereType<int>().toList();
        _classOptions = _classesMap.keys.whereType<int>().toList();
        _typeOptions = _typesMap.keys.whereType<int>().toList();
        _groupOptions.sort();
        _classOptions.sort(_compareClassOptionIds);
        _typeOptions.sort();
      } else {
        // fallback: fetch from Students table like before (legacy schema)
        final futures = await Future.wait<dynamic>([
          _client.from('Students').select('"Type_id"') as Future<dynamic>,
          _client.from('Students').select('"Class_id"') as Future<dynamic>,
          _client.from('Students').select('"Group_id"') as Future<dynamic>,
        ]);

        List<Map<String, dynamic>> typeList = [];
        List<Map<String, dynamic>> classNumList = [];
        List<Map<String, dynamic>> classList = [];

        if (futures.isNotEmpty) {
          if (futures[0] is List) {
            typeList = List<Map<String, dynamic>>.from(futures[0]);
          }
          if (futures.length > 1 && futures[1] is List) {
            classNumList = List<Map<String, dynamic>>.from(futures[1]);
          }
          if (futures.length > 2 && futures[2] is List) {
            classList = List<Map<String, dynamic>>.from(futures[2]);
          }
        }

        final types = typeList
            .map((r) => r['Type_id'] as int?)
            .where((v) => v != null)
            .cast<int>()
            .toSet()
            .toList();
        final classNums = classNumList
            .map((r) => r['Class_id'] as int?)
            .where((v) => v != null)
            .cast<int>()
            .toSet()
            .toList();
        final groups = classList
            .map((r) => r['Group_id'] as int?)
            .where((v) => v != null)
            .cast<int>()
            .toSet()
            .toList();

        types.sort();
        classNums.sort(_compareClassOptionIds);
        groups.sort();

        setState(() {
          _typeOptions = types;
          _classOptions = classNums;
          _groupOptions = groups;
        });
      }
    } catch (_) {
      // ignore - options are optional
    } finally {
      _lookupsLoading = false;
      if (mounted) setState(() {});
    }
  }

  // Try to fetch a lookup table with given tableName, expecting an id and a name/title column
  Future<void> _loadLookupTable(
    String tableName,
    String nameColumn,
    Map<dynamic, String> dest,
  ) async {
    try {
      final res = await _client.from(tableName).select('id, "$nameColumn"');
      if (res is List) {
        for (final r in List<Map<String, dynamic>>.from(res)) {
          final id = r['id'];
          final name = r[nameColumn] ?? r['title'] ?? r['name'];
          if (id != null && name != null) dest[id] = name.toString();
        }
      }
    } catch (_) {
      // table may not exist or be inaccessible; ignore
    }
  }

  Future<void> _fetchStudents() async {
    setState(() => _loading = true);
    try {
      // Build filter query
      var query = _client.from('Students').select();
      // Filters use FK columns when available
      if (_filterType != null) {
        query = query.eq('"Type_id"', _filterType);
      }
      if (_filterClassNumber != null) {
        query = query.eq('"Class_id"', _filterClassNumber);
      }
      if (_filterClass != null) {
        query = query.eq('"Group_id"', _filterClass);
      }
      if (_searchName != null && _searchName!.isNotEmpty) {
        // try common Student name columns
        query = query.ilike('"Student_Name"', '%${_searchName!}%');
      }

      // First, get an exact total count using FetchOptions (if supported by client)
      // Build a countQuery with the same filters to attempt a fallback count
      var countQuery = _client.from('Students').select();
      if (_filterType != null) {
        countQuery = countQuery.eq('"Type_id"', _filterType);
      }
      if (_filterClassNumber != null) {
        countQuery = countQuery.eq('"Class_id"', _filterClassNumber);
      }
      if (_filterClass != null) {
        countQuery = countQuery.eq('"Group_id"', _filterClass);
      }
      if (_searchName != null && _searchName!.isNotEmpty) {
        countQuery = countQuery.ilike('"Student_Name"', '%${_searchName!}%');
      }

      // Try to get total rows by fetching a large range (fallback when count option isn't available)
      try {
        final countRes = await countQuery.range(0, 1000000);
        if (countRes is List) {
          _totalRows = countRes.length;
        }
      } catch (_) {
        // ignore - keep _totalRows = 0
      }

      // Cursor-based: if we already have the page cached, use it
      if (_pageCache.containsKey(_pageIndex)) {
        _rows = _pageCache[_pageIndex]!;
        setState(() => _loading = false);
        return;
      }

      // Determine query for current pageIndex
      List<Map<String, dynamic>> fetched = [];
      if (_pageIndex == 0) {
        // first page: fetch _limit+1 entries (range 0.._limit)
        final res = await query.order('id', ascending: true).range(0, _limit);
        if (res is List) fetched = List<Map<String, dynamic>>.from(res);
      } else {
        // need cursor from previous page
        final prevPage = _pageCache[_pageIndex - 1];
        if (prevPage == null || prevPage.isEmpty) {
          // nothing to fetch
          fetched = [];
        } else {
          final lastId = prevPage.last['id'];
          final res = await query
              .gt('id', lastId)
              .order('id', ascending: true)
              .range(0, _limit);
          if (res is List) fetched = List<Map<String, dynamic>>.from(res);
        }
      }
      if (fetched.length > _limit) {
        // fetched includes one extra to signal more
        _pageHasNext[_pageIndex] = true;
        _rows = fetched.sublist(0, _limit);
      } else {
        _pageHasNext[_pageIndex] = false;
        _rows = fetched;
      }

      // cache the page
      _pageCache[_pageIndex] = _rows;
      debugPrint(
        'StudentsScreen: fetched ${_rows.length} rows for page $_pageIndex',
      );
      if (_rows.isNotEmpty) {
        debugPrint(
          'First row keys: ${_rows.first.keys} values: ${_rows.first}',
        );
      }
      // If lookup maps are empty (permissions or earlier load failure), try loading them now
      try {
        if (_groupsMap.isEmpty) {
          await _loadLookupTable('Groups', 'Group_Name', _groupsMap);
        }
        if (_classesMap.isEmpty) {
          await _loadLookupTable('Classes', 'Class_Number', _classesMap);
        }
        if (_typesMap.isEmpty) {
          await _loadLookupTable('Types', 'Type', _typesMap);
        }
        if (mounted) setState(() {});
      } catch (_) {
        // ignore lookup reload failures
      }
    } catch (e) {
      _rows = [];
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentsForExport() async {
    final allRows = <Map<String, dynamic>>[];
    dynamic lastId;
    const pageSize = 1000;

    while (true) {
      var query = _client.from('Students').select();

      if (_filterType != null) {
        query = query.eq('"Type_id"', _filterType);
      }
      if (_filterClassNumber != null) {
        query = query.eq('"Class_id"', _filterClassNumber);
      }
      if (_filterClass != null) {
        query = query.eq('"Group_id"', _filterClass);
      }
      if (_searchName != null && _searchName!.isNotEmpty) {
        query = query.ilike('"Student_Name"', '%${_searchName!}%');
      }
      if (lastId != null) {
        query = query.gt('id', lastId);
      }

      final response = await query
          .order('id', ascending: true)
          .range(0, pageSize - 1);
      final batch = response is List
          ? List<Map<String, dynamic>>.from(response)
          : <Map<String, dynamic>>[];

      if (batch.isEmpty) {
        break;
      }

      allRows.addAll(batch);

      if (batch.length < pageSize) {
        break;
      }
      lastId = batch.last['id'];
    }

    return allRows;
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _excelSafeNumericLike(String value) {
    if (value.isEmpty) return '';
    return '="$value"';
  }

  bool _isValidStudentCode(String code) {
    return RegExp(r'^[A-Za-z]+\d+$').hasMatch(code);
  }

  String? _buildNextStudentCode(List<dynamic> existingCodes) {
    final pattern = RegExp(r'^([A-Za-z]+)(\d+)$');

    String? bestPrefix;
    int bestSequence = -1;
    int bestWidth = 0;

    for (final raw in existingCodes) {
      final code = (raw ?? '').toString().trim();
      if (code.isEmpty) continue;

      final match = pattern.firstMatch(code);
      if (match == null) continue;

      final prefix = match.group(1)!;
      final digits = match.group(2)!;
      final sequence = int.tryParse(digits);
      if (sequence == null) continue;

      if (sequence > bestSequence) {
        bestSequence = sequence;
        bestPrefix = prefix;
        bestWidth = digits.length;
      }
    }

    if (bestPrefix == null) {
      return null;
    }

    final nextSequence = bestSequence + 1;
    final nextDigits = nextSequence.toString().padLeft(bestWidth, '0');
    return '$bestPrefix$nextDigits';
  }

  Future<void> _exportFilteredStudentsCsv() async {
    if (_exporting) {
      return;
    }

    setState(() => _exporting = true);
    try {
      final exportRows = await _fetchStudentsForExport();
      if (exportRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد بيانات للتصدير بناءً على الفلاتر الحالية'),
            ),
          );
        }
        return;
      }

      final headers = <String>[
        'ID',
        'Student Name',
        'Student Code',
        'Mobile',
        'Group',
        'Class',
        'Type',
      ];

      final buffer = StringBuffer();
      buffer.write('\uFEFF');
      buffer.writeln(headers.map(_csvCell).join(','));

      for (final row in exportRows) {
        final studentCode = (row['Student_Code'] ?? '').toString();
        final mobile = (row['Mobile_No'] ?? '').toString();
        final groupId = row['Group_id'];
        final classId = row['Class_id'];
        final typeId = row['Type_id'];

        final values = <String>[
          (row['id'] ?? '').toString(),
          (row['Student_Name'] ?? '').toString(),
          _excelSafeNumericLike(studentCode),
          _excelSafeNumericLike(mobile),
          _groupsMap[groupId] ?? (groupId?.toString() ?? ''),
          _classesMap[classId] ?? (classId?.toString() ?? ''),
          _typesMap[typeId] ?? (typeId?.toString() ?? ''),
        ];

        buffer.writeln(values.map(_csvCell).join(','));
      }

      final now = DateTime.now();
      final fileName =
          'students_filtered_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

      if (kIsWeb) {
        final bytes = utf8.encode(buffer.toString());
        final blob = html.Blob(<dynamic>[bytes], 'text/csv;charset=utf-8;');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'تم تصدير ${exportRows.length} سجل بنجاح'
                  : 'تم إعداد الملف بنجاح',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تصدير البيانات: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _onSearchNameChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchName = v;
        _pageIndex = 0; // reset to first page
        _pageCache.clear();
        _pageHasNext.clear();
      });
      _fetchStudents();
    });
  }

  void _nextPage() {
    final canNext = _pageHasNext[_pageIndex] ?? false;
    if (canNext) {
      setState(() => _pageIndex += 1);
      _fetchStudents();
    }
  }

  void _prevPage() {
    if (_pageIndex > 0) {
      setState(() => _pageIndex -= 1);
      _fetchStudents();
    }
  }

  Future<void> _deleteRow(dynamic id) async {
    try {
      debugPrint('DEBUG: Starting delete for student ID: $id');
      debugPrint('DEBUG: User session: ${_client.auth.currentUser?.id}');

      final response = await _client
          .from('Students')
          .delete()
          .eq('id', id)
          .select();
      debugPrint('DEBUG: Delete response: $response');

      if (mounted) {
        debugPrint('DEBUG: Widget mounted, clearing cache and refreshing');
        // Clear cache to force fresh data fetch from server
        setState(() {
          _pageCache.clear();
          _pageHasNext.clear();
          _pageIndex = 0;
        });
        await _fetchStudents();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الطالب بنجاح')));
      } else {
        debugPrint('DEBUG: Widget not mounted after delete');
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Delete error: $e');
      debugPrint('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  Future<void> _updateRow(dynamic id, Map<String, dynamic> changes) async {
    try {
      debugPrint(
        'DEBUG: Starting update for student ID: $id with changes: $changes',
      );
      debugPrint('DEBUG: User session: ${_client.auth.currentUser?.id}');

      final response = await _client
          .from('Students')
          .update(changes)
          .eq('id', id)
          .select();
      debugPrint('DEBUG: Update response: $response');

      if (mounted) {
        debugPrint('DEBUG: Widget mounted, clearing cache and refreshing');
        // Clear cache to force fresh data fetch from server
        setState(() {
          _pageCache.clear();
          _pageHasNext.clear();
          _pageIndex = 0;
        });
        await _fetchStudents();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث الطالب بنجاح')));
      } else {
        debugPrint('DEBUG: Widget not mounted after update');
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Update error: $e');
      debugPrint('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في التحديث: $e')));
      }
    }
  }

  String _formatDateOnly(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _showAttendanceOverrideDialog(Map<String, dynamic> row) async {
    if (!(widget.userSession?.hasFullAccess ?? false)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ليس لديك صلاحية لإدارة تحويلات الحضور'),
          ),
        );
      }
      return;
    }

    final studentId = row['id'];
    if (studentId == null) return;

    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMode = 'sard';
    dynamic selectedClassId;
    dynamic selectedGroupId;
    dynamic selectedTypeId;
    DateTime? effectiveFrom;
    DateTime? effectiveTo;
    bool isActive = true;
    int? selectedOverrideId;
    bool loadingOverrides = true;
    bool saving = false;
    List<Map<String, dynamic>> overrides = [];

    Future<void> loadOverrides(StateSetter setDialogState) async {
      setDialogState(() => loadingOverrides = true);
      try {
        final res = await _client
            .from('Student_Attendance_Overrides')
            .select(
              'id, Attendance_Mode, Attend_Class_id, Attend_Group_id, Attend_Type_id, effective_from, effective_to, is_active, reason, notes, created_at',
            )
            .eq('Student_id', studentId)
            .order('created_at', ascending: false);

        overrides = (res is List)
            ? List<Map<String, dynamic>>.from(res)
            : <Map<String, dynamic>>[];
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تحميل تحويلات الحضور: $e')),
          );
        }
      } finally {
        setDialogState(() => loadingOverrides = false);
      }
    }

    void applyOverride(Map<String, dynamic>? o, StateSetter setDialogState) {
      setDialogState(() {
        if (o == null) {
          selectedOverrideId = null;
          selectedMode = 'sard';
          selectedClassId = null;
          selectedGroupId = null;
          selectedTypeId = null;
          effectiveFrom = null;
          effectiveTo = null;
          isActive = true;
          reasonController.clear();
          notesController.clear();
          return;
        }

        selectedOverrideId = (o['id'] as num?)?.toInt();
        selectedMode = (o['Attendance_Mode'] ?? 'sard').toString();
        selectedClassId = o['Attend_Class_id'];
        selectedGroupId = o['Attend_Group_id'];
        selectedTypeId = o['Attend_Type_id'];
        effectiveFrom = _parseDateOnly(o['effective_from']);
        effectiveTo = _parseDateOnly(o['effective_to']);
        isActive = o['is_active'] == true;
        reasonController.text = (o['reason'] ?? '').toString();
        notesController.text = (o['notes'] ?? '').toString();
      });
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            if (loadingOverrides && overrides.isEmpty) {
              Future.microtask(() => loadOverrides(setDialogState));
            }

            final overrideItems = <SearchableLovItem<int?>>[
              const SearchableLovItem<int?>(value: null, label: 'إضافة جديد'),
              ...overrides.map((o) {
                final id = (o['id'] as num?)?.toInt();
                final mode = (o['Attendance_Mode'] ?? '').toString();
                final active = o['is_active'] == true ? 'نشط' : 'غير نشط';
                final from = o['effective_from']?.toString() ?? '-';
                final to = o['effective_to']?.toString() ?? '-';
                return SearchableLovItem<int?>(
                  value: id,
                  label: '$mode | $active | $from -> $to',
                );
              }),
            ];

            Future<void> pickDate({required bool isFrom}) async {
              final current = isFrom ? effectiveFrom : effectiveTo;
              final picked = await showDatePicker(
                context: dialogInnerContext,
                initialDate: current ?? DateTime.now(),
                firstDate: DateTime(2000, 1, 1),
                lastDate: DateTime(2100, 12, 31),
              );
              if (picked == null) return;
              setDialogState(() {
                if (isFrom) {
                  effectiveFrom = picked;
                } else {
                  effectiveTo = picked;
                }
              });
            }

            Future<void> saveOverride() async {
              if (selectedClassId == null ||
                  selectedGroupId == null ||
                  selectedTypeId == null) {
                ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'يرجى تحديد الحلقة والمجموعة والرواية للتحويل',
                    ),
                  ),
                );
                return;
              }
              if (effectiveFrom != null &&
                  effectiveTo != null &&
                  effectiveTo!.isBefore(effectiveFrom!)) {
                ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                  const SnackBar(
                    content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية'),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                final payload = <String, dynamic>{
                  'Student_id': studentId,
                  'Attendance_Mode': selectedMode,
                  'Attend_Class_id': selectedClassId,
                  'Attend_Group_id': selectedGroupId,
                  'Attend_Type_id': selectedTypeId,
                  'effective_from': effectiveFrom == null
                      ? null
                      : _formatDateOnly(effectiveFrom!),
                  'effective_to': effectiveTo == null
                      ? null
                      : _formatDateOnly(effectiveTo!),
                  'is_active': isActive,
                  'reason': reasonController.text.trim().isEmpty
                      ? null
                      : reasonController.text.trim(),
                  'notes': notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                };

                if (selectedOverrideId == null) {
                  payload['Created_By_User_id'] = widget.userSession?.userId;
                  await _client
                      .from('Student_Attendance_Overrides')
                      .insert(payload)
                      .select()
                      .single();
                } else {
                  await _client
                      .from('Student_Attendance_Overrides')
                      .update(payload)
                      .eq('id', selectedOverrideId!)
                      .select()
                      .single();
                }

                await loadOverrides(setDialogState);
                final selected = overrides.where(
                  (o) => (o['id'] as num?)?.toInt() == selectedOverrideId,
                );
                if (selectedOverrideId != null && selected.isNotEmpty) {
                  applyOverride(selected.first, setDialogState);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        selectedOverrideId == null
                            ? 'تم إنشاء تحويل الحضور'
                            : 'تم تحديث تحويل الحضور',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر حفظ التحويل: $e')),
                  );
                }
              } finally {
                setDialogState(() => saving = false);
              }
            }

            Future<void> deactivateOverride() async {
              if (selectedOverrideId == null) return;
              setDialogState(() => saving = true);
              try {
                await _client
                    .from('Student_Attendance_Overrides')
                    .update({'is_active': false})
                    .eq('id', selectedOverrideId!)
                    .select()
                    .single();
                await loadOverrides(setDialogState);
                final selected = overrides.where(
                  (o) => (o['id'] as num?)?.toInt() == selectedOverrideId,
                );
                if (selected.isNotEmpty) {
                  applyOverride(selected.first, setDialogState);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تعطيل التحويل')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تعذر تعطيل التحويل: $e')),
                  );
                }
              } finally {
                setDialogState(() => saving = false);
              }
            }

            final studentName =
                (row['Student_Name'] ?? row['student_name'] ?? '').toString();

            return AlertDialog(
              title: Text('تحويل حضور الطالب: $studentName'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchableLovField<int?>(
                        value: selectedOverrideId,
                        labelText: 'التحويل الحالي',
                        items: overrideItems,
                        onChanged: (value) {
                          final selected = overrides.firstWhere(
                            (o) => (o['id'] as num?)?.toInt() == value,
                            orElse: () => <String, dynamic>{},
                          );
                          if (selected.isEmpty) {
                            applyOverride(null, setDialogState);
                          } else {
                            applyOverride(selected, setDialogState);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      SearchableLovField<String>(
                        value: selectedMode,
                        labelText: 'نوع الحضور',
                        items: const [
                          SearchableLovItem(value: 'sard', label: 'سرد'),
                          SearchableLovItem(value: 'tadabur', label: 'تدبر'),
                          SearchableLovItem(value: 'both', label: 'كلاهما'),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedMode = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      SearchableLovField<dynamic>(
                        value: selectedClassId,
                        labelText: 'الحلقة المستهدفة',
                        items: _classOptions
                            .map(
                              (c) => SearchableLovItem<dynamic>(
                                value: c,
                                label: _classesMap[c] ?? c.toString(),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedClassId = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      SearchableLovField<dynamic>(
                        value: selectedGroupId,
                        labelText: 'المجموعة المستهدفة',
                        items: _groupOptions
                            .map(
                              (g) => SearchableLovItem<dynamic>(
                                value: g,
                                label: _groupsMap[g] ?? g.toString(),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedGroupId = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      SearchableLovField<dynamic>(
                        value: selectedTypeId,
                        labelText: 'الرواية المستهدفة',
                        items: _typeOptions
                            .map(
                              (t) => SearchableLovItem<dynamic>(
                                value: t,
                                label: _typesMap[t] ?? t.toString(),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedTypeId = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => pickDate(isFrom: true),
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                effectiveFrom == null
                                    ? 'من تاريخ (اختياري)'
                                    : 'من: ${_formatDateOnly(effectiveFrom!)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => pickDate(isFrom: false),
                              icon: const Icon(Icons.event),
                              label: Text(
                                effectiveTo == null
                                    ? 'إلى تاريخ (اختياري)'
                                    : 'إلى: ${_formatDateOnly(effectiveTo!)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setDialogState(() => isActive = value),
                        title: const Text('التحويل نشط'),
                      ),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'السبب',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                        ),
                      ),
                      if (loadingOverrides)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق'),
                ),
                if (selectedOverrideId != null)
                  TextButton(
                    onPressed: saving ? null : deactivateOverride,
                    child: const Text('تعطيل'),
                  ),
                ElevatedButton(
                  onPressed: saving ? null : saveOverride,
                  child: Text(selectedOverrideId == null ? 'إنشاء' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRowDetails(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تفاصيل الطالب'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: row.entries
                .map((e) => Text('${_prettifyColumn(e.key)}: ${e.value ?? ''}'))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> row) {
    debugPrint('DEBUG: _showEditDialog called for ID: ${row['id']}');

    try {
      debugPrint('DEBUG: Creating controllers...');
      final nameController = TextEditingController(
        text: (row['Student_Name'] ?? '').toString(),
      );
      final mobileController = TextEditingController(
        text: (row['Mobile_No'] ?? '').toString(),
      );
      final codeController = TextEditingController(
        text: (row['Student_Code'] ?? '').toString(),
      );

      dynamic selectedGroupId = row['Group_id'];
      dynamic selectedTypeId = row['Type_id'];

      // Get current class number for display
      String currentClassNumber = (row['Class_Number'] ?? '').toString();

      debugPrint('DEBUG: Controllers created successfully');

      debugPrint('DEBUG: Calling showDialog...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          debugPrint('DEBUG: Inside dialog builder');
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Filter classes based on selected group and type

              return AlertDialog(
                title: const Text('تعديل بيانات الطالب'),
                content: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الطالب',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: mobileController,
                          decoration: const InputDecoration(
                            labelText: 'رقم الجوال',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'كود الطالب',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Group dropdown
                        if (_groupOptions.isNotEmpty)
                          SearchableLovField<dynamic>(
                            value: _groupOptions.contains(selectedGroupId)
                                ? selectedGroupId
                                : (_groupOptions.isNotEmpty
                                      ? _groupOptions.first
                                      : null),
                            labelText: 'المجموعة',
                            decoration: const InputDecoration(
                              labelText: 'المجموعة',
                              border: OutlineInputBorder(),
                            ),
                            items: _groupOptions.map((g) {
                              final display =
                                  _groupsMap[g] ?? g?.toString() ?? '';
                              return SearchableLovItem<dynamic>(
                                value: g,
                                label: display,
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedGroupId = value;
                              });
                            },
                          ),
                        const SizedBox(height: 12),

                        // Class Number text field (user enters the number they want)
                        TextField(
                          controller: TextEditingController(
                            text: currentClassNumber,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'رقم الحلقة',
                            border: OutlineInputBorder(),
                            hintText: 'أدخل رقم الحلقة',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            currentClassNumber = value;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Type dropdown
                        if (_typeOptions.isNotEmpty)
                          SearchableLovField<dynamic>(
                            value: _typeOptions.contains(selectedTypeId)
                                ? selectedTypeId
                                : (_typeOptions.isNotEmpty
                                      ? _typeOptions.first
                                      : null),
                            labelText: 'الرواية',
                            decoration: const InputDecoration(
                              labelText: 'الرواية',
                              border: OutlineInputBorder(),
                            ),
                            items: _typeOptions.map((t) {
                              final display =
                                  _typesMap[t] ?? t?.toString() ?? '';
                              return SearchableLovItem<dynamic>(
                                value: t,
                                label: display,
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedTypeId = value;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      debugPrint('DEBUG: Cancel clicked');
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      debugPrint('DEBUG: Save clicked');

                      final studentCode = codeController.text.trim();
                      if (studentCode.isEmpty ||
                          !_isValidStudentCode(studentCode)) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'يرجى إدخال كود صالح بصيغة حرف/حروف ثم أرقام (مثل A001)',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      final changes = <String, dynamic>{
                        'Student_Name': nameController.text.trim(),
                        'Mobile_No': mobileController.text.trim(),
                        'Student_Code': studentCode,
                      };

                      if (selectedGroupId != null) {
                        changes['Group_id'] = selectedGroupId;
                      }
                      if (selectedTypeId != null) {
                        changes['Type_id'] = selectedTypeId;
                      }

                      // Find the Class_id based on Class_Number, Group_id, and Type_id
                      if (currentClassNumber.isNotEmpty) {
                        try {
                          final classNumberInt = int.tryParse(
                            currentClassNumber,
                          );
                          if (classNumberInt != null &&
                              selectedGroupId != null &&
                              selectedTypeId != null) {
                            debugPrint(
                              'DEBUG: Looking up Class_id for Class_Number=$classNumberInt, Group_id=$selectedGroupId, Type_id=$selectedTypeId',
                            );

                            final classResult = await _client
                                .from('Classes')
                                .select('id')
                                .eq('Class_Number', classNumberInt)
                                .maybeSingle();

                            if (classResult != null) {
                              final foundClassId = classResult['id'];
                              debugPrint(
                                'DEBUG: Found Class_id: $foundClassId',
                              );
                              changes['Class_id'] = foundClassId;
                            } else {
                              debugPrint('DEBUG: No matching class found');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'لم يتم العثور على حلقة برقم $classNumberInt',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('DEBUG: Error looking up Class_id: $e');
                        }
                      }

                      Navigator.of(dialogContext).pop();
                      debugPrint('DEBUG: Calling _updateRow...');
                      _updateRow(row['id'], changes);
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        debugPrint('DEBUG: Dialog closed');
      });
      debugPrint('DEBUG: showDialog call completed');
    } catch (e, stack) {
      debugPrint('DEBUG: Error in _showEditDialog: $e');
      debugPrint('DEBUG: Stack: $stack');
    }
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final codeController = TextEditingController();
    // Pre-select if user has restrictions
    final hasGroupRestriction =
        widget.userSession?.isAdmin == false && _userGroupId != null;
    final hasClassRestriction =
        widget.userSession?.isAdmin == false && _userClassId != null;
    final hasTypeRestriction =
        widget.userSession?.isAdmin == false && _userTypeId != null;

    dynamic selectedGroup = hasGroupRestriction ? _userGroupId : null;
    dynamic selectedClass = hasClassRestriction ? _userClassId : null;
    dynamic selectedType = hasTypeRestriction ? _userTypeId : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة طالب جديد'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الطالب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: mobileController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الجوال',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText:
                            'كود الطالب (صيغة: حرف/حروف ثم أرقام مثل A001)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SearchableLovField<dynamic>(
                      value: selectedGroup,
                      labelText: 'المجموعة',
                      enabled: !hasGroupRestriction,
                      decoration: InputDecoration(
                        labelText: 'المجموعة',
                        border: const OutlineInputBorder(),
                        suffixIcon: hasGroupRestriction
                            ? const Icon(Icons.lock, size: 18)
                            : null,
                      ),
                      items: _groupOptions.map((g) {
                        final display = _groupsMap[g] ?? g?.toString() ?? '';
                        return SearchableLovItem<dynamic>(
                          value: g,
                          label: display,
                        );
                      }).toList(),
                      onChanged: hasGroupRestriction
                          ? null
                          : (value) {
                              setDialogState(() => selectedGroup = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    SearchableLovField<dynamic>(
                      value: selectedClass,
                      labelText: 'رقم الحلقة',
                      enabled: !hasClassRestriction,
                      decoration: InputDecoration(
                        labelText: 'رقم الحلقة',
                        border: const OutlineInputBorder(),
                        // Show lock icon if restricted
                        suffixIcon: hasClassRestriction
                            ? const Icon(Icons.lock, size: 18)
                            : null,
                      ),
                      items: _classOptions.map((c) {
                        final display = _classesMap[c] ?? c?.toString() ?? '';
                        return SearchableLovItem<dynamic>(
                          value: c,
                          label: display,
                        );
                      }).toList(),
                      // Disable if user has class restriction
                      onChanged: hasClassRestriction
                          ? null
                          : (value) {
                              setDialogState(() => selectedClass = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    SearchableLovField<dynamic>(
                      value: selectedType,
                      labelText: 'الرواية',
                      enabled: !hasTypeRestriction,
                      decoration: InputDecoration(
                        labelText: 'الرواية',
                        border: const OutlineInputBorder(),
                        suffixIcon: hasTypeRestriction
                            ? const Icon(Icons.lock, size: 18)
                            : null,
                      ),
                      items: _typeOptions.map((t) {
                        final display = _typesMap[t] ?? t?.toString() ?? '';
                        return SearchableLovItem<dynamic>(
                          value: t,
                          label: display,
                        );
                      }).toList(),
                      onChanged: hasTypeRestriction
                          ? null
                          : (value) {
                              setDialogState(() => selectedType = value);
                            },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final mobile = mobileController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم الطالب')),
                    );
                    return;
                  }

                  try {
                    final studentData = <String, dynamic>{
                      'Student_Name': name,
                      'Mobile_No': mobile.isNotEmpty ? mobile : null,
                    };

                    // Resolve group / class / type respecting restrictions
                    final targetGroupId = hasGroupRestriction
                        ? _userGroupId
                        : selectedGroup;
                    final targetClassId = hasClassRestriction
                        ? _userClassId
                        : selectedClass;
                    final targetTypeId = hasTypeRestriction
                        ? _userTypeId
                        : selectedType;

                    if (targetGroupId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى اختيار المجموعة')),
                      );
                      return;
                    }

                    studentData['Group_id'] = targetGroupId;
                    if (targetClassId != null) {
                      studentData['Class_id'] = targetClassId;
                    }
                    if (targetTypeId != null) {
                      studentData['Type_id'] = targetTypeId;
                    }

                    // Auto-generate Student_Code from existing values like A001 -> A002.
                    // If no valid existing format is found, require user input.
                    final existingCodesRes = await _client
                        .from('Students')
                        .select('Student_Code')
                        .eq('Group_id', targetGroupId);

                    final existingCodes = existingCodesRes is List
                        ? existingCodesRes
                              .map((r) => (r as Map<String, dynamic>)['Student_Code'])
                              .toList()
                        : <dynamic>[];

                    final nextCode = _buildNextStudentCode(existingCodes);
                    if (nextCode != null) {
                      studentData['Student_Code'] = nextCode;
                    } else {
                      final manualCode = codeController.text.trim();
                      if (manualCode.isEmpty || !_isValidStudentCode(manualCode)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'لا يوجد كود صالح للتوليد التلقائي، يرجى إدخال كود بصيغة حرف/حروف ثم أرقام (مثل A001)',
                            ),
                          ),
                        );
                        return;
                      }
                      studentData['Student_Code'] = manualCode;
                    }

                    await _client.from('Students').insert(studentData);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم إضافة الطالب بنجاح')),
                      );
                      _fetchStudents();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ في إضافة الطالب: $e')),
                      );
                    }
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 950;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStudents,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton(
          onPressed: _showAddStudentDialog,
          backgroundColor: const Color(0xFF6366F1),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 950;
                final fields = [
                  SizedBox(
                    width: compact ? double.infinity : 170,
                    child: SearchableLovField<dynamic>(
                      value: _filterType,
                      labelText: 'الرواية',
                      enabled: !_lookupsLoading,
                      items: [
                        const SearchableLovItem<dynamic>(
                          value: null,
                          label: 'All',
                        ),
                        ..._typeOptions.map((t) {
                          final display = _typesMap[t] ?? (t?.toString() ?? '');
                          return SearchableLovItem<dynamic>(
                            value: t,
                            label: display,
                          );
                        }),
                      ],
                      onChanged: _lookupsLoading
                          ? null
                          : (v) => setState(() => _filterType = v),
                      decoration: InputDecoration(
                        labelText: 'الرواية',
                        suffixIcon: _lookupsLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 170,
                    child: SearchableLovField<dynamic>(
                      value: _filterClassNumber,
                      labelText: 'الحلقة',
                      enabled: !_lookupsLoading,
                      items: [
                        const SearchableLovItem<dynamic>(
                          value: null,
                          label: 'All',
                        ),
                        ..._classOptions.map((t) {
                          final display =
                              _classesMap[t] ?? (t?.toString() ?? '');
                          return SearchableLovItem<dynamic>(
                            value: t,
                            label: display,
                          );
                        }),
                      ],
                      onChanged: _lookupsLoading
                          ? null
                          : (v) => setState(() => _filterClassNumber = v),
                      decoration: InputDecoration(
                        labelText: 'الحلقة',
                        suffixIcon: _lookupsLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 170,
                    child: SearchableLovField<dynamic>(
                      value: _filterClass,
                      labelText: 'المجموعة',
                      enabled: !_lookupsLoading,
                      items: [
                        const SearchableLovItem<dynamic>(
                          value: null,
                          label: 'All',
                        ),
                        ..._groupOptions.map((t) {
                          final display =
                              _groupsMap[t] ?? (t?.toString() ?? '');
                          return SearchableLovItem<dynamic>(
                            value: t,
                            label: display,
                          );
                        }),
                      ],
                      onChanged: _lookupsLoading
                          ? null
                          : (v) => setState(() => _filterClass = v),
                      decoration: InputDecoration(
                        labelText: 'المجموعة',
                        suffixIcon: _lookupsLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search name',
                      ),
                      onChanged: _onSearchNameChanged,
                    ),
                  ),
                ];

                final actions = [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _pageIndex = 0;
                        _pageCache.clear();
                        _pageHasNext.clear();
                      });
                      _fetchStudents();
                    },
                    child: const Text('بحث'),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_loading || _exporting)
                        ? null
                        : _exportFilteredStudentsCsv,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: const Text('تصدير CSV'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterType = null;
                        _filterClassNumber = null;
                        _filterClass = null;
                        _searchName = null;
                        _pageIndex = 0;
                        _pageCache.clear();
                        _pageHasNext.clear();
                      });
                      _fetchStudents();
                    },
                    child: const Text('مسح'),
                  ),
                ];

                if (compact) {
                  return Column(
                    children: [
                      ...fields.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: w,
                        ),
                      ),
                      Row(
                        children: actions
                            .map(
                              (w) => Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                child: w,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...fields.map(
                        (w) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: w,
                        ),
                      ),
                      ...actions.map(
                        (w) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: w,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                ? const Center(child: Text('لا توجد سجلات'))
                : ResponsiveTableContainer(
                    thumbVisibility: isNarrow,
                    child: StudentsTable(
                      rows: _rows,
                      onView: _showRowDetails,
                      onEdit: _showEditDialog,
                      onDelete: _deleteRow,
                      onManageOverride: _showAttendanceOverrideDialog,
                      groupsMap: _groupsMap.isNotEmpty ? _groupsMap : null,
                      typesMap: _typesMap.isNotEmpty ? _typesMap : null,
                      classesMap: _classesMap.isNotEmpty ? _classesMap : null,
                    ),
                  ),
          ),
          // pagination controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 700;
                final start = _pageIndex * _limit;
                final end = start + _rows.length;
                final canPrev = _pageIndex > 0;
                final canNext = _pageHasNext[_pageIndex] ?? false;

                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: canPrev ? _prevPage : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: canNext ? _nextPage : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _totalRows > 0
                            ? 'Showing ${start + 1} - $end of $_totalRows'
                            : 'Showing ${start + 1} - $end',
                      ),
                      controls,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _totalRows > 0
                          ? 'Showing ${start + 1} - $end of $_totalRows'
                          : 'Showing ${start + 1} - $end',
                    ),
                    controls,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _prettifyColumn(String key) {
    var s = key.replaceAll('_', ' ');
    s = s.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    final parts = s.split(RegExp(r"\s+"))..removeWhere((p) => p.trim().isEmpty);
    final capitalized = parts
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() +
              (w.length > 1 ? w.substring(1).toLowerCase() : '');
        })
        .join(' ');
    return capitalized;
  }
}

class StudentsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic>)? onView;
  final void Function(Map<String, dynamic>)? onEdit;
  final Future<void> Function(dynamic id)? onDelete;
  final void Function(Map<String, dynamic>)? onManageOverride;
  final Map<dynamic, String>? groupsMap;
  final Map<dynamic, String>? typesMap;
  final Map<dynamic, String>? classesMap;

  const StudentsTable({
    super.key,
    required this.rows,
    this.onView,
    this.onEdit,
    this.onDelete,
    this.onManageOverride,
    this.groupsMap,
    this.typesMap,
    this.classesMap,
  });

  // Compute filtered keys for both columns and rows so they stay aligned.
  List<dynamic> _computeFilteredKeys(List<dynamic> keys) {
    final Map<String, String> labels = {
      'id': 'الرقم',
      'ID': 'الرقم',
      'Class_id': 'الحلقة',
      'class_id': 'الحلقة',
      'Group_Name': 'المجموعة',
      'group_name': 'المجموعة',
      'group': 'المجموعة',
      'Group_id': 'المجموعة',
      'group_id': 'المجموعة',
      'Type': 'النوع',
      'type': 'النوع',
      'Type_id': 'الرواية',
      'type_id': 'الرواية',
      'Student_Name': 'اسم الطالب',
      'student_name': 'اسم الطالب',
      'StudentName': 'اسم الطالب',
      'Mobile_no': 'الجوال',
      'mobile_no': 'الجوال',
      'MobileNo': 'الجوال',
      'Mobile No': 'الجوال',
      'Mobile No.': 'الجوال',
    };

    // Filter out a run of unwanted columns that appear sequentially after the Mobile column
    final mobileLabels = {'الجوال', 'Mobile No', 'Mobile No.'};
    final unwantedAfterMobile = {'رقم الصف', 'المجموعة', 'النوع'};

    int mobileIndex = -1;
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final label = labels[k] ?? _prettifyColumn(k.toString());
      if (mobileLabels.contains(label) ||
          label.toString().toLowerCase().contains('mobile')) {
        mobileIndex = i;
        break;
      }
    }

    final filteredKeys = <dynamic>[];
    if (mobileIndex == -1) {
      filteredKeys.addAll(keys);
    } else {
      for (var i = 0; i <= mobileIndex && i < keys.length; i++) {
        filteredKeys.add(keys[i]);
      }
      var j = mobileIndex + 1;
      while (j < keys.length) {
        final k = keys[j];
        final label = labels[k] ?? _prettifyColumn(k.toString());
        if (unwantedAfterMobile.contains(label)) {
          j++;
          continue;
        }
        break;
      }
      for (var i = j; i < keys.length; i++) {
        filteredKeys.add(keys[i]);
      }
    }

    // additionally remove any keys whose final label matches the global unwanted list
    final unwantedLabels = {
      'رقم الصف',
      'المجموعة',
      'النوع',
      'class number',
      'class no',
      'class_number',
      'class',
    };
    final unwantedLower = unwantedLabels.map((s) => s.toLowerCase()).toSet();
    filteredKeys.removeWhere((k) {
      final label = (labels[k] ?? _prettifyColumn(k.toString()))
          .toString()
          .toLowerCase();
      return unwantedLower.contains(label);
    });

    return filteredKeys;
  }

  List<DataColumn> _buildColumns() {
    if (rows.isEmpty) return [];
    // determine raw keys and separate FK id keys
    final rawKeys = rows.first.keys.where((k) => k != 'created_at').toList();
    final fkKeys = rawKeys
        .where((k) => k.toString().toLowerCase().endsWith('_id'))
        .toList();
    final keys = rawKeys.where((k) => !fkKeys.contains(k)).toList();

    final Map<String, String> labels = {
      // Arabic column headings (custom adjustments)
      'id': 'الرقم',
      'ID': 'الرقم',

      // class / episode labels
      // explicit id-based label the user requested
      'Class_id': 'الحلقة',
      'class_id': 'الحلقة',

      // group / collection labels
      'Group_Name': 'المجموعة',
      'group_name': 'المجموعة',
      'group': 'المجموعة',
      'Group_id': 'المجموعة',
      'group_id': 'المجموعة',

      // type labels
      'Type': 'النوع',
      'type': 'النوع',
      'Type_id': 'الرواية',
      'type_id': 'الرواية',

      // student and contact
      'Student_Name': 'اسم الطالب',
      'student_name': 'اسم الطالب',
      'StudentName': 'اسم الطالب',
      'Mobile_no': 'الجوال',
      'mobile_no': 'الجوال',
      'MobileNo': 'الجوال',
      // handle header keys that include space/period
      'Mobile No': 'الجوال',
      'Mobile No.': 'الجوال',
    };
    // compute filtered keys using the same logic as rows to keep columns/rows aligned
    final filteredKeys = _computeFilteredKeys(keys);

    final cols = filteredKeys
        .map(
          (k) => DataColumn(
            label: Text(
              labels[k] ?? _prettifyColumn(k.toString()),
              textAlign: TextAlign.right,
            ),
          ),
        )
        .toList();
    // for each fk key, add a friendly column (e.g., Group_id -> Group)
    // but skip creating a derived column if the row already includes a direct name column
    for (final fk in fkKeys) {
      final name = fk.toString().replaceAll(
        RegExp(r'_id\$', caseSensitive: false),
        '',
      );
      // if any existing key already contains the base name (e.g. 'Group_Name' or 'group'), skip
      final base = name.toString().toLowerCase();
      final hasDirect = rawKeys.any((k) {
        final kl = k.toString().toLowerCase();
        return kl.contains(base) && !kl.endsWith('_id');
      });
      if (hasDirect) continue;
      cols.add(DataColumn(label: Text(labels[name] ?? _prettifyColumn(name))));
    }
    // actions
    cols.add(const DataColumn(label: Text('Actions')));
    return cols;
  }

  List<DataRow> _buildRows() {
    // split out fk keys from normal keys
    final rawKeys = rows.first.keys.where((k) => k != 'created_at').toList();
    final fkKeys = rawKeys
        .where((k) => k.toString().toLowerCase().endsWith('_id'))
        .toList();
    final keys = rawKeys.where((k) => !fkKeys.contains(k)).toList();

    // compute filtered keys with same logic as _buildColumns
    final filteredKeys = _computeFilteredKeys(keys);

    return rows.map((row) {
      final cells = <DataCell>[];
      // normal cells first (use filteredKeys to match columns)
      for (final k in filteredKeys) {
        final v = row[k];
        cells.add(
          DataCell(
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                v == null ? '' : v.toString(),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        );
      }

      // FK-derived friendly cells (prefer direct name fields returned by server)
      for (final fk in fkKeys) {
        final v = row[fk];
        final lower = fk.toString().toLowerCase();

        // Prefer direct name fields returned by the server (if you selected them), e.g. 'Group_Name', 'Class_Number', 'Type'
        String? directName;
        if (lower.contains('group')) {
          directName =
              row['Group_Name']?.toString() ??
              row['group_name']?.toString() ??
              row['GroupName']?.toString();
        } else if (lower.contains('class')) {
          directName =
              row['Class_Number']?.toString() ??
              row['class_number']?.toString() ??
              row['ClassNumber']?.toString();
        } else if (lower.contains('type')) {
          directName =
              row['Type']?.toString() ??
              row['type']?.toString() ??
              row['TypeName']?.toString();
        }

        if (directName != null && directName.isNotEmpty) {
          cells.add(
            DataCell(
              Align(
                alignment: Alignment.centerRight,
                child: Text(directName, textAlign: TextAlign.right),
              ),
            ),
          );
          continue;
        }

        // Fallback to lookup maps
        if ((lower.contains('group') || lower.contains('group_id')) &&
            groupsMap != null &&
            v != null) {
          cells.add(
            DataCell(
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  groupsMap![v] ?? v.toString(),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          );
          continue;
        }
        if ((lower.contains('type') || lower.contains('type_id')) &&
            typesMap != null &&
            v != null) {
          cells.add(
            DataCell(
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  typesMap![v] ?? v.toString(),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          );
          continue;
        }
        if ((lower.contains('class') || lower.contains('class_id')) &&
            classesMap != null &&
            v != null) {
          cells.add(
            DataCell(
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  classesMap![v] ?? v.toString(),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          );
          continue;
        }

        cells.add(
          DataCell(
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                v == null ? '' : v.toString(),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        );
      }

      // actions cell
      cells.add(
        DataCell(
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view') {
                if (onView != null) onView!(row);
              } else if (v == 'edit') {
                if (onEdit != null) {
                  // Use Future.microtask to avoid blocking the popup menu
                  Future.microtask(() => onEdit!(row));
                }
              } else if (v == 'delete') {
                // Use Future.microtask to avoid blocking the popup menu
                Future.microtask(() async {
                  final confirm = await showDialog<bool>(
                    context: _dummyContext,
                    builder: (c) => AlertDialog(
                      title: const Text('حذف'),
                      content: const Text('هل تريد حذف هذا السجل؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: const Text('لا'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('نعم'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && onDelete != null) {
                    await onDelete!(row['id']);
                  }
                });
              } else if (v == 'override') {
                if (onManageOverride != null) {
                  Future.microtask(() => onManageOverride!(row));
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'view', child: Text('عرض')),
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              const PopupMenuItem(
                value: 'override',
                child: Text('تحويل الحضور'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ),
      );

      return DataRow(cells: cells);
    }).toList();
  }

  // Helper to prettify column keys
  static String _prettifyColumn(String key) {
    var s = key.replaceAll('_', ' ');
    s = s.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    final parts = s.split(RegExp(r"\s+"))..removeWhere((p) => p.trim().isEmpty);
    final capitalized = parts
        .map((w) {
          if (w.isEmpty) return w;
          return w[0].toUpperCase() +
              (w.length > 1 ? w.substring(1).toLowerCase() : '');
        })
        .join(' ');
    return capitalized;
  }

  // Workaround: to show confirm dialog from within itemBuilder we need a BuildContext. We'll use a dummy
  // context setter at the top of the widget tree when used in the app. For tests, actions won't be used.
  static late BuildContext _dummyContext;

  @override
  Widget build(BuildContext context) {
    _dummyContext = context;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DataTable(
        dataTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
        columns: _buildColumns(),
        rows: _buildRows(),
        columnSpacing: 24,
      ),
    );
  }
}
