import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';

/// Phase 28 + Phase 30: Staff Institution Configurator.
/// Admin Settings screen for university branding, dynamic clearance chain
/// management, custom refund slab editing, module switchboard, and procedure step customizer.
class StaffInstitutionScreen extends ConsumerStatefulWidget {
  const StaffInstitutionScreen({super.key});

  @override
  ConsumerState<StaffInstitutionScreen> createState() => _StaffInstitutionScreenState();
}

class _StaffInstitutionScreenState extends ConsumerState<StaffInstitutionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _config = {};
  List<dynamic> _clearanceChain = [];
  List<dynamic> _refundSlabs = [];
  Map<String, dynamic> _modules = {};
  List<dynamic> _procedureSteps = [];
  final String _selectedProcedureCode = 'withdrawal';

  static const List<Map<String, String>> _availableModules = [
    {
      'id': 'dashboard',
      'title': 'Student & Admin Dashboard',
      'description': 'Central statistics, status cards, and metric overviews.',
      'icon': 'dashboard',
    },
    {
      'id': 'academics',
      'title': 'Academic Cell & Course Records',
      'description': 'Credits, semester tracking, and curriculum mapping.',
      'icon': 'school',
    },
    {
      'id': 'withdrawal',
      'title': 'Withdrawal & Clearance Cockpit',
      'description': 'Multi-gate student exit workflow, caution refund offsets.',
      'icon': 'exit_to_app',
    },
    {
      'id': 'forms',
      'title': 'Forms & Applications Catalog',
      'description': '31+ downloadable academic, financial, and logistics forms.',
      'icon': 'folder_shared',
    },
    {
      'id': 'grievance',
      'title': 'Student Grievance Redressal Desk',
      'description': 'Mandatory SLA ticket logging, tracking, and staff escalation.',
      'icon': 'support_agent',
    },
    {
      'id': 'scholarships',
      'title': 'Scholarships & Financial Aid',
      'description': 'Merit renewal criteria and tuition concessions.',
      'icon': 'monetization_on',
    },
    {
      'id': 'hostel',
      'title': 'Hostel & Accommodation Desk',
      'description': 'Room allocation, warden clearance, mess records.',
      'icon': 'apartment',
    },
    {
      'id': 'examinations',
      'title': 'Examination & Rechecking Portal',
      'description': 'Exam eligibility, re-evaluation, and Form EX-02.',
      'icon': 'assignment',
    },
    {
      'id': 'voice_ai',
      'title': 'AI Counselor & Voice Assistance',
      'description': 'Hands-free speech navigation, bilingual counsel.',
      'icon': 'record_voice_over',
    },
    {
      'id': 'documents',
      'title': 'Verified Documents & Vault',
      'description': 'Digital document verification, bonafide certificates.',
      'icon': 'verified_user',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final configRes = await client.get('/institution/config');
      final chainRes = await client.get('/institution/clearance-chain');
      final slabRes = await client.get('/institution/refund-slabs');
      final modulesRes = await client.get('/institution/modules');
      final stepsRes = await client.get('/procedures/$_selectedProcedureCode/steps');

      if (mounted) {
        setState(() {
          if (configRes.data is Map<String, dynamic>) {
            _config = configRes.data as Map<String, dynamic>;
          }
          if (chainRes.data is Map<String, dynamic>) {
            _clearanceChain = (chainRes.data as Map<String, dynamic>)['chain'] as List? ?? [];
          }
          if (slabRes.data is Map<String, dynamic>) {
            _refundSlabs = (slabRes.data as Map<String, dynamic>)['slabs'] as List? ?? [];
          }
          if (modulesRes.data is Map<String, dynamic>) {
            _modules = (modulesRes.data as Map<String, dynamic>)['modules'] as Map<String, dynamic>? ?? {};
          }
          if (stepsRes.data is Map<String, dynamic>) {
            _procedureSteps = (stepsRes.data as Map<String, dynamic>)['steps'] as List? ?? [];
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

  Future<void> _fetchSteps() async {
    try {
      final client = ref.read(apiClientProvider);
      final stepsRes = await client.get('/procedures/$_selectedProcedureCode/steps');
      if (mounted && stepsRes.data is Map<String, dynamic>) {
        setState(() {
          _procedureSteps = (stepsRes.data as Map<String, dynamic>)['steps'] as List? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleModule(String moduleId, bool enabled) async {
    setState(() {
      _modules[moduleId] = enabled;
    });

    try {
      final client = ref.read(apiClientProvider);
      await client.put(
        '/institution/modules',
        data: {'modules': _modules},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${enabled ? "Enabled" : "Disabled"} module: $moduleId'),
            duration: const Duration(seconds: 1),
            backgroundColor: enabled ? AppColors.successGreen : Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update module switchboard'), backgroundColor: AppColors.urgentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Institution Configurator'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF4DB6AC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.branding_watermark), text: 'Branding'),
            Tab(icon: Icon(Icons.linear_scale), text: 'Clearance Chain'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Refund Slabs'),
            Tab(icon: Icon(Icons.toggle_on_rounded), text: 'Switchboard'),
            Tab(icon: Icon(Icons.format_list_numbered_rounded), text: 'Procedure Steps'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBrandingTab(),
                _buildClearanceChainTab(),
                _buildRefundSlabsTab(),
                _buildModulesTab(),
                _buildProcedureStepsTab(),
              ],
            ),
    );
  }

  // ── Branding Tab ───────────────────────────────────────────────────────────
  Widget _buildBrandingTab() {
    final displayKeys = [
      'institution_name', 'institution_motto', 'crest_logo_url',
      'primary_color', 'secondary_color', 'contact_email',
      'contact_phone', 'website_url', 'address',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_rounded, color: AppColors.amityBlue, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    _config['institution_name'] ?? 'University',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
              if (_config['institution_motto'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 40),
                  child: Text(
                    '"${_config['institution_motto']}"',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 24),
              ...displayKeys.map((key) => _buildConfigRow(key, _config[key]?.toString() ?? '—')),
              const SizedBox(height: 16),
              // Color preview
              Row(
                children: [
                  const Text('Theme Preview: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _parseColor(_config['primary_color']),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _parseColor(_config['secondary_color']),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  Widget _buildConfigRow(String key, String value) {
    final label = key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w).join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ── Clearance Chain Tab ────────────────────────────────────────────────────
  Widget _buildClearanceChainTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.linear_scale, color: AppColors.amityBlue),
              const SizedBox(width: 8),
              const Text('Dynamic Clearance Desks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              Text('${_clearanceChain.length} desks', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 16),
          ..._clearanceChain.asMap().entries.map((entry) {
            final idx = entry.key;
            final desk = entry.value;
            final isLast = idx == _clearanceChain.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper indicator
                Column(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.amityBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (!isLast) Container(width: 2, height: 40, color: AppColors.amityBlue.withValues(alpha: 0.3)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(desk['desk_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (desk['is_active'] == 1 ? AppColors.successGreen : Colors.grey).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  desk['is_active'] == 1 ? 'Active' : 'Inactive',
                                  style: TextStyle(color: desk['is_active'] == 1 ? AppColors.successGreen : Colors.grey, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          Text(desk['desk_name'] ?? '', style: TextStyle(color: Colors.grey.shade700)),
                          if (desk['description'] != null && desk['description'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(desk['description'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Refund Slabs Tab ───────────────────────────────────────────────────────
  Widget _buildRefundSlabsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Refund Day Slabs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FixedColumnWidth(80),
                  2: FixedColumnWidth(80),
                  3: FixedColumnWidth(90),
                  4: FlexColumnWidth(3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppColors.amityBlue.withValues(alpha: 0.1)),
                    children: const [
                      Padding(padding: EdgeInsets.all(10), child: Text('Slab', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(10), child: Text('From', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(10), child: Text('To', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(10), child: Text('Refund %', style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(10), child: Text('Policy Note', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ..._refundSlabs.map((slab) {
                    final pct = (slab['refund_percent'] ?? 0).toDouble();
                    final color = pct >= 80 ? AppColors.successGreen : pct >= 25 ? Colors.amber.shade700 : AppColors.urgentRed;
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(10), child: Text(slab['slab_label'] ?? '')),
                        Padding(padding: const EdgeInsets.all(10), child: Text('Day ${slab['min_days']}')),
                        Padding(padding: const EdgeInsets.all(10), child: Text('Day ${slab['max_days']}')),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text('${pct.toStringAsFixed(0)}%',
                                style: TextStyle(color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                        Padding(padding: const EdgeInsets.all(10), child: Text(slab['policy_note'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Module Switchboard Tab ─────────────────────────────────────────────────
  Widget _buildModulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.toggle_on_rounded, color: Color(0xFF00695C), size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dynamic Module Switchboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    'Toggle features and navigation tabs on or off for this institution',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          ..._availableModules.map((m) {
            final modId = m['id']!;
            final isEnabled = _modules[modId] ?? true;

            IconData iconData;
            switch (m['icon']) {
              case 'dashboard':
                iconData = Icons.dashboard_rounded;
                break;
              case 'school':
                iconData = Icons.school_rounded;
                break;
              case 'exit_to_app':
                iconData = Icons.exit_to_app_rounded;
                break;
              case 'folder_shared':
                iconData = Icons.folder_shared_rounded;
                break;
              case 'support_agent':
                iconData = Icons.support_agent_rounded;
                break;
              case 'monetization_on':
                iconData = Icons.monetization_on_rounded;
                break;
              case 'apartment':
                iconData = Icons.apartment_rounded;
                break;
              case 'assignment':
                iconData = Icons.assignment_rounded;
                break;
              case 'record_voice_over':
                iconData = Icons.record_voice_over_rounded;
                break;
              default:
                iconData = Icons.verified_user_rounded;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                value: isEnabled,
                activeThumbColor: const Color(0xFF00695C),
                secondary: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isEnabled ? const Color(0xFF00695C) : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: isEnabled ? const Color(0xFF00695C) : Colors.grey),
                ),
                title: Text(
                  m['title']!,
                  style: TextStyle(fontWeight: FontWeight.w600, color: isEnabled ? AppColors.ink : Colors.grey.shade600),
                ),
                subtitle: Text(
                  m['description']!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                onChanged: (val) => _toggleModule(modId, val),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Procedure Steps Customizer Tab ────────────────────────────────────────
  Widget _buildProcedureStepsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_list_numbered_rounded, color: Color(0xFF00695C), size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Procedure Step Customizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    'Customize steps, SLA timelines, and responsible departments',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddStepDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Step'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_procedureSteps.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No steps configured for $_selectedProcedureCode.', style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            ..._procedureSteps.map((s) {
              final stepNum = s['step_number'] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00695C).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$stepNum',
                            style: const TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s['title'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    s['timeline_text'] ?? '1-2 days',
                                    style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Department: ${s['department'] ?? '—'}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            if (s['description'] != null && s['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                s['description'].toString(),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF00695C)),
                        tooltip: 'Edit Step',
                        onPressed: () => _showEditStepDialog(s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.urgentRed),
                        tooltip: 'Delete Step',
                        onPressed: () => _confirmDeleteStep(stepNum),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddStepDialog() {
    final titleCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Department Desk');
    final timelineCtrl = TextEditingController(text: '1-2 days');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Procedure Step', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Step Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Responsible Department *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timelineCtrl,
                decoration: const InputDecoration(labelText: 'Timeline SLA (e.g. 24 hours) *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description / Instructions', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || deptCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(apiClientProvider);
                await client.post(
                  '/procedures/$_selectedProcedureCode/steps',
                  data: {
                    'title': titleCtrl.text.trim(),
                    'department': deptCtrl.text.trim(),
                    'timeline_text': timelineCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                  },
                );
                await _fetchSteps();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Step added successfully'), backgroundColor: AppColors.successGreen),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to add step'), backgroundColor: AppColors.urgentRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white),
            child: const Text('Add Step'),
          ),
        ],
      ),
    );
  }

  void _showEditStepDialog(Map<String, dynamic> step) {
    final stepNum = step['step_number'] ?? 1;
    final titleCtrl = TextEditingController(text: step['title'] ?? '');
    final deptCtrl = TextEditingController(text: step['department'] ?? '');
    final timelineCtrl = TextEditingController(text: step['timeline_text'] ?? '');
    final descCtrl = TextEditingController(text: step['description'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Step $stepNum', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Step Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: 'Responsible Department', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timelineCtrl,
                decoration: const InputDecoration(labelText: 'Timeline SLA', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(apiClientProvider);
                await client.put(
                  '/procedures/$_selectedProcedureCode/steps/$stepNum',
                  data: {
                    'title': titleCtrl.text.trim(),
                    'department': deptCtrl.text.trim(),
                    'timeline_text': timelineCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                  },
                );
                await _fetchSteps();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Step updated successfully'), backgroundColor: AppColors.successGreen),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update step'), backgroundColor: AppColors.urgentRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStep(int stepNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Step $stepNumber?'),
        content: const Text('This will delete the step and re-index all subsequent steps to maintain continuous numbering.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(apiClientProvider);
                await client.delete('/procedures/$_selectedProcedureCode/steps/$stepNumber');
                await _fetchSteps();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Step $stepNumber deleted'), backgroundColor: AppColors.urgentRed),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete step'), backgroundColor: AppColors.urgentRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgentRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
