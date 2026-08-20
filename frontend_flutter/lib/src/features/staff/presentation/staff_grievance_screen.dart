import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../application/staff_provider.dart';

class StaffGrievanceScreen extends ConsumerStatefulWidget {
  const StaffGrievanceScreen({super.key});

  @override
  ConsumerState<StaffGrievanceScreen> createState() => _StaffGrievanceScreenState();
}

class _StaffGrievanceScreenState extends ConsumerState<StaffGrievanceScreen> {
  String _filterCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final grievancesAsync = ref.watch(adminGrievancesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Grievance Desk'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('All'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Academics'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Hostel'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Finance'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Infrastructure'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: grievancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (grievances) {
          final filtered = grievances.where((g) {
            if (_filterCategory == 'All') return true;
            return g['category'].toString().toLowerCase() == _filterCategory.toLowerCase();
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No grievances found in this category.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: filtered.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final grievance = filtered[index];
              return _GrievanceCard(grievance: grievance)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * index))
                  .slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _filterCategory == category;
    return ChoiceChip(
      label: Text(category),
      selected: isSelected,
      selectedColor: AppColors.amityBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterCategory = category);
        }
      },
    );
  }
}

class _GrievanceCard extends ConsumerWidget {
  final Map<String, dynamic> grievance;

  const _GrievanceCard({required this.grievance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priority = grievance['priority'] ?? 'LOW';
    final isHigh = priority == 'HIGH';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${grievance['category']}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHigh ? AppColors.urgentRed.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$priority PRIORITY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isHigh ? AppColors.urgentRed : Colors.orange.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${grievance['date']}',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              grievance['subject'],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Filed by: ${grievance['student_id']}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (grievance['status'] != 'RESOLVED') ...[
                  OutlinedButton.icon(
                    onPressed: () => _showResolveDialog(context, ref, grievance['id']),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Resolve'),
                  ),
                ] else ...[
                  const Text('Resolved', style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showResolveDialog(BuildContext context, WidgetRef ref, int id) {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolve Grievance', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Quick Replies:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickReplyChip('Forwarded to HOD', textController),
                _QuickReplyChip('Issue resolved locally', textController),
                _QuickReplyChip('Requires student meeting', textController),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Resolution Notes',
                hintText: 'Enter detailed resolution...',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () {
                  if (textController.text.trim().isEmpty) return;
                  ref.read(staffActionsProvider).resolveGrievance(id, textController.text);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grievance resolved!')));
                },
                child: const Text('Submit Resolution'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String text;
  final TextEditingController controller;

  const _QuickReplyChip(this.text, this.controller);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text),
      backgroundColor: Colors.grey.shade100,
      onPressed: () {
        controller.text = text;
      },
    );
  }
}
