import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import '../../../core/theme/kiosk_theme.dart';
import 'digital_signature_dialog.dart';

class StaffNotesheetScreen extends ConsumerStatefulWidget {
  const StaffNotesheetScreen({super.key});

  @override
  ConsumerState<StaffNotesheetScreen> createState() => _StaffNotesheetScreenState();
}

class _StaffNotesheetScreenState extends ConsumerState<StaffNotesheetScreen> {
  bool _isLoading = true;
  List<dynamic> _notesheets = [];
  String? _selectedCategory;
  String _currentStageFilter = 'ALL';

  final List<String> _stages = ['SUPERVISOR', 'HOD', 'HOI', 'PRO_VC', 'VC'];

  @override
  void initState() {
    super.initState();
    _fetchNotesheets();
  }

  Future<void> _fetchNotesheets() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(apiClientProvider);
      final params = <String, dynamic>{};
      if (_currentStageFilter != 'ALL') {
        params['stage'] = _currentStageFilter;
      }
      if (_selectedCategory != null && _selectedCategory != 'All') {
        params['category'] = _selectedCategory;
      }

      final res = await dio.get('/notesheets', queryParameters: params);
      if (mounted) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _notesheets = data['notesheets'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performAction(String refNo, String action, String stage, {String? customComments}) async {
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.post(
        '/notesheets/$refNo/action',
        data: {
          'officer_id': 'STAFF_CURRENT',
          'officer_name': 'Senior Administrative Officer',
          'role': stage,
          'action': action,
          'comments': customComments ?? 'Signed and processed via Staff Digital Notesheet Cockpit',
        },
      );

      if (mounted) {
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notesheet $refNo marked: $action'),
              backgroundColor: AppColors.successGreen,
            ),
          );
          _fetchNotesheets();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Action failed: ${res.data}'),
              backgroundColor: AppColors.urgentRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.urgentRed,
          ),
        );
      }
    }
  }

  void _openSignatureFlow(String refNo, String stage) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => DigitalSignatureDialog(
        officerName: 'Dr. Suresh Sharma',
        officerRole: stage,
        stage: stage,
      ),
    );

    if (result != null) {
      final comments = "${result['comments']} [${result['signature']}]";
      _performAction(refNo, stage == 'VC' ? 'APPROVE' : 'FORWARD', stage, customComments: comments);
    }
  }

  void _showWordEditDialog(Map<String, dynamic> ns) {
    final content = ns['content'] is Map ? Map<String, dynamic>.from(ns['content'] as Map) : <String, dynamic>{};
    final refNo = ns['reference_no'];
    final controllers = <String, TextEditingController>{};
    for (final entry in content.entries) {
      controllers[entry.key] = TextEditingController(text: entry.value?.toString() ?? '');
    }
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.description_rounded, color: AppColors.amityBlue),
            const SizedBox(width: 8),
            Text('Word-Style Document Editor: $refNo'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit any paragraph or field directly like a Word document. All modifications are tracked with an audit trail.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ...content.keys.map((k) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[k],
                      decoration: InputDecoration(
                        labelText: k.replaceAll('_', ' ').toUpperCase(),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: k.contains('reason') || k.contains('notes') ? 3 : 1,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Mandatory Audit Justification',
                    hintText: 'e.g. Corrected course details and updated disciplinary findings.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amityBlue),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audit reason is mandatory for document modifications')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final dio = ref.read(apiClientProvider);
                for (final entry in controllers.entries) {
                  final newVal = entry.value.text.trim();
                  if (newVal != content[entry.key]?.toString()) {
                    await dio.post(
                      '/notesheets/$refNo/edit-field',
                      data: {
                        'officer_id': 'STAFF_OFFICER',
                        'officer_role': ns['current_stage'] ?? 'HOD',
                        'field_name': entry.key,
                        'new_value': newVal,
                        'reason': reason,
                      },
                    );
                  }
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document updated and audit logged!'), backgroundColor: AppColors.successGreen),
                  );
                  _fetchNotesheets();
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Changes to Document'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Notesheet Word Editor & Signatures'),
        backgroundColor: AppColors.amityBlue,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchNotesheets, tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Text('Stage Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _currentStageFilter,
                  items: ['ALL', ..._stages]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _currentStageFilter = val);
                      _fetchNotesheets();
                    }
                  },
                ),
                const Spacer(),
                Text(
                  'Hierarchy: Supervisor ➔ HOD ➔ HOI ➔ Pro-VC ➔ VC',
                  style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notesheets.isEmpty
                    ? const Center(child: Text('No digital notesheets found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _notesheets.length,
                        itemBuilder: (ctx, idx) {
                          final ns = _notesheets[idx];
                          final refNo = ns['reference_no'] ?? '';
                          final title = ns['title'] ?? '';
                          final stage = ns['current_stage'] ?? '';
                          final status = ns['status'] ?? '';
                          final content = ns['content'] is Map ? ns['content'] as Map : {};
                          final signatures = ns['signatures'] is List ? ns['signatures'] as List : [];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Document Official Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrow = constraints.maxWidth < 650;
                                      final iconAndTitle = Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: AppColors.amityBlue,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'AMITY UNIVERSITY • OFFICIAL ACADEMIC & ADMINISTRATIVE NOTESHEET',
                                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5, color: AppColors.amityBlue),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Reference No: $refNo • Category: ${ns['category'] ?? 'General'}',
                                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );

                                      final statusBadge = Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: status == 'APPROVED'
                                              ? AppColors.successGreen
                                              : (status == 'REJECTED' ? AppColors.urgentRed : AppColors.amityYellow),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$stage ($status)',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      );

                                      if (isNarrow) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            iconAndTitle,
                                            const SizedBox(height: 10),
                                            statusBadge,
                                          ],
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(child: iconAndTitle),
                                          const SizedBox(width: 12),
                                          statusBadge,
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                // Document Body (Word-file style)
                                Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAFAFA),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: content.entries.map((entry) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 180,
                                                    child: Text(
                                                      '${entry.key.replaceAll('_', ' ').toUpperCase()}:',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      entry.value?.toString() ?? '',
                                                      style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),

                                      const SizedBox(height: 24),
                                      const Divider(),
                                      const SizedBox(height: 14),

                                      // Digital Signatures Section
                                      Row(
                                        children: const [
                                          Icon(Icons.verified_user_rounded, color: AppColors.amityBlue, size: 20),
                                          SizedBox(width: 8),
                                          Text('OFFICIAL SIGNATURES & VERIFICATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // Signature Blocks
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: _stages.map((stg) {
                                          final sig = signatures.firstWhere((s) => s['stage'] == stg, orElse: () => null);
                                          final isSigned = sig != null;

                                          return Container(
                                            width: 220,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: isSigned ? Colors.blue.shade50 : Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSigned ? AppColors.amityBlue.withValues(alpha: 0.4) : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(stg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.amityBlue)),
                                                    const Spacer(),
                                                    Icon(
                                                      isSigned ? Icons.check_circle_rounded : Icons.pending_outlined,
                                                      size: 16,
                                                      color: isSigned ? AppColors.successGreen : Colors.grey,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                if (isSigned) ...[
                                                  Text(sig['officer_name'] ?? 'Officer', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${sig['action']} • ${sig['signed_at']?.toString().substring(0, 10) ?? ''}',
                                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Seal: ${sig['comments'] ?? 'Signed'}',
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black87),
                                                  ),
                                                ] else ...[
                                                  const SizedBox(height: 10),
                                                  const Text('Pending signature', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                                ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),

                                // Document Actions Bar
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.amityBlue),
                                        label: const Text('Download DOCX'),
                                        onPressed: () {
                                          final url = '${ApiConfig.serverUrl}/api/notesheets/$refNo/docx';
                                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.edit_document, size: 16),
                                        label: const Text('Edit Document Text'),
                                        onPressed: status == 'IN_REVIEW' ? () => _showWordEditDialog(ns) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                        label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                        onPressed: status == 'IN_REVIEW' ? () => _performAction(refNo, 'REJECT', stage) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: stage == 'VC' ? AppColors.successGreen : AppColors.amityBlue,
                                        ),
                                        icon: Icon(stage == 'VC' ? Icons.verified : Icons.draw_rounded, size: 18),
                                        label: Text(stage == 'VC' ? 'Sign & Final Approve' : 'Add Signature & Forward'),
                                        onPressed: status == 'IN_REVIEW' ? () => _openSignatureFlow(refNo, stage) : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
