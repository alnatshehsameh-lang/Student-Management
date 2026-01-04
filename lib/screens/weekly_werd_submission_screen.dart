import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyWerdSubmissionScreen extends StatefulWidget {
  final String? submissionToken;
  
  const WeeklyWerdSubmissionScreen({
    super.key,
    this.submissionToken,
  });

  @override
  State<WeeklyWerdSubmissionScreen> createState() => _WeeklyWerdSubmissionScreenState();
}

class _WeeklyWerdSubmissionScreenState extends State<WeeklyWerdSubmissionScreen> with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  Map<String, dynamic>? _submission;
  Map<String, dynamic>? _student;
  List<Map<String, dynamic>> _questions = [];
  final Map<String, String> _responses = {}; // question_id -> status
  final Map<String, String> _comments = {}; // question_id -> comment
  
  late AnimationController _successAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    _loadSubmission();
  }

  @override
  void dispose() {
    _successAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmission() async {
    if (widget.submissionToken == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // First check if it's a shared link
      final sharedLinkRes = await _client
          .from('Weekly_Werd_Shared_Links')
          .select('*')
          .eq('shared_token', widget.submissionToken!)
          .limit(1)
          .maybeSingle();

      if (sharedLinkRes != null) {
        // It's a shared link - show student selector
        await _showStudentSelector(sharedLinkRes);
        return;
      }

      // Otherwise try individual submission
      final submissionRes = await _client
          .from('Weekly_Werd')
          .select('*, Students(id, Student_Name, Student_Code)')
          .eq('submission_token', widget.submissionToken!)
          .limit(1)
          .maybeSingle();

      if (submissionRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رابط غير صحيح')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      // Load active checklist template
      final templateRes = await _client
          .from('Weekly_Checklist_Template')
          .select('*')
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (templateRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد نموذج فعّال')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final checklistItems = templateRes['checklist_items'] as List;
      final existingResponses = submissionRes['checklist_responses'] as List;

      setState(() {
        _submission = submissionRes;
        _student = submissionRes['Students'];
        _questions = List<Map<String, dynamic>>.from(checklistItems);
        
        // Load existing responses if any
        for (var response in existingResponses) {
          final itemId = response['item_id'];
          _responses[itemId] = response['status'];
          if (response['comment'] != null) {
            _comments[itemId] = response['comment'];
          }
        }
        
        // Check if already submitted
        _submitted = existingResponses.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحميل: $e')),
        );
      }
      setState(() => _loading = false);
    }
  }

  int get _completedCount {
    return _responses.values.where((status) => status == 'completed').length;
  }

  int get _totalCount => _questions.length;

  double get _progressPercentage {
    if (_totalCount == 0) return 0;
    return (_completedCount / _totalCount) * 100;
  }

  Future<void> _showStudentSelector(Map<String, dynamic> sharedLink) async {
    // Load students for this class/group
    var builder = _client.from('Students').select('id, Student_Name, Student_Code');
    
    if (sharedLink['Class_id'] != null) {
      builder = builder.eq('Class_id', sharedLink['Class_id']);
    }
    if (sharedLink['Group_id'] != null) {
      builder = builder.eq('Group_id', sharedLink['Group_id']);
    }
    
    final studentsRes = await builder.order('Student_Name').limit(500);
    
    if (studentsRes is! List || studentsRes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد طلاب')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    final students = List<Map<String, dynamic>>.from(studentsRes);

    if (!mounted) return;

    // Show dialog to select student
    final selectedStudent = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر اسمك'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text('${student['Student_Name']} (${student['Student_Code'] ?? ''})'),
                onTap: () => Navigator.pop(context, student),
              );
            },
          ),
        ),
      ),
    );

    if (selectedStudent == null) {
      setState(() => _loading = false);
      return;
    }

    // Load or create submission for this student
    await _loadStudentSubmission(selectedStudent, sharedLink);
  }

  Future<void> _loadStudentSubmission(
    Map<String, dynamic> student,
    Map<String, dynamic> sharedLink,
  ) async {
    try {
      final weekStartStr = sharedLink['week_start_date'];
      
      // Check if submission already exists
      var existingSubmission = await _client
          .from('Weekly_Werd')
          .select('*')
          .eq('Student_id', student['id'])
          .eq('week_start_date', weekStartStr)
          .maybeSingle();

      // If doesn't exist, create it
      if (existingSubmission == null) {
        await _client.from('Weekly_Werd').insert({
          'Student_id': student['id'],
          'Class_id': sharedLink['Class_id'],
          'Group_id': sharedLink['Group_id'],
          'Type_id': sharedLink['Type_id'],
          'week_start_date': sharedLink['week_start_date'],
          'week_end_date': sharedLink['week_end_date'],
          'submission_token': widget.submissionToken,
          'checklist_responses': [],
        });

        existingSubmission = await _client
            .from('Weekly_Werd')
            .select('*')
            .eq('Student_id', student['id'])
            .eq('week_start_date', weekStartStr)
            .single();
      }

      // Load template
      final templateRes = await _client
          .from('Weekly_Checklist_Template')
          .select('*')
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (templateRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد نموذج فعّال')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final checklistItems = templateRes['checklist_items'] as List;
      final existingResponses = existingSubmission['checklist_responses'] as List;

      setState(() {
        _submission = existingSubmission;
        _student = student;
        _questions = List<Map<String, dynamic>>.from(checklistItems);
        
        // Load existing responses
        for (var response in existingResponses) {
          final itemId = response['item_id'];
          _responses[itemId] = response['status'];
          if (response['comment'] != null) {
            _comments[itemId] = response['comment'];
          }
        }
        
        _submitted = existingResponses.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading student submission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitResponses() async {
    // Validate: check all mandatory questions are answered
    for (var question in _questions) {
      if (question['is_mandatory'] == true) {
        if (!_responses.containsKey(question['id'])) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى الإجابة على جميع الأسئلة المطلوبة')),
          );
          return;
        }
      }
    }

    setState(() => _submitting = true);

    try {
      // Prepare responses
      final responsesData = _questions.map((q) {
        final itemId = q['id'];
        return {
          'item_id': itemId,
          'question': q['question'],
          'status': _responses[itemId] ?? 'not_done',
          'comment': _comments[itemId],
        };
      }).toList();

      // Update submission
      await _client
          .from('Weekly_Werd')
          .update({
            'checklist_responses': responsesData,
            'submitted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _submission!['id']);

      setState(() {
        _submitted = true;
        _submitting = false;
      });

      // Play success animation
      _successAnimationController.forward();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحفظ بنجاح! شكراً لك'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استبيان الورد الأسبوعي'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _submission == null
                ? _buildErrorView()
                : _submitted
                    ? _buildSubmittedView()
                    : _buildFormView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'رابط غير صحيح',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'يرجى التحقق من الرابط والمحاولة مرة أخرى',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green[400],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'تم الإرسال بنجاح!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'شكراً ${_student?['Student_Name'] ?? ''} (${_student?['Student_Code'] ?? ''})',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'تم حفظ إجاباتك في ${DateTime.now().toString().split(' ')[0]}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            label: const Text('العودة للرئيسية'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      children: [
        // Header with student info and progress
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Text(
                  'مرحباً ${_student?['Student_Name'] ?? ''} (${_student?['Student_Code'] ?? ''}),',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الأسبوع: ${_submission?['week_start_date']} - ${_submission?['week_end_date']}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                // Progress Circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: _progressPercentage / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${_progressPercentage.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_completedCount من $_totalCount',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Questions List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              final itemId = question['id'];
              final isMandatory = question['is_mandatory'] ?? true;
              final currentStatus = _responses[itemId];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: currentStatus == 'completed'
                                  ? Colors.green[100]
                                  : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: currentStatus == 'completed'
                                      ? Colors.green[700]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question['question'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isMandatory)
                                  Text(
                                    '* مطلوب',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[400],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Status Options
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusButton(
                              itemId: itemId,
                              status: 'completed',
                              label: 'مكتمل',
                              icon: Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusButton(
                              itemId: itemId,
                              status: 'partially',
                              label: 'جزئياً',
                              icon: Icons.pending,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusButton(
                              itemId: itemId,
                              status: 'not_done',
                              label: 'لم يتم',
                              icon: Icons.cancel,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Comment Field
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'ملاحظة (اختياري)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        maxLines: 2,
                        onChanged: (value) {
                          _comments[itemId] = value;
                        },
                        controller: TextEditingController(
                          text: _comments[itemId] ?? '',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Submit Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitResponses,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'إرسال الإجابات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton({
    required String itemId,
    required String status,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _responses[itemId] == status;

    return InkWell(
      onTap: () {
        setState(() {
          _responses[itemId] = status;
        });
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[400],
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
