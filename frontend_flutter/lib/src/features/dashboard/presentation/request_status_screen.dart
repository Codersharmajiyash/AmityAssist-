import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../../../core/api_client.dart';

final requestStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final studentId = ref.watch(authProvider).studentId;
  if (studentId == null) throw Exception('Not logged in');
  
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/status/$studentId');
  return response.data as Map<String, dynamic>;
});

class RequestStatusScreen extends ConsumerWidget {
  const RequestStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(requestStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Status')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (data) {
          final bool hasRequest = data['has_request'] ?? false;
          if (!hasRequest) {
            return const Center(child: Text('No active withdrawal requests.'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Withdrawal Request', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text('Status: ${data['status']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('Reason: ${data['reason']}'),
                    if (data['reference_no'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Reference No: ${data['reference_no']}'),
                    ],
                    const SizedBox(height: 16),
                    if (data['status'] == 'APPROVED')
                      const Text('Your request has been approved. Further instructions have been sent to your email.', style: TextStyle(color: Colors.green)),
                    if (data['status'] == 'REJECTED')
                      const Text('Your request has been rejected. Please contact the administration for details.', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
