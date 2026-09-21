import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';

/// Phase 30: Staff Interactive Procedure Setup Wizard.
/// Allows administrators and department officers to design, configure,
/// and deploy custom student workflows, approval chains, SLA targets,
/// and document verification checklists.
class StaffProcedureWizardScreen extends ConsumerStatefulWidget {
  const StaffProcedureWizardScreen({super.key});

  @override
  ConsumerState<StaffProcedureWizardScreen> createState() =>
      _StaffProcedureWizardScreenState();
}

class _StaffProcedureWizardScreenState
    extends ConsumerState<StaffProcedureWizardScreen> {
  bool _isLoading = true;
  List<dynamic> _procedures = [];
  String _selectedCategoryFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchProcedures();
  }

  Future<void> _fetchProcedures() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/procedures');
      if (mounted) {
        setState(() {
          if (res.data is Map<String, dynamic>) {
            _procedures =
                (res.data as Map<String, dynamic>)['procedures'] as List? ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredProcedures {
    if (_selectedCategoryFilter == 'ALL') return _procedures;
    return _procedures.where((p) {
      final cat = (p['category'] ?? '').toString().toUpperCase();
      return cat == _selectedCategoryFilter;
    }).toList();
  }

  void _openCreateWizardModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProcedureSetupWizardSheet(
        onCreated: () {
          _fetchProcedures();
        },
      ),
    );
  }

  void _showProcedureDetailsDialog(Map<String, dynamic> proc) {
    final steps = proc['steps'] as List? ?? [];
    final docs = proc['required_docs'] as List? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_tree_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proc['title'] ?? 'Procedure Details',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    '${proc['department']} • SLA: ${proc['sla_days']} Days',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((proc['description'] ?? '').toString().isNotEmpty) ...[
                  Text(
                    proc['description'],
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.ink, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                ],

                // Required Documents
                const Text(
                  'REQUIRED DOCUMENTS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                if (docs.isEmpty)
                  const Text('No mandatory documents required.',
                      style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: docs.map<Widget>((d) {
                      return Chip(
                        avatar: const Icon(Icons.description_outlined,
                            size: 16, color: AppColors.teal),
                        label: Text(d.toString(),
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.tealSoft,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 20),
                const Text(
                  'SEQUENTIAL APPROVAL STEPS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.muted),
                ),
                const SizedBox(height: 12),

                if (steps.isEmpty)
                  const Text('No steps configured for this procedure.',
                      style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.muted))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: steps.length,
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Container(
                        width: 2,
                        height: 16,
                        color: AppColors.line,
                      ),
                    ),
                    itemBuilder: (ctx, idx) {
                      final s = steps[idx] as Map<String, dynamic>;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['title'] ?? 'Step ${idx + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.apartment_rounded,
                                        size: 13, color: AppColors.muted),
                                    const SizedBox(width: 4),
                                    Text(
                                      s['responsible_desk'] ?? 'Desk',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.timer_outlined,
                                        size: 13, color: AppColors.muted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${s['sla_days']} days SLA',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted),
                                    ),
                                  ],
                                ),
                                if ((s['description'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    s['description'],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'ALL',
      'ACADEMIC',
      'EXAMINATION',
      'ACCOMMODATION',
      'ACADEMIC_RECORDS',
      'FINANCE',
      'CAMPUS_SERVICES',
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Procedure Setup Wizard & Directory'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF163B63), Color(0xFF1E8A7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Procedures',
            onPressed: _fetchProcedures,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateWizardModal,
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text(
          'New Procedure Wizard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategoryFilter == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.replaceAll('_', ' ')),
                      selected: isSelected,
                      selectedColor: AppColors.primarySoft,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.muted,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCategoryFilter = cat);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProcedures.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined,
                                size: 64, color: AppColors.muted),
                            const SizedBox(height: 16),
                            const Text(
                              'No custom procedures found',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap the button below to launch the Interactive Wizard',
                              style: TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _openCreateWizardModal,
                              icon: const Icon(Icons.add),
                              label: const Text('Launch Procedure Wizard'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProcedures.length,
                        itemBuilder: (ctx, index) {
                          final proc = _filteredProcedures[index]
                              as Map<String, dynamic>;
                          final steps = proc['steps'] as List? ?? [];
                          final docs = proc['required_docs'] as List? ?? [];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.line),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showProcedureDetailsDialog(proc),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.assignment_outlined,
                                            color: AppColors.primary,
                                            size: 26,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                proc['title'] ?? 'Untitled',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${proc['department']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.goldSoft,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.timer_outlined,
                                                  size: 13,
                                                  color: AppColors.gold),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${proc['sla_days']}d SLA',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF8A5B00),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if ((proc['description'] ?? '')
                                        .toString()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        proc['description'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _BadgeChip(
                                          icon: Icons.checklist_rounded,
                                          label: '${steps.length} Steps',
                                          color: AppColors.teal,
                                          bg: AppColors.tealSoft,
                                        ),
                                        _BadgeChip(
                                          icon: Icons.attach_file_rounded,
                                          label: '${docs.length} Documents',
                                          color: AppColors.primary,
                                          bg: AppColors.primarySoft,
                                        ),
                                        _BadgeChip(
                                          icon: Icons.category_rounded,
                                          label: '${proc['category']}',
                                          color: AppColors.muted,
                                          bg: AppColors.surface,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-Stage Interactive Wizard Sheet
class _ProcedureSetupWizardSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _ProcedureSetupWizardSheet({required this.onCreated});

  @override
  ConsumerState<_ProcedureSetupWizardSheet> createState() =>
      _ProcedureSetupWizardSheetState();
}

class _ProcedureSetupWizardSheetState
    extends ConsumerState<_ProcedureSetupWizardSheet> {
  int _currentStage = 0; // 0: Basic Info, 1: Steps, 2: Documents, 3: Review
  bool _isSubmitting = false;

  // Form controllers - Stage 1
  final _titleController = TextEditingController();
  final _departmentController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'ACADEMIC';
  int _slaDays = 7;

  // Stage 2 - Steps
  final List<Map<String, dynamic>> _steps = [];

  // Stage 3 - Documents
  final List<String> _requiredDocs = [];
  final _docInputController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _departmentController.dispose();
    _descController.dispose();
    _docInputController.dispose();
    super.dispose();
  }

  void _addStepDialog() {
    final titleCtrl = TextEditingController();
    final deskCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int stepSla = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Approval Step'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Step Title *',
                    hintText: 'e.g. Warden Clearance',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deskCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Responsible Desk / Role *',
                    hintText: 'e.g. Hostel Warden',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Verification Instructions',
                    hintText: 'What needs to be checked at this desk?',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Step SLA (Days):'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: stepSla,
                      items: [1, 2, 3, 5, 7, 10, 14]
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d days'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => stepSla = val);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final t = titleCtrl.text.trim();
                final d = deskCtrl.text.trim();
                if (t.isEmpty || d.isEmpty) return;
                setState(() {
                  _steps.add({
                    'title': t,
                    'responsible_desk': d,
                    'description': descCtrl.text.trim(),
                    'sla_days': stepSla,
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Step'),
            ),
          ],
        ),
      ),
    );
  }

  void _addDocument() {
    final doc = _docInputController.text.trim();
    if (doc.isNotEmpty && !_requiredDocs.contains(doc)) {
      setState(() {
        _requiredDocs.add(doc);
        _docInputController.clear();
      });
    }
  }

  Future<void> _submitProcedure() async {
    if (_titleController.text.trim().isEmpty ||
        _departmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required basic details')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(apiClientProvider);
      final payload = {
        'title': _titleController.text.trim(),
        'department': _departmentController.text.trim(),
        'category': _selectedCategory,
        'description': _descController.text.trim(),
        'sla_days': _slaDays,
        'required_docs': _requiredDocs,
        'steps': _steps,
        'created_by': 'STAFF_ADMIN',
      };

      final res = await client.post('/procedures', data: payload);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res.statusCode == 201) {
          widget.onCreated();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('🎉 Custom procedure published successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Failed to publish procedure: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle & Header
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high_rounded,
                    color: AppColors.teal, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Interactive Procedure Setup Wizard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Stepper Progress Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _StagePill(
                  stage: 0,
                  current: _currentStage,
                  label: '1. Basic Info',
                  onTap: () => setState(() => _currentStage = 0),
                ),
                const SizedBox(width: 8),
                _StagePill(
                  stage: 1,
                  current: _currentStage,
                  label: '2. Steps',
                  onTap: () => setState(() => _currentStage = 1),
                ),
                const SizedBox(width: 8),
                _StagePill(
                  stage: 2,
                  current: _currentStage,
                  label: '3. Documents',
                  onTap: () => setState(() => _currentStage = 2),
                ),
                const SizedBox(width: 8),
                _StagePill(
                  stage: 3,
                  current: _currentStage,
                  label: '4. Review',
                  onTap: () => setState(() => _currentStage = 3),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Wizard Stage Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStageContent(),
            ),
          ),

          // Navigation Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStage > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentStage--),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                if (_currentStage < 3)
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStage == 0 &&
                          (_titleController.text.trim().isEmpty ||
                              _departmentController.text.trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter Title and Department')),
                        );
                        return;
                      }
                      setState(() => _currentStage++);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next Step'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitProcedure,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Publish Procedure'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_currentStage) {
      case 0:
        return _buildStage1BasicInfo();
      case 1:
        return _buildStage2Steps();
      case 2:
        return _buildStage3Docs();
      case 3:
        return _buildStage4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStage1BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stage 1: Basic Procedure Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Define the procedure title, responsible department, and category.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Procedure Title *',
            hintText: 'e.g. Hostel Room Change Application',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _departmentController,
          decoration: const InputDecoration(
            labelText: 'Department / Authority *',
            hintText: 'e.g. Hostel Administration',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'ACADEMIC',
                  'EXAMINATION',
                  'ACCOMMODATION',
                  'ACADEMIC_RECORDS',
                  'FINANCE',
                  'CAMPUS_SERVICES',
                  'GENERAL',
                ]
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _slaDays,
                decoration: const InputDecoration(
                  labelText: 'Overall SLA (Days) *',
                  border: OutlineInputBorder(),
                ),
                items: [3, 5, 7, 10, 14, 21, 30]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('$d Days SLA'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _slaDays = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Procedure Description',
            hintText: 'Summarize the purpose and requirements of this procedure.',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildStage2Steps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage 2: Sequential Workflow Steps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Define which desks must review and approve this in order.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _addStepDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Step'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_steps.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.format_list_numbered_rounded,
                      size: 40, color: AppColors.muted),
                  SizedBox(height: 8),
                  Text(
                    'No steps added yet.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap "Add Step" to configure sequential clearance desks.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _steps.length,
            itemBuilder: (ctx, idx) {
              final s = _steps[idx];
              return Card(
                key: ValueKey(s['title'] + idx.toString()),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.line)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 14,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    s['title'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${s['responsible_desk']} • ${s['sla_days']}d SLA',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (idx > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          tooltip: 'Move Up',
                          onPressed: () {
                            setState(() {
                              final item = _steps.removeAt(idx);
                              _steps.insert(idx - 1, item);
                            });
                          },
                        ),
                      if (idx < _steps.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          tooltip: 'Move Down',
                          onPressed: () {
                            setState(() {
                              final item = _steps.removeAt(idx);
                              _steps.insert(idx + 1, item);
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger, size: 20),
                        tooltip: 'Remove Step',
                        onPressed: () {
                          setState(() => _steps.removeAt(idx));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStage3Docs() {
    final suggestedDocs = [
      'Student ID Card Copy',
      'Latest Fee Receipt',
      'Grade Card / Marksheet',
      'No-Objection Certificate',
      'Medical Certificate',
      'Parent Consent Undertaking',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stage 3: Required Documents Checklist',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Specify files or certificates students must attach when applying.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _docInputController,
                decoration: const InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'e.g. Police Clearance Certificate',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addDocument(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addDocument,
              icon: const Icon(Icons.add),
              label: const Text('Add Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Quick Suggestions:',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestedDocs.map((s) {
            return ActionChip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onPressed: () {
                if (!_requiredDocs.contains(s)) {
                  setState(() => _requiredDocs.add(s));
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Configured Document Checklist:',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink),
        ),
        const SizedBox(height: 10),
        if (_requiredDocs.isEmpty)
          const Text('No documents added yet.',
              style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _requiredDocs.map((d) {
              return Chip(
                avatar: const Icon(Icons.check_circle,
                    size: 16, color: AppColors.teal),
                label: Text(d),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() => _requiredDocs.remove(d));
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStage4Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stage 4: Review & Publish',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Review the configured procedure details before publishing to students.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.trim().isEmpty
                      ? 'Untitled Procedure'
                      : _titleController.text.trim(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_departmentController.text.trim()} • $_selectedCategory • $_slaDays Days SLA',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                if (_descController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_descController.text.trim(),
                      style: const TextStyle(fontSize: 13)),
                ],
                const Divider(height: 24),
                Text(
                  'APPROVAL TIMELINE (${_steps.length} DESKS)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                if (_steps.isEmpty)
                  const Text('Direct submission (no intermediate steps).',
                      style: TextStyle(fontSize: 12, color: AppColors.muted))
                else
                  ..._steps.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.teal,
                            child: Text('${idx + 1}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          Text(s['title'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 8),
                          Text('(${s['responsible_desk']}, ${s['sla_days']}d)',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 24),
                Text(
                  'DOCUMENT REQUIREMENTS (${_requiredDocs.length} FILES)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                if (_requiredDocs.isEmpty)
                  const Text('No mandatory attachments.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _requiredDocs.map((d) {
                      return Chip(
                        label: Text(d, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.primarySoft,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StagePill extends StatelessWidget {
  final int stage;
  final int current;
  final String label;
  final VoidCallback onTap;

  const _StagePill({
    required this.stage,
    required this.current,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = stage == current;
    final isDone = stage < current;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : isDone
                    ? AppColors.tealSoft
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : isDone
                      ? AppColors.teal
                      : AppColors.line,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isActive || isDone ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? Colors.white
                    : isDone
                        ? AppColors.teal
                        : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
