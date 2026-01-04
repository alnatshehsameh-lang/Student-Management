class WeeklyWerdSubmission {
  final int? id;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int studentId;
  final int? classId;
  final int? groupId;
  final int? typeId;
  final List<ChecklistResponse> responses;
  final DateTime? submittedAt;
  final String? submissionToken;

  WeeklyWerdSubmission({
    this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.studentId,
    this.classId,
    this.groupId,
    this.typeId,
    required this.responses,
    this.submittedAt,
    this.submissionToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'week_start_date': weekStartDate.toIso8601String().split('T')[0],
      'week_end_date': weekEndDate.toIso8601String().split('T')[0],
      'Student_id': studentId,
      'Class_id': classId,
      'Group_id': groupId,
      'Type_id': typeId,
      'checklist_responses': responses.map((r) => r.toJson()).toList(),
      'submission_token': submissionToken,
    };
  }

  factory WeeklyWerdSubmission.fromJson(Map<String, dynamic> json) {
    return WeeklyWerdSubmission(
      id: json['id'],
      weekStartDate: DateTime.parse(json['week_start_date']),
      weekEndDate: DateTime.parse(json['week_end_date']),
      studentId: json['Student_id'],
      classId: json['Class_id'],
      groupId: json['Group_id'],
      typeId: json['Type_id'],
      responses: (json['checklist_responses'] as List)
          .map((r) => ChecklistResponse.fromJson(r))
          .toList(),
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at']) 
          : null,
      submissionToken: json['submission_token'],
    );
  }
}

class ChecklistResponse {
  final String itemId;
  final String question;
  final String status; // 'completed', 'partially', 'not_done'
  final String? comment;

  ChecklistResponse({
    required this.itemId,
    required this.question,
    required this.status,
    this.comment,
  });

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'question': question,
      'status': status,
      'comment': comment,
    };
  }

  factory ChecklistResponse.fromJson(Map<String, dynamic> json) {
    return ChecklistResponse(
      itemId: json['item_id'],
      question: json['question'],
      status: json['status'],
      comment: json['comment'],
    );
  }
}

class ChecklistTemplate {
  final int? id;
  final String title;
  final String? description;
  final List<ChecklistItem> items;
  final bool isActive;

  ChecklistTemplate({
    this.id,
    required this.title,
    this.description,
    required this.items,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'checklist_items': items.map((i) => i.toJson()).toList(),
      'is_active': isActive,
    };
  }

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplate(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      items: (json['checklist_items'] as List)
          .map((i) => ChecklistItem.fromJson(i))
          .toList(),
      isActive: json['is_active'] ?? true,
    );
  }
}

class ChecklistItem {
  final String id;
  final String question;
  final bool isMandatory;

  ChecklistItem({
    required this.id,
    required this.question,
    this.isMandatory = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'is_mandatory': isMandatory,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      question: json['question'],
      isMandatory: json['is_mandatory'] ?? true,
    );
  }
}
