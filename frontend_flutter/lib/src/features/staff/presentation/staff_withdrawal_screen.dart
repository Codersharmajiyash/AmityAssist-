import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/staff_provider.dart';

class StaffWithdrawalScreen extends ConsumerWidget {
  const StaffWithdrawalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(adminRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal Queue')),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No withdrawal requests.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Student ID: ${req['student_id']} - ${req['type']}'),
                  subtitle: Text('Status: ${req['status']}\nReason: ${req['reason']}'),
                  trailing: req['status'] == 'PENDING_APPROVAL'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () {
                                ref.read(staffActionsProvider).updateRequestStatus(req['id'], 'APPROVED');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                ref.read(staffActionsProvider).updateRequestStatus(req['id'], 'REJECTED');
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
}
