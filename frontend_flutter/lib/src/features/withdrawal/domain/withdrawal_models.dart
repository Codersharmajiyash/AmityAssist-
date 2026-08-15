class WithdrawalGuide {
  const WithdrawalGuide({
    required this.title,
    required this.summary,
    required this.principle,
    required this.steps,
    required this.documents,
    required this.forms,
    required this.officialTimeline,
  });

  factory WithdrawalGuide.fromJson(Map<String, dynamic> json) {
    return WithdrawalGuide(
      title: json['title'] as String? ?? 'Withdrawal Intelligence System',
      summary: json['summary'] as String? ?? '',
      principle: json['principle'] as String? ?? '',
      steps: (json['steps'] as List? ?? [])
          .map((item) => WithdrawalStep.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      documents: (json['documents'] as List? ?? [])
          .map((item) => WithdrawalDocument.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      forms: (json['forms'] as List? ?? [])
          .map((item) => WithdrawalForm.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      officialTimeline: (json['official_timeline'] as List? ?? [])
          .map((item) => TimelineBand.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  final String title;
  final String summary;
  final String principle;
  final List<WithdrawalStep> steps;
  final List<WithdrawalDocument> documents;
  final List<WithdrawalForm> forms;
  final List<TimelineBand> officialTimeline;
}

class WithdrawalStep {
  const WithdrawalStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.department,
    required this.timelineText,
  });

  factory WithdrawalStep.fromJson(Map<String, dynamic> json) {
    return WithdrawalStep(
      stepNumber: json['step_number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      department: json['department'] as String? ?? '',
      timelineText: json['timeline_text'] as String? ?? '',
    );
  }

  final int stepNumber;
  final String title;
  final String description;
  final String department;
  final String timelineText;
}

class WithdrawalDocument {
  const WithdrawalDocument({
    required this.name,
    required this.description,
    required this.mandatory,
  });

  factory WithdrawalDocument.fromJson(Map<String, dynamic> json) {
    return WithdrawalDocument(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }

  final String name;
  final String description;
  final bool mandatory;
}

class WithdrawalForm {
  const WithdrawalForm({
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.issuingDepartment,
  });

  factory WithdrawalForm.fromJson(Map<String, dynamic> json) {
    return WithdrawalForm(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      issuingDepartment: json['issuing_department'] as String? ?? '',
    );
  }

  final String name;
  final String description;
  final String downloadUrl;
  final String issuingDepartment;
}

class TimelineBand {
  const TimelineBand({required this.stage, required this.timeline});

  factory TimelineBand.fromJson(Map<String, dynamic> json) {
    return TimelineBand(
      stage: json['stage'] as String? ?? '',
      timeline: json['timeline'] as String? ?? '',
    );
  }

  final String stage;
  final String timeline;
}
