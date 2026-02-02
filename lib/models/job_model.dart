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
  final List<String> applicants;
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
    this.applicants = const [],
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
      applicants: List<String>.from(map['applicants'] ?? []),
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
      'applicants': applicants,
      'selectedApplicant': selectedApplicant,
      'deadline': Timestamp.fromDate(deadline),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
