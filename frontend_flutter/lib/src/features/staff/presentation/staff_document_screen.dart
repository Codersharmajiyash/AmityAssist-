import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/staff_provider.dart';

class StaffDocumentScreen extends ConsumerWidget {
  const StaffDocumentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(adminDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Document Audit')),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (docs) {
          if (docs.isEmpty) {
            return const Center(child: Text('No documents require auditing.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Student ID: ${d['student_id']} - ${d['document_type']}'),
                  subtitle: Text('Status: ${d['status']}'),
                  trailing: d['status'] == 'PENDING'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () {
                                ref.read(staffActionsProvider).verifyDocument(d['id'], 'VERIFIED', 'Looks good');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.flag, color: Colors.orange),
                              onPressed: () {
                                _showFlagDialog(context, ref, d['id']);
                              },
                            ),
                          ],
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

  void _showFlagDialog(BuildContext context, WidgetRef ref, int id) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flag Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason for flagging'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(staffActionsProvider).verifyDocument(id, 'FLAGGED', controller.text);
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Flag Document'),
          ),
        ],
      ),
    );
  }
}
