import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../application/staff_provider.dart';

class StaffWithdrawalScreen extends ConsumerStatefulWidget {
  const StaffWithdrawalScreen({super.key});

  @override
  ConsumerState<StaffWithdrawalScreen> createState() => _StaffWithdrawalScreenState();
}

class _StaffWithdrawalScreenState extends ConsumerState<StaffWithdrawalScreen> {
  final Set<int> _selectedIds = {};
  String _filterStatus = 'PENDING';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(adminRequestsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Withdrawals Queue'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _buildTab('PENDING', 'Pending'),
                const SizedBox(width: 8),
                _buildTab('APPROVED', 'Approved'),
                const SizedBox(width: 8),
                _buildTab('REJECTED', 'Rejected'),
                const Spacer(),
                if (_selectedIds.isNotEmpty && _filterStatus == 'PENDING')
                  FilledButton.icon(
                    onPressed: () async {
                      await ref.read(staffActionsProvider).batchApproveRequests(_selectedIds.toList());
                      setState(() => _selectedIds.clear());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Batch approval successful')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text('Approve Selected (${_selectedIds.length})'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.successGreen),
                  ).animate().fadeIn().scale(),
              ],
            ),
          ),
        ),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (requests) {
          final filtered = requests
              .where((r) => r['status'].toString().toUpperCase() == _filterStatus)
              .toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No requests found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  )
                ],
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Student ID')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filtered.map((req) {
                  final id = req['id'] as int;
                  final isSelected = _selectedIds.contains(id);

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: _filterStatus == 'PENDING'
                        ? (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          }
                        : null,
                    cells: [
                      DataCell(Text('#$id')),
                      DataCell(
                        Text(
                          req['student_id'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataCell(Text(req['reason'])),
                      DataCell(Text(req['date'])),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(req['status']).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            req['status'],
                            style: TextStyle(
                              color: _getStatusColor(req['status']),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        _filterStatus == 'PENDING'
                            ? Row(
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      ref.read(staffActionsProvider).updateRequestStatus(id, 'approved');
                                    },
                                    child: const Text('Approve', style: TextStyle(color: AppColors.successGreen)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(staffActionsProvider).updateRequestStatus(id, 'rejected');
                                    },
                                    child: const Text('Reject', style: TextStyle(color: AppColors.urgentRed)),
                                  ),
                                ],
                              )
                            : const Text('--'),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ).animate().fadeIn().slideY(begin: 0.05),
          );
        },
      ),
    );
  }

  Widget _buildTab(String status, String label) {
    final isSelected = _filterStatus == status;
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected ? AppColors.amityBlue : Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onPressed: () {
        setState(() {
          _filterStatus = status;
          _selectedIds.clear();
        });
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return AppColors.successGreen;
      case 'REJECTED':
        return AppColors.urgentRed;
      default:
        return AppColors.amityYellow;
    }
  }
}
