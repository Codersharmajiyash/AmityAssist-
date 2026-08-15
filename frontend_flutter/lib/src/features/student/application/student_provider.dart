import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_provider.dart';

/// Models the student profile data
class StudentProfile {
  final String id;
  final String name;
  final String course;
  final double cgpa;
  final String feeStatus;

  StudentProfile({
    required this.id,
    required this.name,
    required this.course,
    required this.cgpa,
    required this.feeStatus,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      course: json['course'] ?? '',
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 0.0,
      feeStatus: json['fee_status'] ?? '',
    );
  }
}

final studentProfileProvider = FutureProvider<StudentProfile?>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final authState = ref.watch(authProvider);

  final studentId = authState.studentId;
  if (studentId == null) return null;

  try {
    final response = await dio.get('/student/profile', queryParameters: {
      'student_id': studentId,
    });
    
    if (response.statusCode == 200 && response.data != null) {
      return StudentProfile.fromJson(response.data);
    }
    return null;
  } catch (e) {
    // If running offline or disconnected, return a fallback mock
    return StudentProfile(
      id: studentId,
      name: 'Offline Student',
      course: 'Unknown Course',
      cgpa: 0.0,
      feeStatus: 'Unknown',
    );
  }
});
