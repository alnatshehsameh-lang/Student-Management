import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_session.dart';
import '../widgets/responsive_table_container.dart';

class SupervisorsScreen extends StatefulWidget {
  final UserSession userSession;

  const SupervisorsScreen({super.key, required this.userSession});

  @override
  State<SupervisorsScreen> createState() => _SupervisorsScreenState();
}

class _SupervisorsScreenState extends State<SupervisorsScreen> {
  final _client = Supabase.instance.client;

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

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final lookups = await Future.wait<dynamic>([
        _client.from('Users').select('id, username, email, Full_name, role').eq('role', 'supervisor').order('username'),
        _client.from('Classes').select('id, Class_Number').order('Class_Number'),
        _client.from('Groups').select('id, Group_Name').order('Group_Name'),
        _client.from('Types').select('id, Type').order('Type'),
      ]);

      _users = List<Map<String, dynamic>>.from(lookups[0] as List);
      _classes = List<Map<String, dynamic>>.from(lookups[1] as List);
      _groups = List<Map<String, dynamic>>.from(lookups[2] as List);
      _types = List<Map<String, dynamic>>.from(lookups[3] as List);

      _classNames
        ..clear()
        ..addEntries(_classes.map((e) => MapEntry(_asInt(e['id'])!, (e['Class_Number'] ?? '').toString())));
      _groupNames
        ..clear()
        ..addEntries(_groups.map((e) => MapEntry(_asInt(e['id'])!, (e['Group_Name'] ?? '').toString())));
      _typeNames
        ..clear()
        ..addEntries(_types.map((e) => MapEntry(_asInt(e['id'])!, (e['Type'] ?? '').toString())));

      final managersRes = await _client
          .from('Managers')
          .select('id, person_number, full_name, country, type, line_manager, User_id, Class_id, Group_id, Type_id, Users!inner(id, username, email, Full_name, role)')
          .eq('Users.role', 'supervisor')
          .order('id');

