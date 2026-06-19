import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_session.dart';
import '../widgets/responsive_table_container.dart';
import '../widgets/searchable_lov_field.dart';

class LookupSettingsScreen extends StatelessWidget {
  final UserSession userSession;

  const LookupSettingsScreen({super.key, required this.userSession});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _LookupTileData(
        title: 'المجموعات',
        subtitle: 'إدارة جدول Groups',
        icon: Icons.groups_rounded,
        color: const Color(0xFFDBEAFE),
        destination: GroupsLookupScreen(userSession: userSession),
      ),
      _LookupTileData(
        title: 'الحلقات',
        subtitle: 'إدارة جدول Classes',
        icon: Icons.class_rounded,
        color: const Color(0xFFDCFCE7),
        destination: ClassesLookupScreen(userSession: userSession),
      ),
      _LookupTileData(
        title: 'الأنواع',
        subtitle: 'إدارة جدول Types',
        icon: Icons.category_rounded,
        color: const Color(0xFFFFEDD5),
        destination: TypesLookupScreen(userSession: userSession),
      ),
      _LookupTileData(
        title: 'المستخدمون',
        subtitle: 'إدارة جدول Users',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFFF3E8FF),
        destination: UsersLookupScreen(userSession: userSession),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الجداول')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: userSession.hasFullAccess
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    var columns = 2;
                    if (constraints.maxWidth < 900) {
                      columns = 1;
                    }

                    return GridView.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: constraints.maxWidth < 900 ? 2.8 : 2.2,
                      children: sections
                          .map(
                            (section) => _LookupTile(
                              data: section,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => section.destination,
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'ليس لديك صلاحية لإدارة جداول الإعدادات.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      ),
    );
  }
}

class GroupsLookupScreen extends StatelessWidget {
  final UserSession userSession;

  const GroupsLookupScreen({super.key, required this.userSession});

  @override
  Widget build(BuildContext context) {
    return _SimpleLookupScreen(
      userSession: userSession,
      title: 'إعدادات المجموعات',
      tableName: 'Groups',
      valueColumn: 'Group_Name',
      valueLabel: 'اسم المجموعة',
    );
  }
}

class ClassesLookupScreen extends StatelessWidget {
  final UserSession userSession;

  const ClassesLookupScreen({super.key, required this.userSession});

  @override
  Widget build(BuildContext context) {
    return _SimpleLookupScreen(
      userSession: userSession,
      title: 'إعدادات الحلقات',
      tableName: 'Classes',
      valueColumn: 'Class_Number',
      valueLabel: 'رقم الحلقة',
    );
  }
}

class TypesLookupScreen extends StatelessWidget {
  final UserSession userSession;

  const TypesLookupScreen({super.key, required this.userSession});

  @override
  Widget build(BuildContext context) {
    return _SimpleLookupScreen(
      userSession: userSession,
      title: 'إعدادات الأنواع',
      tableName: 'Types',
      valueColumn: 'Type',
      valueLabel: 'النوع',
    );
  }
}

class UsersLookupScreen extends StatefulWidget {
  final UserSession userSession;

  const UsersLookupScreen({super.key, required this.userSession});

  @override
  State<UsersLookupScreen> createState() => _UsersLookupScreenState();
}

