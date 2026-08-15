import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/api_client.dart';

final studentDocumentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final studentId = ref.watch(authProvider).studentId;
  if (studentId == null) throw Exception('Not logged in');
  
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/documents/list/$studentId');
  return response.data as List<dynamic>;
});

class DocumentCenterScreen extends ConsumerWidget {
  const DocumentCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(studentDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Document Center')),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (docs) {
          if (docs.isEmpty) {
            return const Center(child: Text('You have not uploaded any documents.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.file_present, size: 40),
                  title: Text(doc['document_type'] ?? 'Unknown Document'),
                  subtitle: Text('Status: ${doc['status']}'),
                  trailing: _buildStatusIcon(doc['status']),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'VERIFIED':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'FLAGGED':
        return const Icon(Icons.warning, color: Colors.orange);
      default:
        return const Icon(Icons.hourglass_empty, color: Colors.grey);
    }
  }
}
