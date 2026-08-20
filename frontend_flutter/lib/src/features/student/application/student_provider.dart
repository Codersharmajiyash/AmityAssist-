import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../auth/application/auth_provider.dart';

/// Models the student profile data.
class StudentProfile {
  final String id;
  final String name;
  final String course;
  final double cgpa;
  final int attendance;
  final String feeStatus;
  final String branch;
  final int semester;
  final String hostelStatus;

  StudentProfile({
    required this.id,
    required this.name,
    required this.course,
    required this.cgpa,
    required this.attendance,
    required this.feeStatus,
    this.branch = '',
    this.semester = 1,
    this.hostelStatus = 'N/A',
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      course: json['course'] ?? '',
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 0.0,
      attendance: (json['attendance'] as num?)?.toInt() ?? 0,
      feeStatus: json['fee_status'] ?? 'Unknown',
      branch: json['branch'] ?? '',
      semester: (json['semester'] as num?)?.toInt() ?? 1,
      hostelStatus: json['hostel_status'] ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'course': course,
        'cgpa': cgpa,
        'attendance': attendance,
        'fee_status': feeStatus,
        'branch': branch,
        'semester': semester,
        'hostel_status': hostelStatus,
      };
}

final studentProfileProvider = FutureProvider<StudentProfile?>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final authState = ref.watch(authProvider);
  final cache = ref.watch(offlineCacheProvider);

  final studentId = authState.studentId;
  if (studentId == null) return null;

  try {
    final response = await dio.get('/student/profile', queryParameters: {
      'student_id': studentId,
    });

    if (response.statusCode == 200 && response.data != null) {
      final profile = StudentProfile.fromJson(response.data);
      // Cache for offline use
      await cache.put('profile_$studentId', response.data);
      return profile;
    }
    return null;
  } catch (e) {
    // Serve from offline cache if available
    final cached = cache.get('profile_$studentId');
    if (cached != null) {
      return StudentProfile.fromJson(Map<String, dynamic>.from(cached));
    }
    // Final fallback — minimal offline stub
    return StudentProfile(
      id: studentId,
      name: 'Offline Student',
      course: 'Unknown Course',
      cgpa: 0.0,
      attendance: 0,
      feeStatus: 'Unknown',
    );
  }
});
