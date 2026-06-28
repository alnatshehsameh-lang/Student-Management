import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_session.dart';
import '../widgets/responsive_table_container.dart';
import '../widgets/searchable_lov_field.dart';

class SupervisorsScreen extends StatefulWidget {
  final UserSession userSession;

  const SupervisorsScreen({super.key, required this.userSession});

  @override
  State<SupervisorsScreen> createState() => _SupervisorsScreenState();
}

class _SupervisorsScreenState extends State<SupervisorsScreen> {
  final _client = Supabase.instance.client;

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

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _supervisors = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _types = [];

  final Map<int, String> _classNames = {};
  final Map<int, String> _groupNames = {};
  final Map<int, String> _typeNames = {};

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  String _scopeLabel(int? classId, int? groupId, int? typeId) {
    final classLabel = classId == null
        ? '-'
        : (_classNames[classId] ?? classId.toString());
    final groupLabel = groupId == null
        ? '-'
        : (_groupNames[groupId] ?? groupId.toString());
    final typeLabel = typeId == null
        ? '-'
        : (_typeNames[typeId] ?? typeId.toString());
    return 'حلقة: $classLabel | مجموعة: $groupLabel | رواية: $typeLabel';
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final lookups = await Future.wait<dynamic>([
        _client
            .from('Users')
            .select('id, username, email, Full_name, role')
            .order('username'),
        _client.from('Classes').select('id, Class_Number').order('Class_Number'),
        _client.from('Groups').select('id, Group_Name').order('Group_Name'),
        _client.from('Types').select('id, Type').order('Type'),
      ]);

      _users = List<Map<String, dynamic>>.from(lookups[0] as List);
      _classes = List<Map<String, dynamic>>.from(lookups[1] as List);
      _classes.sort(_compareClassRows);
      _groups = List<Map<String, dynamic>>.from(lookups[2] as List);
      _types = List<Map<String, dynamic>>.from(lookups[3] as List);

      _classNames
        ..clear()
        ..addEntries(
          _classes.map(
            (e) => MapEntry(_asInt(e['id'])!, (e['Class_Number'] ?? '').toString()),
          ),
        );
      _groupNames
        ..clear()
        ..addEntries(
          _groups.map(
            (e) => MapEntry(_asInt(e['id'])!, (e['Group_Name'] ?? '').toString()),
          ),
        );
      _typeNames
        ..clear()
        ..addEntries(
          _types.map(
            (e) => MapEntry(_asInt(e['id'])!, (e['Type'] ?? '').toString()),
          ),
        );

      final managersRes = await _client
          .from('Managers')
          .select(
            'id, person_number, full_name, country, type, line_manager, User_id, Users!inner(id, username, email, Full_name, role), Managers_Lines(id, Group_id, Class_id, Type_id, is_active, effective_from, effective_to)',
          )
          .eq('Users.role', 'supervisor')
          .order('id');

      final rows = List<Map<String, dynamic>>.from(managersRes as List);
      _supervisors = rows.map((m) {
        final user = m['Users'] as Map<String, dynamic>?;

        final linesRaw = m['Managers_Lines'];
        final lines = <Map<String, dynamic>>[];
        if (linesRaw is List) {
          for (final line in List<Map<String, dynamic>>.from(linesRaw)) {
            lines.add({
              'id': _asInt(line['id']),
              'Class_id': _asInt(line['Class_id']),
              'Group_id': _asInt(line['Group_id']),
              'Type_id': _asInt(line['Type_id']),
              'is_active': line['is_active'] == true,
              'effective_from': line['effective_from'],
              'effective_to': line['effective_to'],
            });
          }
        }

        final scopeSummary = lines
            .map(
              (line) => _scopeLabel(
                line['Class_id'] as int?,
                line['Group_id'] as int?,
                line['Type_id'] as int?,
              ),
            )
            .join('\n');

        return {
          'id': _asInt(m['id']),
          'person_number': _asInt(m['person_number']),
          'full_name': m['full_name'],
          'country': m['country'],
          'type': m['type'],
          'line_manager': _asInt(m['line_manager']),
          'User_id': _asInt(m['User_id']),
          'username': user?['username'],
          'email': user?['email'],
          'user_full_name': user?['Full_name'],
          'lines': lines,
          'lines_count': lines.length,
          'lines_summary': scopeSummary,
        };
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تحميل بيانات المشرفات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSupervisorDialog({Map<String, dynamic>? row}) async {
    final isEdit = row != null;

    int? selectedUserId = row?['User_id'] as int?;
    final fullNameController = TextEditingController(
      text: row?['full_name']?.toString() ?? row?['user_full_name']?.toString() ?? '',
    );
    final countryController = TextEditingController(text: row?['country']?.toString() ?? '');
    final lineManagerController = TextEditingController(
      text: row?['line_manager']?.toString() ?? '',
    );

    String managerType = row?['type']?.toString() ?? 'supervisor';
    final initialLines = (row?['lines'] is List)
        ? List<Map<String, dynamic>>.from(row!['lines'] as List)
        : <Map<String, dynamic>>[];
    final lines = initialLines.isEmpty
        ? <Map<String, dynamic>>[
            {
              'id': null,
              'Class_id': null,
              'Group_id': null,
              'Type_id': null,
              'is_active': true,
              'effective_from': null,
              'effective_to': null,
            },
          ]
        : initialLines.map((line) => Map<String, dynamic>.from(line)).toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            final selectedUser = _users
                .where((u) => _asInt(u['id']) == selectedUserId)
                .cast<Map<String, dynamic>>()
                .toList();
            final selectedEmail = selectedUser.isNotEmpty
                ? (selectedUser.first['email']?.toString() ?? '-')
                : '-';
            final selectedUserFullName = selectedUser.isNotEmpty
                ? (selectedUser.first['Full_name']?.toString() ?? '-')
                : '-';

            void addLine() {
              setDialogState(() {
                lines.add({
                  'id': null,
                  'Class_id': null,
                  'Group_id': null,
                  'Type_id': null,
                  'is_active': true,
                  'effective_from': null,
                  'effective_to': null,
                });
              });
            }

            void removeLine(int index) {
              setDialogState(() {
                if (lines.length == 1) {
                  lines[0] = {
                    'id': null,
                    'Class_id': null,
                    'Group_id': null,
                    'Type_id': null,
                    'is_active': true,
                    'effective_from': null,
                    'effective_to': null,
                  };
                  return;
                }
                lines.removeAt(index);
              });
            }

            return AlertDialog(
              title: Text(isEdit ? 'تعديل مشرفة' : 'إضافة مشرفة جديدة'),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'بيانات المشرفة (Header)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 10),
                      SearchableLovField<int>(
                        value: selectedUserId,
                        labelText: 'اسم المستخدم (من جدول Users)',
                        items: _users
                            .map(
                              (u) => SearchableLovItem<int>(
                                value: _asInt(u['id'])!,
                                label: u['username']?.toString() ?? '',
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUserId = value;
                            if (fullNameController.text.trim().isEmpty) {
                              final selected = _users
                                  .where((u) => _asInt(u['id']) == value)
                                  .cast<Map<String, dynamic>>()
                                  .toList();
                              if (selected.isNotEmpty) {
                                final fromUser = selected.first['Full_name']?.toString();
                                final username = selected.first['username']?.toString();
                                fullNameController.text =
                                    (fromUser != null && fromUser.trim().isNotEmpty)
                                    ? fromUser
                                    : (username ?? '');
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'البريد: $selectedEmail | الاسم في Users: $selectedUserFullName',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل في Managers',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: countryController,
                        decoration: const InputDecoration(
                          labelText: 'الدولة (اختياري)',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 10),
                      SearchableLovField<String>(
                        value: managerType,
                        labelText: 'نوع السجل في Managers',
                        items: const [
                          SearchableLovItem(value: 'supervisor', label: 'supervisor'),
                          SearchableLovItem(value: 'manager', label: 'manager'),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => managerType = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: lineManagerController,
                        decoration: const InputDecoration(
                          labelText: 'Line Manager (رقم) - اختياري',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'التعيينات (Lines)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextButton.icon(
                            onPressed: addLine,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة سطر'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(lines.length, (index) {
                        final line = lines[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'السطر ${index + 1}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف السطر',
                                      onPressed: () => removeLine(index),
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SearchableLovField<int?>(
                                  value: line['Class_id'] as int?,
                                  labelText: 'الحلقة',
                                  items: [
                                    const SearchableLovItem<int?>(value: null, label: 'اختر الحلقة'),
                                    ..._classes.map(
                                      (e) => SearchableLovItem<int?>(
                                        value: _asInt(e['id']),
                                        label: (e['Class_Number'] ?? '').toString(),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() => line['Class_id'] = value);
                                  },
                                ),
                                const SizedBox(height: 8),
                                SearchableLovField<int?>(
                                  value: line['Group_id'] as int?,
                                  labelText: 'المجموعة',
                                  items: [
                                    const SearchableLovItem<int?>(value: null, label: 'اختر المجموعة'),
                                    ..._groups.map(
                                      (e) => SearchableLovItem<int?>(
                                        value: _asInt(e['id']),
                                        label: (e['Group_Name'] ?? '').toString(),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() => line['Group_id'] = value);
                                  },
                                ),
                                const SizedBox(height: 8),
                                SearchableLovField<int?>(
                                  value: line['Type_id'] as int?,
                                  labelText: 'الرواية',
                                  items: [
                                    const SearchableLovItem<int?>(value: null, label: 'اختر الرواية'),
                                    ..._types.map(
                                      (e) => SearchableLovItem<int?>(
                                        value: _asInt(e['id']),
                                        label: (e['Type'] ?? '').toString(),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() => line['Type_id'] = value);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final fullName = fullNameController.text.trim();
                          final country = countryController.text.trim();
                          final lineManager = int.tryParse(
                            lineManagerController.text.trim(),
                          );

                          if (selectedUserId == null) {
                            ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى اختيار اسم المستخدم من جدول Users'),
                              ),
                            );
                            return;
                          }

                          if (fullName.isEmpty) {
                            ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                              const SnackBar(content: Text('الاسم الكامل مطلوب')),
                            );
                            return;
                          }

                          if (lines.isEmpty) {
                            ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                              const SnackBar(content: Text('يجب إضافة سطر تعيين واحد على الأقل')),
                            );
                            return;
                          }

                          final normalizedLines = <Map<String, int>>[];
                          final uniqueness = <String>{};
                          for (var i = 0; i < lines.length; i++) {
                            final classId = _asInt(lines[i]['Class_id']);
                            final groupId = _asInt(lines[i]['Group_id']);
                            final typeId = _asInt(lines[i]['Type_id']);
                            if (classId == null || groupId == null || typeId == null) {
                              ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                                SnackBar(content: Text('يرجى استكمال بيانات السطر ${i + 1}')),
                              );
                              return;
                            }
                            final key = '$classId|$groupId|$typeId';
                            if (uniqueness.contains(key)) {
                              ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                                const SnackBar(content: Text('لا يمكن تكرار نفس الحلقة/المجموعة/الرواية')),
                              );
                              return;
                            }
                            uniqueness.add(key);
                            normalizedLines.add({
                              'Class_id': classId,
                              'Group_id': groupId,
                              'Type_id': typeId,
                            });
                          }

                          setState(() => _saving = true);

                          try {
                            int managerId;
                            final managerPayload = {
                              'User_id': selectedUserId,
                              'full_name': fullName,
                              'country': country.isEmpty ? null : country,
                              'type': managerType,
                              'line_manager': lineManager,
                            };

                            if (!isEdit) {
                              final existingByUser = await _client
                                  .from('Managers')
                                  .select('id')
                                  .eq('User_id', selectedUserId!)
                                  .maybeSingle();

                              if (existingByUser != null) {
                                managerId = _asInt(existingByUser['id'])!;
                                await _client
                                    .from('Managers')
                                    .update(managerPayload)
                                    .eq('id', managerId);
                              } else {
                                try {
                                  final inserted = await _client
                                      .from('Managers')
                                      .insert(managerPayload)
                                      .select('id')
                                      .single();
                                  managerId = _asInt(inserted['id'])!;
                                } on PostgrestException catch (e) {
                                  if (e.code == '23505' &&
                                      e.message.contains('MANAGERS_full_name_key')) {
                                    final existingByName = await _client
                                        .from('Managers')
                                        .select('id')
                                        .eq('full_name', fullName)
                                        .maybeSingle();
                                    if (existingByName == null) rethrow;
                                    managerId = _asInt(existingByName['id'])!;
                                    await _client
                                        .from('Managers')
                                        .update(managerPayload)
                                        .eq('id', managerId);
                                  } else {
                                    rethrow;
                                  }
                                }
                              }
                            } else {
                              managerId = row['id'] as int;
                              await _client
                                  .from('Managers')
                                  .update(managerPayload)
                                  .eq('id', managerId);
                            }

                            await _client
                                .from('Managers_Lines')
                                .delete()
                                .eq('manager_id', managerId);

                            final linePayload = normalizedLines
                                .map(
                                  (line) => {
                                    'manager_id': managerId,
                                    'Class_id': line['Class_id'],
                                    'Group_id': line['Group_id'],
                                    'Type_id': line['Type_id'],
                                    'is_active': true,
                                  },
                                )
                                .toList();
                            await _client.from('Managers_Lines').insert(linePayload);

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit ? 'تم تحديث بيانات المشرفة' : 'تمت إضافة المشرفة',
                                  ),
                                ),
                              );
                            }

                            await _fetchAll();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تعذر حفظ بيانات المشرفة: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSupervisor(Map<String, dynamic> row) async {
    final managerId = row['id'] as int;
    final displayName = row['full_name']?.toString().trim().isNotEmpty == true
        ? row['full_name'].toString()
        : (row['username']?.toString() ?? '');

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف المشرفة "$displayName"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      await _client.from('Managers').delete().eq('id', managerId);
      await _fetchAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المشرفة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حذف المشرفة: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.userSession.hasFullAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة المشرفات')),
        body: const Center(
          child: Text(
            'ليس لديك صلاحية للوصول إلى هذه الصفحة',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المشرفات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetchAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNarrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saving ? null : () => _showSupervisorDialog(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('إضافة مشرفة'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'عدد المشرفات: ${_supervisors.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saving ? null : () => _showSupervisorDialog(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('إضافة مشرفة'),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'عدد المشرفات: ${_supervisors.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _supervisors.isEmpty
                        ? const Center(child: Text('لا توجد مشرفات'))
                        : Card(
                            child: ResponsiveTableContainer(
                              child: DataTable(
                                dataTextStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                                columns: const [
                                  DataColumn(label: Text('الرقم الوظيفي')),
                                  DataColumn(label: Text('الاسم الكامل')),
                                  DataColumn(label: Text('اسم المستخدم')),
                                  DataColumn(label: Text('البريد الإلكتروني')),
                                  DataColumn(label: Text('الدولة')),
                                  DataColumn(label: Text('النوع')),
                                  DataColumn(label: Text('Line Manager')),
                                  DataColumn(label: Text('عدد السطور')),
                                  DataColumn(label: Text('التعيينات')),
                                  DataColumn(label: Text('الإجراءات')),
                                ],
                                rows: _supervisors.map((row) {
                                  final linesCount = row['lines_count'] as int? ?? 0;
                                  final linesSummary = row['lines_summary']?.toString() ?? '-';

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(row['person_number']?.toString() ?? '-')),
                                      DataCell(Text(row['full_name']?.toString() ?? '-')),
                                      DataCell(Text(row['username']?.toString() ?? '-')),
                                      DataCell(Text(row['email']?.toString() ?? '-')),
                                      DataCell(Text(row['country']?.toString() ?? '-')),
                                      DataCell(Text(row['type']?.toString() ?? '-')),
                                      DataCell(Text(row['line_manager']?.toString() ?? '-')),
                                      DataCell(Text(linesCount.toString())),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 320),
                                          child: Text(
                                            linesSummary.isEmpty ? '-' : linesSummary,
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 96,
                                          child: Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: [
                                              IconButton(
                                                tooltip: 'تعديل',
                                                visualDensity: VisualDensity.compact,
                                                constraints: const BoxConstraints(
                                                  minWidth: 36,
                                                  minHeight: 36,
                                                ),
                                                padding: EdgeInsets.zero,
                                                onPressed: _saving
                                                    ? null
                                                    : () => _showSupervisorDialog(row: row),
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                              ),
                                              IconButton(
                                                tooltip: 'حذف',
                                                visualDensity: VisualDensity.compact,
                                                constraints: const BoxConstraints(
                                                  minWidth: 36,
                                                  minHeight: 36,
                                                ),
                                                padding: EdgeInsets.zero,
                                                onPressed: _saving
                                                    ? null
                                                    : () => _deleteSupervisor(row),
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
