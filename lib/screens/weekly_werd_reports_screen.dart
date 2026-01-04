import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_session.dart';

class WeeklyWerdReportsScreen extends StatefulWidget {
  final UserSession userSession;
  const WeeklyWerdReportsScreen({super.key, required this.userSession});

  @override
  State<WeeklyWerdReportsScreen> createState() => _WeeklyWerdReportsScreenState();
}

class _WeeklyWerdReportsScreenState extends State<WeeklyWerdReportsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _submissions = [];
  DateTime? _selectedWeekStart;
  int? _userClassId;
  int? _userGroupId;

  @override
  void initState() {
    super.initState();
    _fetchUserRestrictions();
  }

  Future<void> _fetchUserRestrictions() async {
    if (widget.userSession.isAdmin || widget.userSession.userId == null) {
      _fetchSubmissions();
      return;
    }

    try {
      final response = await _client
          .from('Managers')
          .select('Class_id, Group_id')
          .eq('User_id', widget.userSession.userId!)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _userClassId = response['Class_id'];
          _userGroupId = response['Group_id'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch restrictions: $e');
    }
    
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _loading = true);
    try {
      var builder = _client
          .from('Weekly_Werd')
          .select('*, Students(id, Student_Name, Student_Code, Class_id, Group_id)');

      // Apply restrictions
      if (!widget.userSession.isAdmin) {
        if (_userClassId != null) {
          builder = builder.eq('Class_id', _userClassId!);
        }
        if (_userGroupId != null) {
          builder = builder.eq('Group_id', _userGroupId!);
        }
      }

      // Filter by selected week if any
      if (_selectedWeekStart != null) {
        builder = builder.eq('week_start_date', _selectedWeekStart!.toIso8601String().split('T')[0]);
      }

      final res = await builder.order('week_start_date', ascending: false).limit(100);

      if (res is List) {
        setState(() {
          _submissions = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Error fetching submissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSubmissionDetails(Map<String, dynamic> submission) {
    final responses = submission['checklist_responses'] as List;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الورد الأسبوعي'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الطالب: ${submission['Students']?['Student_Name'] ?? 'غير معروف'} (${submission['Students']?['Student_Code'] ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('الأسبوع: ${submission['week_start_date']} - ${submission['week_end_date']}'),
              const Divider(height: 24),
              ...responses.map((r) {
                final status = r['status'];
                Color statusColor = Colors.grey;
                String statusText = 'لم يتم';
                IconData statusIcon = Icons.close;

                if (status == 'completed') {
                  statusColor = Colors.green;
                  statusText = 'مكتمل';
                  statusIcon = Icons.check_circle;
                } else if (status == 'partially') {
                  statusColor = Colors.orange;
                  statusText = 'جزئياً';
                  statusIcon = Icons.pending;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['question'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor),
                          ),
                        ],
                      ),
                      if (r['comment'] != null && (r['comment'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ملاحظة: ${r['comment']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير الورد الأسبوعي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSubmissions,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _submissions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد تقارير حتى الآن',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _submissions.length,
                    itemBuilder: (context, index) {
                      final submission = _submissions[index];
                      final responses = submission['checklist_responses'] as List;
                      
                      // Calculate completion percentage
                      int completed = responses.where((r) => r['status'] == 'completed').length;
                      int total = responses.length;
                      double percentage = (completed / total) * 100;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showSubmissionDetails(submission),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: percentage >= 80
                                          ? Colors.green
                                          : percentage >= 50
                                              ? Colors.orange
                                              : Colors.red,
                                      child: Text(
                                        '${percentage.toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${submission['Students']?['Student_Name'] ?? 'غير معروف'} (${submission['Students']?['Student_Code'] ?? ''})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'الأسبوع: ${submission['week_start_date']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_left),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    percentage >= 80
                                        ? Colors.green
                                        : percentage >= 50
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$completed من $total مكتمل',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
