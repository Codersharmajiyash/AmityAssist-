import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../auth/application/auth_provider.dart';

/// Fetch all active workflows for the student.
final workflowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final studentId = ref.watch(authProvider).studentId;
  if (studentId == null) return [];

  final dio = ref.watch(apiClientProvider);
  try {
    final response = await dio.get('/workflows', queryParameters: {
      'student_id': studentId,
    });
    return (response.data as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (e) {
    // Fallback: try the old status endpoint
    try {
      final response = await dio.get('/status/$studentId');
      final data = response.data as Map<String, dynamic>;
      if (data['has_request'] == true) {
        return [data];
      }
    } catch (_) {}
    return [];
  }
});

class RequestStatusScreen extends ConsumerWidget {
  const RequestStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowsAsync = ref.watch(workflowsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Status')),
      body: workflowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (workflows) {
          if (workflows.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No active requests', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Your withdrawal, grievance, and scholarship\nworkflows will appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workflowsProvider),
            child: ListView.builder(
              itemCount: workflows.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final wf = workflows[index];
                return _WorkflowCard(workflow: wf)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 80 * index),
                      duration: 350.ms,
                    )
                    .slideY(begin: 0.08);
              },
            ),
          );
        },
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.workflow});
  final Map<String, dynamic> workflow;

  @override
  Widget build(BuildContext context) {
    final type = (workflow['procedure_type'] ?? workflow['type'] ?? 'request')
        .toString()
        .toUpperCase();
    final status = workflow['status'] ?? 'UNKNOWN';
    final refNo = workflow['workflow_id'] ?? workflow['reference_no'] ?? '';
    final department = workflow['current_department'] ?? '';
    final reason = workflow['reason'] ?? '';
    final checklist = workflow['checklist'] as List? ?? [];
    final statusFlow = workflow['status_flow'] as List? ?? [];

    final typeColor = switch (type) {
      'WITHDRAWAL' => AppColors.urgentRed,
      'GRIEVANCE' => const Color(0xFF7B1FA2),
      'SCHOLARSHIP' => const Color(0xFFF9A825),
      _ => AppColors.amityBlue,
    };

    final typeIcon = switch (type) {
      'WITHDRAWAL' => Icons.exit_to_app_rounded,
      'GRIEVANCE' => Icons.gavel_rounded,
      'SCHOLARSHIP' => Icons.workspace_premium_rounded,
      _ => Icons.track_changes_rounded,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$type Workflow',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      if (refNo.toString().isNotEmpty)
                        Text(
                          'Ref: $refNo',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                    ),
                  ),
                ),
              ],
            ),

            if (department.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.business_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Current: $department',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],

            if (reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: $reason',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],

            // Status flow timeline
            if (statusFlow.isNotEmpty) ...[
              const Divider(height: 24),
              _WorkflowTimeline(statusFlow: statusFlow, currentStatus: status),
            ],

            // Checklist
            if (checklist.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...checklist.map((item) {
                final itemMap = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                final name = itemMap['name'] ?? itemMap['item'] ?? 'Item';
                final completed = itemMap['completed'] ?? false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20,
                        color: completed ? AppColors.successGreen : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            decoration: completed ? TextDecoration.lineThrough : null,
                            color: completed ? Colors.grey : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkflowTimeline extends StatelessWidget {
  const _WorkflowTimeline({required this.statusFlow, required this.currentStatus});
  final List statusFlow;
  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final currentIdx = statusFlow.indexWhere(
      (s) => s.toString().toLowerCase() == currentStatus.toLowerCase(),
    );

    return SizedBox(
      height: 64,
      child: Row(
        children: List.generate(statusFlow.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final isActive = stepIdx < currentIdx;
            return Expanded(
              child: Container(
                height: 3,
                color: isActive ? AppColors.successGreen : Colors.grey.shade300,
              ),
            );
          }

          final stepIdx = i ~/ 2;
          final isActive = stepIdx <= currentIdx;
          final isCurrent = stepIdx == currentIdx;
          final label = statusFlow[stepIdx]
              .toString()
              .replaceAll('_', '\n')
              .toUpperCase();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isCurrent ? 26 : 20,
                height: isCurrent ? 26 : 20,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.successGreen : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border:
                      isCurrent ? Border.all(color: AppColors.successGreen, width: 3) : null,
                ),
                child:
                    isActive ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? AppColors.successGreen : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
