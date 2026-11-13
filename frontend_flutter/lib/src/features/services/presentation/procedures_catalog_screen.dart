import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';

class ProceduresCatalogScreen extends ConsumerStatefulWidget {
  const ProceduresCatalogScreen({super.key});

  @override
  ConsumerState<ProceduresCatalogScreen> createState() => _ProceduresCatalogScreenState();
}

class _ProceduresCatalogScreenState extends ConsumerState<ProceduresCatalogScreen> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _customProcedures = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProcedures();
  }

  Future<void> _fetchProcedures() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get('/procedures', queryParameters: {'active_only': true});
      final data = response.data;

      if (data is Map && data['procedures'] is List) {
        setState(() {
          _customProcedures = (data['procedures'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // In offline/mock mode or backend error, continue with default procedures
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  List<Map<String, dynamic>> _getDefaultProcedures() {
    return [
      {
        'id': 'withdrawal',
        'title': 'Official University Withdrawal & Digital Clearance',
        'department': 'Registrar & Student Services',
        'category': 'CLEARANCE',
        'description':
            'Structured 4-gate automated clearance across Library, Hostel, Finance, and Registrar. Includes automatic caution deposit refund calculation under UGC norms.',
        'sla_days': 7,
        'is_core': true,
        'required_docs': [
          'Withdrawal Application Form',
          'Student ID Proof',
          'Fee Clearance Statement',
          'Library Clearance Slip'
        ],
        'steps': [
          {'step_number': 1, 'title': 'Gate 1: Central Library', 'responsible_desk': 'Circulation Desk', 'sla_days': 1},
          {'step_number': 2, 'title': 'Gate 2: Hostel & Mess Administration', 'responsible_desk': 'Hostel Office', 'sla_days': 2},
          {'step_number': 3, 'title': 'Gate 3: Finance & Accounts Office', 'responsible_desk': 'Finance Counter 4', 'sla_days': 2},
          {'step_number': 4, 'title': 'Gate 4: Registrar Final Audit & TC', 'responsible_desk': 'Assistant Registrar Room 102', 'sla_days': 2},
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _getAllCombinedProcedures() {
    final defaults = _getDefaultProcedures();
    final combined = <Map<String, dynamic>>[...defaults];

    // Append custom procedures avoiding duplicate IDs
    for (final custom in _customProcedures) {
      final exists = combined.any((p) => p['id'] == custom['id'] || p['title'] == custom['title']);
      if (!exists) {
        combined.add(custom);
      }
    }

    return combined.where((proc) {
      final matchesSearch = _searchQuery.isEmpty ||
          (proc['title'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (proc['department'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (proc['description'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());

      final cat = (proc['category'] ?? 'GENERAL').toString().toUpperCase();
      final matchesCategory = _selectedCategory == 'ALL' || cat.contains(_selectedCategory);

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final procedures = _getAllCombinedProcedures();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('University Procedures Catalog'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.amityBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Procedures',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchProcedures,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header banner & search section
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.amityBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_tree_rounded, color: AppColors.amityBlue, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Official University Procedures & Workflows',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select a procedure to review official clearance steps, required documentation, and SLA timelines.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Search field
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search procedure by name, desk, or keyword (e.g. withdrawal, certificate, hostel)...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.amityBlue),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Workflows'),
                      _buildFilterChip('CLEARANCE', 'Clearance & Exit'),
                      _buildFilterChip('ACADEMIC', 'Academic Records'),
                      _buildFilterChip('SPORTS', 'Sports & Facilities'),
                      _buildFilterChip('STUDENT_SERVICES', 'Campus Services'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Procedures Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : procedures.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No matching procedures found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try adjusting your search terms or filter category.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchProcedures,
                        child: GridView.builder(
                          padding: EdgeInsets.all(isDesktop ? 24 : 14),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 3 : 1,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            mainAxisExtent: 260,
                          ),
                          itemCount: procedures.length,
                          itemBuilder: (context, index) {
                            final proc = procedures[index];
                            return _buildProcedureCard(context, proc);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.amityBlue.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppColors.amityBlue : Colors.grey.shade700,
        ),
        onSelected: (_) => setState(() => _selectedCategory = key),
      ),
    );
  }

  Widget _buildProcedureCard(BuildContext context, Map<String, dynamic> proc) {
    final isCore = proc['is_core'] == true || proc['id'] == 'withdrawal';
    final title = proc['title'] ?? 'Official Procedure';
    final dept = proc['department'] ?? 'University Administration';
    final desc = proc['description'] ?? 'Standard university procedural workflow.';
    final sla = proc['sla_days'] ?? 3;
    final category = (proc['category'] ?? 'OFFICIAL').toString().replaceAll('_', ' ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCore ? AppColors.amityBlue.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: isCore ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (proc['id'] == 'withdrawal') {
            // Opens the full 4-gate Withdrawal Services screen (Images 2 & 3)
            context.push('/withdrawal');
          } else {
            _showProcedureDetailsDialog(context, proc);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCore
                          ? AppColors.urgentRed.withValues(alpha: 0.1)
                          : AppColors.amityBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCore ? Icons.assignment_return_rounded : Icons.description_rounded,
                      color: isCore ? AppColors.urgentRed : AppColors.amityBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCore
                                ? AppColors.urgentRed.withValues(alpha: 0.1)
                                : Colors.blueGrey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCore ? '★ CORE WORKFLOW' : category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCore ? AppColors.urgentRed : Colors.blueGrey.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dept,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$sla Days', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  desc,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isCore ? 'Open 4-Gate Clearance' : 'View Workflow Steps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCore ? AppColors.urgentRed : AppColors.amityBlue,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: isCore ? AppColors.urgentRed : AppColors.amityBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProcedureDetailsDialog(BuildContext context, Map<String, dynamic> proc) {
    final title = proc['title'] ?? 'Official Procedure';
    final dept = proc['department'] ?? 'University Administration';
    final desc = proc['description'] ?? 'No description provided.';
    final sla = proc['sla_days'] ?? 3;
    final docs = proc['required_docs'] is List ? (proc['required_docs'] as List) : [];
    final steps = proc['steps'] is List ? (proc['steps'] as List) : [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.all(20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amityBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree_outlined, color: AppColors.amityBlue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$dept • Expected SLA: $sla Days', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Approval Pipeline Steps
                const Row(
                  children: [
                    Icon(Icons.stairs_rounded, size: 18, color: AppColors.amityBlue),
                    SizedBox(width: 6),
                    Text('Approval Chain & Desk Flow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                if (steps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Direct processing desk: $dept (Single stage)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  )
                else
                  ...steps.map((st) {
                    final stMap = st is Map ? st : {};
                    final stNum = stMap['step_number'] ?? (steps.indexOf(st) + 1);
                    final stTitle = stMap['title'] ?? 'Processing Step';
                    final stDesk = stMap['responsible_desk'] ?? dept;
                    final stDays = stMap['sla_days'] ?? 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.amityBlue,
                            child: Text('$stNum', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stTitle.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text('Desk: $stDesk', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text('$stDays Day(s)', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Required Documents Checklist
                const Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 18, color: AppColors.amityBlue),
                    SizedBox(width: 6),
                    Text('Mandatory Documents Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('No external documents required. Processed against active enrollment record.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  )
                else
                  ...docs.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.successGreen),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d.toString(), style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amityBlue),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Workflow guide for "$title" ready. Contact $dept to initiate application.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Initiate Application'),
          ),
        ],
      ),
    );
  }
}
