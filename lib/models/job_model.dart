import 'package:cloud_firestore/cloud_firestore.dart';

class JobModel {
  final String id;
  final String companyId;
  final String title;
  final String description;
  final List<String> requiredSkills;
  final String location;
  final double? budgetMin;
  final double? budgetMax;
  final String jobType; // full-time, part-time, contract, freelance
  final String status; // open, in_progress, completed, cancelled
  // ── Shift / schedule fields (used for conflict detection) ─────────────────
  /// One of: 'morning'(06-12), 'afternoon'(12-18), 'evening'(18-22),
  /// 'night'(22-06), 'flexible'(any time), 'custom'(use shiftStart/shiftEnd).
  final String? shiftType;
  final String? shiftStart; // 'HH:mm', only relevant when shiftType == 'custom'
  final String? shiftEnd;   // 'HH:mm', only relevant when shiftType == 'custom'
  final List<String> workDays; // e.g. ['mon','tue','wed','thu','fri']; empty = all
  final List<String> applicants;
  final Map<String, String>
      applicationStatus; // applicantId -> pending/accepted/rejected
  final String? selectedApplicant;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobModel({
    required this.id,
    required this.companyId,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.location,
    this.budgetMin,
    this.budgetMax,
    required this.jobType,
    this.status = 'open',
    this.shiftType,
    this.shiftStart,
    this.shiftEnd,
    this.workDays = const [],
    this.applicants = const [],
    this.applicationStatus = const {},
    this.selectedApplicant,
    required this.deadline,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobModel.fromMap(Map<String, dynamic> map, String id) {
    return JobModel(
      id: id,
      companyId: map['companyId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
      location: map['location'] ?? '',
      budgetMin: map['budgetMin']?.toDouble(),
      budgetMax: map['budgetMax']?.toDouble(),
      jobType: map['jobType'] ?? 'freelance',
      status: map['status'] ?? 'open',
      shiftType: map['shiftType'],
      shiftStart: map['shiftStart'],
      shiftEnd: map['shiftEnd'],
      workDays: List<String>.from(map['workDays'] ?? []),
      applicants: List<String>.from(map['applicants'] ?? []),
      applicationStatus: (map['applicationStatus'] as Map<String, dynamic>? ??
              {})
          .map((key, value) => MapEntry(key, value?.toString() ?? 'pending')),
      selectedApplicant: map['selectedApplicant'],
      deadline: (map['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'title': title,
      'description': description,
      'requiredSkills': requiredSkills,
      'location': location,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'jobType': jobType,
      'status': status,
      if (shiftType != null) 'shiftType': shiftType,
      if (shiftStart != null) 'shiftStart': shiftStart,
      if (shiftEnd != null) 'shiftEnd': shiftEnd,
      'workDays': workDays,
      'applicants': applicants,
      'applicationStatus': applicationStatus,
      'selectedApplicant': selectedApplicant,
      'deadline': Timestamp.fromDate(deadline),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns shift window as (startMinutes, endMinutes) for overlap checks.
  /// Returns null for 'flexible' or unset shifts.
  (int, int)? get shiftMinutes {
    int toMins(int h, int m) => h * 60 + m;
    switch (shiftType) {
      case 'morning':   return (toMins(6, 0),  toMins(12, 0));
      case 'afternoon': return (toMins(12, 0), toMins(18, 0));
      case 'evening':   return (toMins(18, 0), toMins(22, 0));
      case 'night':     return (toMins(22, 0), toMins(30, 0)); // 30h = 06:00+1
      case 'custom':
        if (shiftStart != null && shiftEnd != null) {
          final s = shiftStart!.split(':');
          final e = shiftEnd!.split(':');
          return (
            toMins(int.parse(s[0]), int.parse(s[1])),
            toMins(int.parse(e[0]), int.parse(e[1])),
          );
        }
        return null;
      default: return null; // flexible — no fixed window
    }
  }

  String get shiftLabel {
    switch (shiftType) {
      case 'morning':   return 'Morning (6 AM – 12 PM)';
      case 'afternoon': return 'Afternoon (12 PM – 6 PM)';
      case 'evening':   return 'Evening (6 PM – 10 PM)';
      case 'night':     return 'Night (10 PM – 6 AM)';
      case 'custom':
        if (shiftStart != null && shiftEnd != null) {
          return 'Custom ($shiftStart – $shiftEnd)';
        }
        return 'Custom';
      default: return 'Flexible';
    }
  }
}
