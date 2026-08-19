import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/api_client.dart';

final academicsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final studentId = ref.watch(authProvider).studentId;
  if (studentId == null) throw Exception('Not logged in');
  
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/student/exams?student_id=$studentId');
  return response.data as List<dynamic>;
});

class AcademicsScreen extends ConsumerWidget {
  const AcademicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicsAsync = ref.watch(academicsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Academics')),
      body: academicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (exams) {
          if (exams.isEmpty) {
            return const Center(child: Text('No academic records found.'));
          }

          return ListView.builder(
            itemCount: exams.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final exam = exams[index];
              final hasFailed = exam['grade'] == 'F' || exam['grade'] == 'D';
              
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.school, size: 40),
                  title: Text(exam['course_name'] ?? 'Unknown Course'),
                  subtitle: Text('Exam Date: ${exam['exam_date'] ?? 'TBA'}\nGrade: ${exam['grade'] ?? 'Pending'}'),
                  isThreeLine: true,
                  trailing: hasFailed 
                      ? const Chip(
                          label: Text('Back Paper Eligible', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.orange,
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
