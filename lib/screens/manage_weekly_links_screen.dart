import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class ManageWeeklyLinksScreen extends StatefulWidget {
  final UserSession userSession;
  const ManageWeeklyLinksScreen({super.key, required this.userSession});

  @override
  State<ManageWeeklyLinksScreen> createState() => _ManageWeeklyLinksScreenState();
}

class _ManageWeeklyLinksScreenState extends State<ManageWeeklyLinksScreen> {
  final _client = Supabase.instance.client;
  bool _generating = false;
  List<Map<String, dynamic>> _generatedLinks = [];
  DateTime _selectedWeekStart = _getStartOfWeek(DateTime.now());
  int? _userClassId;
  int? _userGroupId;
  int? _userTypeId;

  static DateTime _getStartOfWeek(DateTime date) {
    // Get Sunday as start of week
    return date.subtract(Duration(days: date.weekday % 7));
  }

  @override
  void initState() {
    super.initState();
    _fetchUserRestrictions();
  }

  Future<void> _fetchUserRestrictions() async {
    if (widget.userSession.isAdmin || widget.userSession.userId == null) {
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
  }

  Future<void> _generateLinks() async {
    setState(() => _generating = true);

    try {
      final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
      final weekStartStr = _selectedWeekStart.toIso8601String().split('T')[0];
      final weekEndStr = weekEnd.toIso8601String().split('T')[0];

      // Generate one shared token for this week, class, and group
      final sharedToken = _generateToken(DateTime.now().millisecondsSinceEpoch);
      
      // Store or retrieve the shared link info
      final existingLink = await _client
          .from('Weekly_Werd_Shared_Links')
          .select('shared_token')
          .eq('week_start_date', weekStartStr)
          .eq('Class_id', _userClassId ?? 0)
          .eq('Group_id', _userGroupId ?? 0)
          .maybeSingle();

      String finalToken;
      if (existingLink != null) {
        finalToken = existingLink['shared_token'];
      } else {
        // Insert new shared link
        await _client.from('Weekly_Werd_Shared_Links').insert({
          'week_start_date': weekStartStr,
          'week_end_date': weekEndStr,
          'Class_id': _userClassId,
          'Group_id': _userGroupId,
          'Type_id': _userTypeId,
          'shared_token': sharedToken,
          'created_by': widget.userSession.userId,
        });
        finalToken = sharedToken;
      }

      final sharedLink = 'https://yourapp.com/werd-checklist/$finalToken';

      setState(() {
        _generatedLinks = [{
          'type': 'shared',
          'class_id': _userClassId,
          'group_id': _userGroupId,
          'week': '$weekStartStr - $weekEndStr',
          'token': finalToken,
          'link': sharedLink,
        }];
        _generating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الرابط المشترك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() => _generating = false);
    }
  }

  String _generateToken(int studentId) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = timestamp + studentId * 1000;
    final buffer = StringBuffer();
    
    for (int i = 0; i < 40; i++) {
      final index = ((random + i * 7919 + studentId * 13) % chars.length).abs();
      buffer.write(chars[index]);
    }
    
    return buffer.toString();
  }

  void _copyLink(String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط')),
    );
  }

  void _copyAllLinks() {
    if (_generatedLinks.isEmpty) return;
    
    final link = _generatedLinks.first['link'];
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الرابط')),
    );
  }

  Future<void> _selectWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ من الأسبوع',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (picked != null) {
      setState(() {
        _selectedWeekStart = _getStartOfWeek(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة روابط الورد الأسبوعي'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // Week Selector
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر الأسبوع',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectWeek,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'الأسبوع المحدد',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${_selectedWeekStart.toString().split(' ')[0]} - ${weekEnd.toString().split(' ')[0]}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _generateLinks,
                      icon: _generating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: Text(_generating ? 'جاري الإنشاء...' : 'إنشاء الروابط'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Generated Links List
            if (_generatedLinks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تم إنشاء ${_generatedLinks.length} رابط',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _copyAllLinks,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('نسخ الكل'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _generatedLinks.length,
                  itemBuilder: (context, index) {
                    final link = _generatedLinks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.link,
                                    color: Colors.green[700],
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'رابط مشترك للمجموعة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        'الأسبوع: ${link['week']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      link['link'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _copyLink(link['link']),
                                icon: const Icon(Icons.copy),
                                label: const Text('نسخ الرابط لمشاركته'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'شارك هذا الرابط مع جميع الطلاب في المجموعة عبر واتساب',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لم يتم إنشاء روابط بعد',
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'اضغط على "إنشاء الروابط" للبدء',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