class _UsersLookupScreenState extends State<UsersLookupScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    if (!mounted) {
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _client
          .from('Users')
          .select('id, username, email, Full_name, role')
          .order('id');
      _rows = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل المستخدمين: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showUserDialog({Map<String, dynamic>? row}) async {
    final isEdit = row != null;
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(
      text: row?['username']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: row?['email']?.toString() ?? '',
    );
    final fullNameController = TextEditingController(
      text: row?['Full_name']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    var selectedRole = row?['role']?.toString() ?? 'supervisor';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'تعديل مستخدم' : 'إضافة مستخدم'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: usernameController,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'اسم المستخدم مطلوب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الكامل',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        SearchableLovField<String>(
                          value: selectedRole,
                          labelText: 'الصلاحية',
                          items: const [
                            SearchableLovItem(value: 'admin', label: 'admin'),
                            SearchableLovItem(
                              value: 'manager',
                              label: 'manager',
                            ),
                            SearchableLovItem(
                              value: 'supervisor',
                              label: 'supervisor',
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() => selectedRole = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: isEdit
                                ? 'كلمة المرور الجديدة (اختياري)'
                                : 'كلمة المرور',
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (!isEdit &&
                                (value == null || value.trim().isEmpty)) {
                              return 'كلمة المرور مطلوبة';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) {
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'username': usernameController.text.trim(),
        'email': emailController.text.trim().isEmpty
            ? null
            : emailController.text.trim(),
        'Full_name': fullNameController.text.trim().isEmpty
            ? null
            : fullNameController.text.trim(),
        'role': selectedRole,
      };
      final password = passwordController.text.trim();
      if (password.isNotEmpty) {
        payload['password'] = password;
      }

      if (isEdit) {
        await _client.from('Users').update(payload).eq('id', row['id']);
      } else {
        await _client.from('Users').insert(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'تم تحديث المستخدم' : 'تمت إضافة المستخدم'),
          ),
        );
      }
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل حفظ المستخدم: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteUser(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: const Text('سيتم حذف المستخدم نهائياً. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _client.from('Users').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف المستخدم')));
      }
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل حذف المستخدم: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المستخدمين'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadRows,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.userSession.hasFullAccess
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : () => _showUserDialog(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('إضافة مستخدم'),
            )
          : null,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: widget.userSession.hasFullAccess
            ? _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadRows,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'المستخدمون',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text('إجمالي السجلات: ${_rows.length}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: ResponsiveTableContainer(
                              padding: const EdgeInsets.all(12),
                              minWidth: 980,
                              child: DataTable(
                                dataTextStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                                columns: const [
                                  DataColumn(label: Text('المعرف')),
                                  DataColumn(label: Text('اسم المستخدم')),
                                  DataColumn(label: Text('الاسم الكامل')),
                                  DataColumn(label: Text('البريد')),
                                  DataColumn(label: Text('الصلاحية')),
                                  DataColumn(label: Text('إجراءات')),
                                ],
                                rows: _rows
                                    .map(
                                      (row) => DataRow(
                                        cells: [
                                          DataCell(Text('${row['id'] ?? ''}')),
                                          DataCell(
                                            Text(
                                              (row['username'] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              (row['Full_name'] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              (row['email'] ?? '').toString(),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              (row['role'] ?? '').toString(),
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
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 36,
                                                          minHeight: 36,
                                                        ),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: _saving
                                                        ? null
                                                        : () =>
                                                              _showUserDialog(
                                                                row: row,
                                                              ),
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'حذف',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 36,
                                                          minHeight: 36,
                                                        ),
                                                    padding: EdgeInsets.zero,
                                                    onPressed: _saving
                                                        ? null
                                                        : () => _deleteUser(
                                                            (row['id'] as num)
                                                                .toInt(),
                                                          ),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
            : const Center(child: Text('ليس لديك صلاحية لإدارة المستخدمين.')),
      ),
    );
  }
}

class _SimpleLookupScreen extends StatefulWidget {
  final UserSession userSession;
  final String title;
  final String tableName;
  final String valueColumn;
  final String valueLabel;

  const _SimpleLookupScreen({
    required this.userSession,
    required this.title,
    required this.tableName,
    required this.valueColumn,
    required this.valueLabel,
  });

  @override
  State<_SimpleLookupScreen> createState() => _SimpleLookupScreenState();
}

class _SimpleLookupScreenState extends State<_SimpleLookupScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _rows = [];

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
    final labelA = (a[widget.valueColumn] ?? '').toString();
    final labelB = (b[widget.valueColumn] ?? '').toString();
    final numA = _extractClassNumberForSort(labelA);
    final numB = _extractClassNumberForSort(labelB);
    final hasNumA = numA != (1 << 30);
    final hasNumB = numB != (1 << 30);
    if (hasNumA && hasNumB && numA != numB) return numA.compareTo(numB);
    if (hasNumA && !hasNumB) return -1;
    if (!hasNumA && hasNumB) return 1;
    return labelA.compareTo(labelB);
  }

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    if (!mounted) {
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _client
          .from(widget.tableName)
          .select('id, ${widget.valueColumn}')
          .order(widget.valueColumn);
      _rows = List<Map<String, dynamic>>.from(response as List);
      if (widget.tableName == 'Classes' || widget.valueColumn == 'Class_Number') {
        _rows.sort(_compareClassRows);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل البيانات: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showLookupDialog({Map<String, dynamic>? row}) async {
    final isEdit = row != null;
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: row?[widget.valueColumn]?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isEdit ? 'تعديل ${widget.valueLabel}' : 'إضافة ${widget.valueLabel}',
        ),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(labelText: widget.valueLabel),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '${widget.valueLabel} مطلوب';
                }
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) {
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        widget.valueColumn: controller.text.trim(),
      };

      if (isEdit) {
        await _client
            .from(widget.tableName)
            .update(payload)
            .eq('id', row['id']);
      } else {
        await _client.from(widget.tableName).insert(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'تم التحديث بنجاح' : 'تمت الإضافة بنجاح'),
          ),
        );
      }
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteRow(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف السجل'),
        content: const Text('سيتم حذف السجل نهائياً. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _client.from(widget.tableName).delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف السجل')));
      }
      await _loadRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadRows,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.userSession.hasFullAccess
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : () => _showLookupDialog(),
              icon: const Icon(Icons.add),
              label: Text('إضافة ${widget.valueLabel}'),
            )
          : null,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: widget.userSession.hasFullAccess
            ? _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadRows,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.valueLabel,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text('إجمالي السجلات: ${_rows.length}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: ResponsiveTableContainer(
                              padding: const EdgeInsets.all(12),
                              minWidth: 700,
                              child: DataTable(
                                dataTextStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                                columns: [
                                  const DataColumn(label: Text('المعرف')),
                                  DataColumn(label: Text(widget.valueLabel)),
                                  const DataColumn(label: Text('إجراءات')),
                                ],
                                rows: _rows
                                    .map(
                                      (row) => DataRow(
                                        cells: [
                                          DataCell(Text('${row['id'] ?? ''}')),
                                          DataCell(
                                            Text(
                                              (row[widget.valueColumn] ?? '')
                                                  .toString(),
                                            ),
                                          ),
                                          DataCell(
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                IconButton(
                                                  tooltip: 'تعديل',
                                                  onPressed: _saving
                                                      ? null
                                                      : () => _showLookupDialog(
                                                          row: row,
                                                        ),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'حذف',
                                                  onPressed: _saving
                                                      ? null
                                                      : () => _deleteRow(
                                                          (row['id'] as num)
                                                              .toInt(),
                                                        ),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
            : const Center(child: Text('ليس لديك صلاحية لإدارة هذا الجدول.')),
      ),
    );
  }
}

class _LookupTileData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget destination;

  const _LookupTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.destination,
  });
}

class _LookupTile extends StatelessWidget {
  final _LookupTileData data;
  final VoidCallback onTap;

  const _LookupTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: data.color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(data.icon, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(data.subtitle),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