      final rows = List<Map<String, dynamic>>.from(managersRes as List);
      _supervisors = rows.map((m) {
        final user = m['Users'] as Map<String, dynamic>?;
        return {
          'id': _asInt(m['id']),
          'person_number': _asInt(m['person_number']),
          'full_name': m['full_name'],
          'country': m['country'],
          'type': m['type'],
          'line_manager': _asInt(m['line_manager']),
          'User_id': _asInt(m['User_id']),
          'Class_id': _asInt(m['Class_id']),
          'Group_id': _asInt(m['Group_id']),
          'Type_id': _asInt(m['Type_id']),
          'username': user?['username'],
          'email': user?['email'],
          'user_full_name': user?['Full_name'],
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
    final lineManagerController = TextEditingController(text: row?['line_manager']?.toString() ?? '');

    String managerType = row?['type']?.toString() ?? 'supervisor';
    int? selectedClassId = row?['Class_id'] as int?;
    int? selectedGroupId = row?['Group_id'] as int?;
    int? selectedTypeId = row?['Type_id'] as int?;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogInnerContext, setDialogState) {
            final selectedUser = _users.where((u) => _asInt(u['id']) == selectedUserId).cast<Map<String, dynamic>>().toList();
            final selectedEmail = selectedUser.isNotEmpty ? (selectedUser.first['email']?.toString() ?? '-') : '-';
            final selectedUserFullName = selectedUser.isNotEmpty ? (selectedUser.first['Full_name']?.toString() ?? '-') : '-';

            return AlertDialog(
              title: Text(isEdit ? 'تعديل مشرفة' : 'إضافة مشرفة جديدة'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedUserId,
                        decoration: const InputDecoration(labelText: 'اسم المستخدم (من جدول Users)'),
                        items: _users
                            .map(
                              (u) => DropdownMenuItem<int>(
                                value: _asInt(u['id'])!,
                                child: Text(u['username']?.toString() ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUserId = value;
                            if (fullNameController.text.trim().isEmpty) {
                              final selected = _users.where((u) => _asInt(u['id']) == value).cast<Map<String, dynamic>>().toList();
                              if (selected.isNotEmpty) {
                                final fromUser = selected.first['Full_name']?.toString();
                                final username = selected.first['username']?.toString();
                                fullNameController.text = (fromUser != null && fromUser.trim().isNotEmpty)
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
                        child: Text('البريد: $selectedEmail | الاسم في Users: $selectedUserFullName'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل في Managers'),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: countryController,
                        decoration: const InputDecoration(labelText: 'الدولة (اختياري)'),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: managerType,
                        decoration: const InputDecoration(labelText: 'نوع السجل في Managers'),
                        items: const [
                          DropdownMenuItem(value: 'supervisor', child: Text('supervisor')),
                          DropdownMenuItem(value: 'manager', child: Text('manager')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => managerType = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: lineManagerController,
                        decoration: const InputDecoration(labelText: 'Line Manager (رقم) - اختياري'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int?>(
                        value: selectedClassId,
                        decoration: const InputDecoration(labelText: 'الحلقة (اختياري)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('غير محدد')),
                          ..._classes.map(
                            (e) => DropdownMenuItem<int?>(
                              value: _asInt(e['id']),
                              child: Text((e['Class_Number'] ?? '').toString()),
                            ),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() => selectedClassId = value),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        value: selectedGroupId,
                        decoration: const InputDecoration(labelText: 'المجموعة (اختياري)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('غير محدد')),
                          ..._groups.map(
                            (e) => DropdownMenuItem<int?>(
                              value: _asInt(e['id']),
                              child: Text((e['Group_Name'] ?? '').toString()),
                            ),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() => selectedGroupId = value),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        value: selectedTypeId,
                        decoration: const InputDecoration(labelText: 'الرواية (اختياري)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('غير محدد')),
                          ..._types.map(
                            (e) => DropdownMenuItem<int?>(
                              value: _asInt(e['id']),
                              child: Text((e['Type'] ?? '').toString()),
                            ),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() => selectedTypeId = value),
                      ),
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
                          final lineManager = int.tryParse(lineManagerController.text.trim());

                          if (selectedUserId == null) {
                            ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                              const SnackBar(content: Text('يرجى اختيار اسم المستخدم من جدول Users')),
                            );
                            return;
                          }

                          if (fullName.isEmpty) {
                            ScaffoldMessenger.of(dialogInnerContext).showSnackBar(
                              const SnackBar(content: Text('الاسم الكامل مطلوب')),
                            );
                            return;
                          }

                          setState(() => _saving = true);

                          try {
                            if (!isEdit) {
                              await _client.from('Managers').insert({
                                'User_id': selectedUserId,
                                'full_name': fullName,
                                'country': country.isEmpty ? null : country,
                                'type': managerType,
                                'line_manager': lineManager,
                                'Class_id': selectedClassId,
                                'Group_id': selectedGroupId,
                                'Type_id': selectedTypeId,
                              });
                            } else {
                              final managerId = row['id'] as int;
                              await _client.from('Managers').update({
                                'User_id': selectedUserId,
                                'full_name': fullName,
                                'country': country.isEmpty ? null : country,
                                'type': managerType,
                                'line_manager': lineManager,
                                'Class_id': selectedClassId,
                                'Group_id': selectedGroupId,
                                'Type_id': selectedTypeId,
                              }).eq('id', managerId);
                            }

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isEdit ? 'تم تحديث بيانات المشرفة' : 'تمت إضافة المشرفة')),
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

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل تريد حذف المشرفة "$displayName"؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف المشرفة: $e')),
        );
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
                                    columns: const [
                                      DataColumn(label: Text('الرقم الوظيفي')),
                                      DataColumn(label: Text('الاسم الكامل')),
                                      DataColumn(label: Text('اسم المستخدم')),
                                      DataColumn(label: Text('البريد الإلكتروني')),
                                      DataColumn(label: Text('الدولة')),
                                      DataColumn(label: Text('النوع')),
                                      DataColumn(label: Text('Line Manager')),
                                      DataColumn(label: Text('الحلقة')),
                                      DataColumn(label: Text('المجموعة')),
                                      DataColumn(label: Text('الرواية')),
                                      DataColumn(label: Text('الإجراءات')),
                                    ],
                                    rows: _supervisors.map((row) {
                                      final classId = row['Class_id'] as int?;
                                      final groupId = row['Group_id'] as int?;
                                      final typeId = row['Type_id'] as int?;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(row['person_number']?.toString() ?? '-')),
                                          DataCell(Text(row['full_name']?.toString() ?? '-')),
                                          DataCell(Text(row['username']?.toString() ?? '-')),
                                          DataCell(Text(row['email']?.toString() ?? '-')),
                                          DataCell(Text(row['country']?.toString() ?? '-')),
                                          DataCell(Text(row['type']?.toString() ?? '-')),
                                          DataCell(Text(row['line_manager']?.toString() ?? '-')),
                                          DataCell(Text(classId != null ? (_classNames[classId] ?? classId.toString()) : '-')),
                                          DataCell(Text(groupId != null ? (_groupNames[groupId] ?? groupId.toString()) : '-')),
                                          DataCell(Text(typeId != null ? (_typeNames[typeId] ?? typeId.toString()) : '-')),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'تعديل',
                                                  onPressed: _saving ? null : () => _showSupervisorDialog(row: row),
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                ),
                                                IconButton(
                                                  tooltip: 'حذف',
                                                  onPressed: _saving ? null : () => _deleteSupervisor(row),
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                ),
                                              ],
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
