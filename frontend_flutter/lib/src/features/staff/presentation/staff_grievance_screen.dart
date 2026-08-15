import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/staff_provider.dart';

class StaffGrievanceScreen extends ConsumerWidget {
  const StaffGrievanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grievancesAsync = ref.watch(adminGrievancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grievance Desk')),
      body: grievancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (grievances) {
          if (grievances.isEmpty) {
            return const Center(child: Text('No active grievances.'));
          }
          return ListView.builder(
            itemCount: grievances.length,
            itemBuilder: (context, index) {
              final g = grievances[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Student ID: ${g['student_id']} - ${g['category']}'),
                  subtitle: Text('Status: ${g['status']}\nDetails: ${g['description']}'),
                  trailing: g['status'] == 'OPEN' || g['status'] == 'IN_PROGRESS'
                      ? ElevatedButton(
                          onPressed: () {
                            _showResolveDialog(context, ref, g['id']);
                          },
                          child: const Text('Resolve'),
                        )
                      : const Text('RESOLVED', style: TextStyle(color: Colors.green)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showResolveDialog(BuildContext context, WidgetRef ref, int id) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Grievance'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Resolution notes'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(staffActionsProvider).resolveGrievance(id, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Submit Resolution'),
          ),
        ],
      ),
    );
  }
}
