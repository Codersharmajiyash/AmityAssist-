import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/api_client.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../auth/application/auth_provider.dart';

/// Fetch grievance history for the student.
final grievanceHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final studentId = ref.watch(authProvider).studentId;
  final cache = ref.watch(offlineCacheProvider);

  if (studentId == null) return [];

  try {
    final response = await dio.get('/student/grievances', queryParameters: {
      'student_id': studentId,
    });

    final data = (response.data as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await cache.put('grievances_$studentId', response.data);
    return data;
  } catch (e) {
    final cached = cache.get('grievances_$studentId');
    if (cached != null) {
      return (cached as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
});

class GrievanceScreen extends ConsumerStatefulWidget {
  const GrievanceScreen({super.key});

  @override
  ConsumerState<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends ConsumerState<GrievanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _descController = TextEditingController();
  String _category = 'academic';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitGrievance() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your issue.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final dio = ref.read(apiClientProvider);
    final studentId = ref.read(authProvider).studentId;

    try {
      if (studentId != null) {
        await dio.post('/student/grievances', data: {
          'student_id': studentId,
          'category': _category,
          'description': _descController.text,
        });
      }

      if (mounted) {
        _descController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grievance filed successfully!')),
        );
        ref.invalidate(grievanceHistoryProvider);
        _tabController.animateTo(1); // Switch to history tab
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.response?.data?['detail'] ?? e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grievance Desk'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'File New'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFileTab(context),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildFileTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Color(0xFF7B1FA2), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Text('File a New Grievance', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'academic', child: Text('Academic Issue')),
                  DropdownMenuItem(value: 'fee', child: Text('Fee & Finance')),
                  DropdownMenuItem(value: 'hostel', child: Text('Hostel & Accommodation')),
                  DropdownMenuItem(value: 'exam', child: Text('Examination')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
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
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 80),
                    child: Icon(Icons.edit_note_rounded),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitGrievance,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Grievance'),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildHistoryTab() {
    final historyAsync = ref.watch(grievanceHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (grievances) {
        if (grievances.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No grievances filed yet', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(grievanceHistoryProvider),
          child: ListView.builder(
            itemCount: grievances.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final g = grievances[index];
              return _GrievanceHistoryTile(grievance: g)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms);
            },
          ),
        );
      },
    );
  }
}

class _GrievanceHistoryTile extends StatelessWidget {
  const _GrievanceHistoryTile({required this.grievance});
  final Map<String, dynamic> grievance;

  @override
  Widget build(BuildContext context) {
    final status = grievance['status'] ?? 'UNKNOWN';
    final category = grievance['category'] ?? '';
    final description = grievance['description'] ?? '';
    final resolution = grievance['resolution'] ?? '';
    final date = grievance['created_at'] ?? grievance['date'] ?? '';

    final statusColor = switch (status.toUpperCase()) {
      'RESOLVED' => AppColors.successGreen,
      'IN_PROGRESS' => const Color(0xFFF9A825),
      'OPEN' => AppColors.amityBlue,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(category, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (date.isNotEmpty)
                  Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(fontSize: 15)),
            if (resolution.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.successGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resolution: $resolution',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // ── Visual timeline ──────────────────────
            const SizedBox(height: 16),
            _StatusTimeline(currentStatus: status),
          ],
        ),
      ),
    );
  }
}

/// Simple horizontal status timeline.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.currentStatus});
  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final statuses = ['OPEN', 'IN_PROGRESS', 'RESOLVED'];
    final currentIdx = statuses.indexWhere(
      (s) => s == currentStatus.toUpperCase(),
    );

    return Row(
      children: List.generate(statuses.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
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

        return Column(
          children: [
            Container(
              width: isCurrent ? 28 : 22,
              height: isCurrent ? 28 : 22,
              decoration: BoxDecoration(
                color: isActive ? AppColors.successGreen : Colors.grey.shade300,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: AppColors.successGreen, width: 3)
                    : null,
              ),
              child: isActive
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              statuses[stepIdx].replaceAll('_', '\n'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.successGreen : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }),
    );
  }
}
