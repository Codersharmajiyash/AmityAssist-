import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_provider.dart';

class GrievanceScreen extends ConsumerStatefulWidget {
  const GrievanceScreen({super.key});

  @override
  ConsumerState<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends ConsumerState<GrievanceScreen> {
  final _descController = TextEditingController();
  String _category = 'academic';
  bool _isSubmitting = false;

  Future<void> _submitGrievance() async {
    if (_descController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    final dio = ref.read(apiClientProvider);
    final studentId = ref.read(authProvider).studentId;

    try {
      if (studentId != null) {
        await dio.post('/student/grievance', data: {
          'student_id': studentId,
          'category': _category,
          'description': _descController.text,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grievance filed successfully!')),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.response?.data?['detail'] ?? e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grievance Desk')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File a New Grievance', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'academic', child: Text('Academic Issue')),
                    DropdownMenuItem(value: 'fee', child: Text('Fee & Finance')),
                    DropdownMenuItem(value: 'hostel', child: Text('Hostel & Accommodation')),
                    DropdownMenuItem(value: 'exam', child: Text('Examination')),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Describe your issue in detail',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submitGrievance,
                    child: _isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit Grievance'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

