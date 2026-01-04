import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class StudentsScreen extends StatefulWidget {
  // allow injecting a SupabaseClient for tests
  final dynamic client;
  final UserSession? userSession;
  const StudentsScreen({super.key, this.client, this.userSession});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late final dynamic _client = widget.client ?? Supabase.instance.client;
  bool _loading = true;
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
    if (widget.userSession == null || 
        widget.userSession!.isAdmin || 
        widget.userSession!.userId == null) {
      return;
    }

    try {
      final response = await _client
          .from('Managers')
          .select('Class_id, Group_id, Type_id')
          .eq('User_id', widget.userSession!.userId!)
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
      debugPrint('Failed to fetch user restrictions from Managers: $e');
    }
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

      if (_groupsMap.isNotEmpty || _classesMap.isNotEmpty || _typesMap.isNotEmpty) {
        // populate options from lookup maps
        _groupOptions = _groupsMap.keys.whereType<int>().toList();
        _classOptions = _classesMap.keys.whereType<int>().toList();
        _typeOptions = _typesMap.keys.whereType<int>().toList();
        _groupOptions.sort();
        _classOptions.sort();
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
          if (futures[0] is List) typeList = List<Map<String, dynamic>>.from(futures[0]);
          if (futures.length > 1 && futures[1] is List) classNumList = List<Map<String, dynamic>>.from(futures[1]);
          if (futures.length > 2 && futures[2] is List) classList = List<Map<String, dynamic>>.from(futures[2]);
        }

        final types = typeList.map((r) => r['Type_id'] as int?).where((v) => v != null).cast<int>().toSet().toList();
        final classNums = classNumList.map((r) => r['Class_id'] as int?).where((v) => v != null).cast<int>().toSet().toList();
        final groups = classList.map((r) => r['Group_id'] as int?).where((v) => v != null).cast<int>().toSet().toList();

        types.sort();
        classNums.sort();
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
  Future<void> _loadLookupTable(String tableName, String nameColumn, Map<dynamic, String> dest) async {
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
          final res = await query.gt('id', lastId).order('id', ascending: true).range(0, _limit);
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
      debugPrint('StudentsScreen: fetched ${_rows.length} rows for page $_pageIndex');
      if (_rows.isNotEmpty) debugPrint('First row keys: ${_rows.first.keys} values: ${_rows.first}');
      // If lookup maps are empty (permissions or earlier load failure), try loading them now
      try {
        if (_groupsMap.isEmpty) await _loadLookupTable('Groups', 'Group_Name', _groupsMap);
        if (_classesMap.isEmpty) await _loadLookupTable('Classes', 'Class_Number', _classesMap);
        if (_typesMap.isEmpty) await _loadLookupTable('Types', 'Type', _typesMap);
        if (mounted) setState(() {});
      } catch (_) {
        // ignore lookup reload failures
      }
    } catch (e) {
      _rows = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _loading = false);
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
      await _client.from('Students').delete().eq('id', id);
      _fetchStudents();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
    }
  }

  Future<void> _updateRow(dynamic id, Map<String, dynamic> changes) async {
    try {
      await _client.from('Students').update(changes).eq('id', id);
      _fetchStudents();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update error: $e')));
    }
  }

  void _showRowDetails(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تفاصيل الطالب'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: row.entries.map((e) => Text('${_prettifyColumn(e.key)}: ${e.value ?? ''}')).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> row) {
    final Map<String, TextEditingController> controllers = {};
    row.forEach((k, v) => controllers[k] = TextEditingController(text: v?.toString() ?? ''));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل'),
        content: SingleChildScrollView(
          child: Column(
            children: row.keys.map((k) {
              return TextField(controller: controllers[k], decoration: InputDecoration(labelText: _prettifyColumn(k)));
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final changes = <String, dynamic>{};
              controllers.forEach((k, c) {
                changes[k] = c.text;
              });
              Navigator.pop(context);
              _updateRow(row['id'], changes);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    // Pre-select if user has restrictions
    final hasGroupRestriction = widget.userSession?.isAdmin == false && _userGroupId != null;
    final hasClassRestriction = widget.userSession?.isAdmin == false && _userClassId != null;
    final hasTypeRestriction = widget.userSession?.isAdmin == false && _userTypeId != null;
    
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
                    DropdownButtonFormField<dynamic>(
                      initialValue: selectedGroup,
                      decoration: InputDecoration(
                        labelText: 'المجموعة',
                        border: const OutlineInputBorder(),
                        suffixIcon: hasGroupRestriction
                            ? const Icon(Icons.lock, size: 18)
                            : null,
                      ),
                      items: _groupOptions.map((g) {
                        final display = _groupsMap[g] ?? g?.toString() ?? '';
                        return DropdownMenuItem(value: g, child: Text(display));
                      }).toList(),
                      onChanged: hasGroupRestriction
                          ? null
                          : (value) {
                              setDialogState(() => selectedGroup = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<dynamic>(
                      initialValue: selectedClass,
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
                        return DropdownMenuItem(value: c, child: Text(display));
                      }).toList(),
                      // Disable if user has class restriction
                      onChanged: hasClassRestriction
                          ? null
                          : (value) {
                              setDialogState(() => selectedClass = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<dynamic>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'الرواية',
                        border: const OutlineInputBorder(),
                        suffixIcon: hasTypeRestriction
                            ? const Icon(Icons.lock, size: 18)
                            : null,
                      ),
                      items: _typeOptions.map((t) {
                        final display = _typesMap[t] ?? t?.toString() ?? '';
                        return DropdownMenuItem(value: t, child: Text(display));
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

                    // Enforce restrictions: use user's IDs if restricted
                    if (hasGroupRestriction) {
                      studentData['Group_id'] = _userGroupId;
                    } else if (selectedGroup != null) {
                      studentData['Group_id'] = selectedGroup;
                    }
                    
                    if (hasClassRestriction) {
                      studentData['Class_id'] = _userClassId;
                    } else if (selectedClass != null) {
                      studentData['Class_id'] = selectedClass;
                    }
                    
                    if (hasTypeRestriction) {
                      studentData['Type_id'] = _userTypeId;
                    } else if (selectedType != null) {
                      studentData['Type_id'] = selectedType;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStudents)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Type filter
                Expanded(
                  child: DropdownButtonFormField<dynamic>(
                    initialValue: _filterType,
                    items: [DropdownMenuItem<dynamic>(value: null, child: Text('All'))]
                        .followedBy(_typeOptions.map((t) {
                      final display = _typesMap[t] ?? (t?.toString() ?? '');
                      return DropdownMenuItem(value: t, child: Text(display));
                    })).toList(),
                    onChanged: _lookupsLoading ? null : (v) => setState(() => _filterType = v),
                    decoration: InputDecoration(
                      labelText: 'الرواية',
                      suffixIcon: _lookupsLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Class number filter
                Expanded(
                  child: DropdownButtonFormField<dynamic>(
                    initialValue: _filterClassNumber,
                    items: [DropdownMenuItem<dynamic>(value: null, child: Text('All'))]
                        .followedBy(_classOptions.map((t) {
                      final display = _classesMap[t] ?? (t?.toString() ?? '');
                      return DropdownMenuItem(value: t, child: Text(display));
                    })).toList(),
                    onChanged: _lookupsLoading ? null : (v) => setState(() => _filterClassNumber = v),
                    decoration: InputDecoration(
                      labelText: 'الحلقة',
                      suffixIcon: _lookupsLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Group filter
                Expanded(
                  child: DropdownButtonFormField<dynamic>(
                    initialValue: _filterClass,
                    items: [DropdownMenuItem<dynamic>(value: null, child: Text('All'))]
                        .followedBy(_groupOptions.map((t) {
                      final display = _groupsMap[t] ?? (t?.toString() ?? '');
                      return DropdownMenuItem(value: t, child: Text(display));
                    })).toList(),
                    onChanged: _lookupsLoading ? null : (v) => setState(() => _filterClass = v),
                    decoration: InputDecoration(
                      labelText: 'المجموعة',
                      suffixIcon: _lookupsLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // name search
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Search name'),
                    onChanged: _onSearchNameChanged,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  setState(() {
                    _pageIndex = 0;
                    _pageCache.clear();
                    _pageHasNext.clear();
                  });
                  _fetchStudents();
                }, child: const Text('بحث')),
                const SizedBox(width: 8),
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
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? const Center(child: Text('لا توجد سجلات'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: StudentsTable(
                            rows: _rows,
                            onView: _showRowDetails,
                            onEdit: _showEditDialog,
                            onDelete: _deleteRow,
                            groupsMap: _groupsMap.isNotEmpty ? _groupsMap : null,
                            typesMap: _typesMap.isNotEmpty ? _typesMap : null,
                            classesMap: _classesMap.isNotEmpty ? _classesMap : null,
                          ),
                        ),
                      ),
          ),
          // pagination controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(builder: (_) {
                  final start = _pageIndex * _limit;
                  final end = start + _rows.length;
                  final canPrev = _pageIndex > 0;
                  final canNext = _pageHasNext[_pageIndex] ?? false;
                  return Row(
                    children: [
                      Text(_totalRows > 0 ? 'Showing ${start + 1} - $end of $_totalRows' : 'Showing ${start + 1} - $end'),
                      const SizedBox(width: 12),
                      IconButton(onPressed: canPrev ? _prevPage : null, icon: const Icon(Icons.chevron_left)),
                      IconButton(onPressed: canNext ? _nextPage : null, icon: const Icon(Icons.chevron_right)),
                    ],
                  );
                })
              ],
            ),
          )
        ],
      ),
    );
  }

  String _prettifyColumn(String key) {
    var s = key.replaceAll('_', ' ');
    s = s.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    final parts = s.split(RegExp(r"\s+"))..removeWhere((p) => p.trim().isEmpty);
    final capitalized = parts.map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');
    return capitalized;
  }
}

class StudentsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic>)? onView;
  final void Function(Map<String, dynamic>)? onEdit;
  final Future<void> Function(dynamic id)? onDelete;
  final Map<dynamic, String>? groupsMap;
  final Map<dynamic, String>? typesMap;
  final Map<dynamic, String>? classesMap;

  const StudentsTable({
    super.key,
    required this.rows,
    this.onView,
    this.onEdit,
    this.onDelete,
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
      if (mobileLabels.contains(label) || label.toString().toLowerCase().contains('mobile')) {
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
    final unwantedLabels = {'رقم الصف', 'المجموعة', 'النوع', 'class number', 'class no', 'class_number', 'class'};
    final unwantedLower = unwantedLabels.map((s) => s.toLowerCase()).toSet();
    filteredKeys.removeWhere((k) {
      final label = (labels[k] ?? _prettifyColumn(k.toString())).toString().toLowerCase();
      return unwantedLower.contains(label);
    });

    return filteredKeys;
  }

  List<DataColumn> _buildColumns() {
    if (rows.isEmpty) return [];
    // determine raw keys and separate FK id keys
    final rawKeys = rows.first.keys.where((k) => k != 'created_at').toList();
    final fkKeys = rawKeys.where((k) => k.toString().toLowerCase().endsWith('_id')).toList();
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

  final cols = filteredKeys.map((k) => DataColumn(label: Text(labels[k] ?? _prettifyColumn(k.toString()), textAlign: TextAlign.right))).toList();
    // for each fk key, add a friendly column (e.g., Group_id -> Group)
    // but skip creating a derived column if the row already includes a direct name column
    for (final fk in fkKeys) {
      final name = fk.toString().replaceAll(RegExp(r'_id\$', caseSensitive: false), '');
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
    final fkKeys = rawKeys.where((k) => k.toString().toLowerCase().endsWith('_id')).toList();
    final keys = rawKeys.where((k) => !fkKeys.contains(k)).toList();

    // compute filtered keys with same logic as _buildColumns
    final filteredKeys = _computeFilteredKeys(keys);

    return rows.map((row) {
      final cells = <DataCell>[];
      // normal cells first (use filteredKeys to match columns)
      for (final k in filteredKeys) {
        final v = row[k];
        cells.add(DataCell(Align(alignment: Alignment.centerRight, child: Text(v == null ? '' : v.toString(), textAlign: TextAlign.right))));
      }

      // FK-derived friendly cells (prefer direct name fields returned by server)
      for (final fk in fkKeys) {
        final v = row[fk];
        final lower = fk.toString().toLowerCase();

        // Prefer direct name fields returned by the server (if you selected them), e.g. 'Group_Name', 'Class_Number', 'Type'
        String? directName;
        if (lower.contains('group')) {
          directName = row['Group_Name']?.toString() ?? row['group_name']?.toString() ?? row['GroupName']?.toString();
        } else if (lower.contains('class')) {
          directName = row['Class_Number']?.toString() ?? row['class_number']?.toString() ?? row['ClassNumber']?.toString();
        } else if (lower.contains('type')) {
          directName = row['Type']?.toString() ?? row['type']?.toString() ?? row['TypeName']?.toString();
        }

        if (directName != null && directName.isNotEmpty) {
          cells.add(DataCell(Align(alignment: Alignment.centerRight, child: Text(directName, textAlign: TextAlign.right))));
          continue;
        }

        // Fallback to lookup maps
        if ((lower.contains('group') || lower.contains('group_id')) && groupsMap != null && v != null) {
          cells.add(DataCell(Align(alignment: Alignment.centerRight, child: Text(groupsMap![v] ?? v.toString(), textAlign: TextAlign.right))));
          continue;
        }
        if ((lower.contains('type') || lower.contains('type_id')) && typesMap != null && v != null) {
          cells.add(DataCell(Align(alignment: Alignment.centerRight, child: Text(typesMap![v] ?? v.toString(), textAlign: TextAlign.right))));
          continue;
        }
        if ((lower.contains('class') || lower.contains('class_id')) && classesMap != null && v != null) {
          cells.add(DataCell(Align(alignment: Alignment.centerRight, child: Text(classesMap![v] ?? v.toString(), textAlign: TextAlign.right))));
          continue;
        }

        cells.add(DataCell(Align(alignment: Alignment.centerRight, child: Text(v == null ? '' : v.toString(), textAlign: TextAlign.right))));
      }

      // actions cell
      cells.add(DataCell(PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'view') {
            if (onView != null) onView!(row);
          } else if (v == 'edit') {
            if (onEdit != null) onEdit!(row);
          } else if (v == 'delete') {
            final confirm = await showDialog<bool>(
              context: _dummyContext, // replaced below
              builder: (c) => AlertDialog(
                title: const Text('حذف'),
                content: const Text('هل تريد حذف هذا السجل؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('لا')),
                  TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('نعم')),
                ],
              ),
            );
            if (confirm == true && onDelete != null) {
              await onDelete!(row['id']);
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'view', child: Text('عرض')),
          const PopupMenuItem(value: 'edit', child: Text('تعديل')),
          const PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      )));

      return DataRow(cells: cells);
    }).toList();
  }

  // Helper to prettify column keys
  static String _prettifyColumn(String key) {
    var s = key.replaceAll('_', ' ');
    s = s.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    final parts = s.split(RegExp(r"\s+"))..removeWhere((p) => p.trim().isEmpty);
    final capitalized = parts.map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '');
    }).join(' ');
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
        columns: _buildColumns(),
        rows: _buildRows(),
        columnSpacing: 24,
      ),
    );
  }
}
