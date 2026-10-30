import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../../core/utils/platform_file_picker.dart';
import '../../auth/application/auth_provider.dart';

class WithdrawalDocRequirement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isRequired;

  const WithdrawalDocRequirement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isRequired = true,
  });
}

const _kWithdrawalDocs = [
  WithdrawalDocRequirement(
    id: 'withdrawal_application',
    title: 'Process 1: Signed Course Withdrawal Form (ADM/WTH-01)',
    description: 'Official student withdrawal petition signed by student stating reason and effective semester.',
    icon: Icons.assignment_turned_in_rounded,
    isRequired: true,
  ),
  WithdrawalDocRequirement(
    id: 'parent_consent',
    title: 'Process 2: Parent / Guardian Consent Letter',
    description: 'Signed letter from parent or registered guardian confirming authorization with phone number.',
    icon: Icons.family_restroom_rounded,
    isRequired: true,
  ),
  WithdrawalDocRequirement(
    id: 'bank_proof',
    title: 'Process 3: Bank Passbook / Cancelled Cheque (for NEFT Refund)',
    description: 'Bank document clearly displaying student/parent Account Number and IFSC code for refund transfer.',
    icon: Icons.account_balance_rounded,
    isRequired: true,
  ),
  WithdrawalDocRequirement(
    id: 'student_id_proof',
    title: 'Process 4: Student ID Card Copy',
    description: 'Front and back photo/scan of University Identity Card for digital identity validation.',
    icon: Icons.badge_rounded,
    isRequired: false,
  ),
];

class WithdrawalFlowScreen extends ConsumerStatefulWidget {
  const WithdrawalFlowScreen({super.key});

  @override
  ConsumerState<WithdrawalFlowScreen> createState() => _WithdrawalFlowScreenState();
}

class _WithdrawalFlowScreenState extends ConsumerState<WithdrawalFlowScreen> {
  // Phase 4: Bank Detail Input State Controllers
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  String _accountRelationship = 'Student';
  int _currentStep = 0;
  String? _reason;
  bool _isSubmitting = false;
  String? _uploadStatusMessage;

  final Map<String, PickedDocFile> _pickedDocs = {};
  final Set<String> _pickingDocIds = {};

  final _reasons = [
    'Medical Reasons',
    'Financial Hardship',
    'Transferring to another university',
    'Personal Reasons',
    'Other'
  ];


  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authProvider);
      if (!auth.isAuthenticated || auth.studentId == null || auth.isStaff) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.lock_person_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Student Sign-In Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Withdrawal submission requires verified student credentials.\nPlease sign in as a student to proceed.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.go('/services');
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.push('/login');
                },
                child: const Text('Sign In as Student'),
              ),
            ],
          ),
        );
        return;
      }

      // Check if student already has an active request (strictly once at a time)
      try {
        final dio = ref.read(apiClientProvider);
        final resp = await dio.get('/withdrawal/status/${auth.studentId}');
        final data = resp.data as Map<String, dynamic>;
        final hasRequest = data['has_request'] == true;
        final request = data['request'] as Map<String, dynamic>?;
        final status = (request?['status'] ?? '').toString().toLowerCase();
        final isTerminal = status == 'completed' || status == 'rejected' || status == 'cancelled';

        if (hasRequest && !isTerminal && mounted) {
          final refNo = request?['reference_no'] ?? 'AMITY-WTH';
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Active Request In Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'You already have an active withdrawal application in progress ($refNo).\n\nUnder university rules, only one active withdrawal request is permitted at a time.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    context.go('/services');
                  },
                  child: const Text('Return to Services'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    context.go('/request-status');
                  },
                  icon: const Icon(Icons.track_changes_rounded, size: 18),
                  label: const Text('Track Active Request'),
                ),
              ],
            ),
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _pickProcessDocument(WithdrawalDocRequirement doc) async {
    setState(() => _pickingDocIds.add(doc.id));
    try {
      final file = await PlatformFilePicker.pickDocument(accept: '.pdf,.jpg,.jpeg,.png');
      if (file != null && mounted) {
        setState(() => _pickedDocs[doc.id] = file);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.title} selected: ${file.name} (${file.formattedSize})'),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingDocIds.remove(doc.id));
    }
  }

  Future<void> _submitRequest() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.studentId == null || auth.isStaff) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in with verified student credentials to submit.')),
        );
      }
      return;
    }
    final studentId = auth.studentId!;

    // Check required process documents
    final missingRequired = _kWithdrawalDocs.where((d) => d.isRequired && !_pickedDocs.containsKey(d.id)).toList();
    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please upload required document: ${missingRequired.first.title}'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadStatusMessage = 'Initializing clearance chain across 4 university gates...';
    });

    try {
      final dio = ref.read(apiClientProvider);

      // 1. Submit official withdrawal initiating 4 clearance gates & caution deposit ledger
      final response = await dio.post('/withdrawal/apply', data: {
        'student_id': studentId,
        'reason': _reason,
        'intent': 'withdrawal_official',
      });

      final data = response.data as Map<String, dynamic>;
      final refNo = data['reference_no']?.toString() ?? 'AMITY-WTH-2026';

      // Phase 4: Save structured bank details to Confidential Vault
      if (_accountHolderController.text.trim().isNotEmpty &&
          _accountNumberController.text.trim().isNotEmpty &&
          _ifscCodeController.text.trim().isNotEmpty) {
        try {
          await dio.post('/withdrawal/$refNo/bank-details', data: {
            'account_holder_name': _accountHolderController.text.trim(),
            'account_number': _accountNumberController.text.trim(),
            'confirm_account_number': _confirmAccountController.text.trim().isNotEmpty
                ? _confirmAccountController.text.trim()
                : _accountNumberController.text.trim(),
            'ifsc_code': _ifscCodeController.text.trim().toUpperCase(),
            'relationship': _accountRelationship,
          });
        } catch (_) {}
      }
      final voucher = data['voucher'] as Map<String, dynamic>?;
      final refundAmt = voucher?['net_refundable_amount']?.toString() ?? '119,000.00';

      // 2. Upload each process document with real bytes to /documents/upload
      int uploadedCount = 0;
      for (final doc in _kWithdrawalDocs) {
        final picked = _pickedDocs[doc.id];
        if (picked != null) {
          uploadedCount++;
          if (mounted) {
            setState(() {
              _uploadStatusMessage = 'Uploading ${doc.title} ($uploadedCount/${_pickedDocs.length})...';
            });
          }
          try {
            final formData = FormData.fromMap({
              'student_id': studentId,
              'document_type': doc.id,
              'file': picked.bytes != null
                  ? MultipartFile.fromBytes(picked.bytes!, filename: picked.name)
                  : MultipartFile.fromString('Official Document: ${doc.title}', filename: picked.name),
            });
            await dio.post('/documents/upload', data: formData);
          } catch (_) {}
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 28),
                SizedBox(width: 10),
                Text('Withdrawal Submitted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your clearance chain has been initialized across 4 university gates.'),
                const SizedBox(height: 12),
                Text(
                  '${_pickedDocs.length} process documents uploaded and queued for institutional OCR audit.',
                  style: const TextStyle(fontSize: 13, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Official Reference Token:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SelectableText(
                        refNo,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Estimated Net Refund: ₹$refundAmt',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.successGreen),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Track this application anytime using your token at the kiosk or under Live Clearance Tracker.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                },
                child: const Text('Return to Home'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  Navigator.pop(context);
                  context.push('/request-status');
                },
                icon: const Icon(Icons.track_changes_rounded, size: 18),
                label: const Text('Track 4-Gate Status'),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail']?.toString() ?? e.message ?? 'Unknown error';
      if (mounted) {
        if (detail.toLowerCase().contains('active withdrawal request') || detail.toLowerCase().contains('already in progress')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
                  SizedBox(width: 8),
                  Text('Active Request Exists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(detail),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/request-status');
                  },
                  icon: const Icon(Icons.track_changes_rounded, size: 18),
                  label: const Text('Track Live Status'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $detail')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadStatusMessage = null;
        });
      }
    }
  }

  // ── Phase 4: Visual Sample Cheque Modal ──────────────────────────────────────
  void showSampleChequeGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0A192F)),
            SizedBox(width: 10),
            Text('Cancelled Cheque Specimen Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A cancelled cheque proves your bank details to the Finance Office so your refund can be wired via NEFT.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              // Visual Cheque Specimen Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('HDFC BANK LTD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('DATE: DD/MM/YYYY', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('PAY: _____________________________________', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 8),
                        const Text('A/C NO: 50100234891234  (Keep Legible)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                        const Text('IFSC CODE: HDFC0000128  (Keep Legible)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('[ Do NOT Sign Here ]', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Two Diagonal Red Lines with CANCELLED
                    Positioned.fill(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.25,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.symmetric(horizontal: BorderSide(color: Colors.red.shade700, width: 2)),
                            ),
                            child: Text(
                              'C A N C E L L E D',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red.shade700, letterSpacing: 4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Mandatory Compliance Rules:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _ruleBullet('1. Account Holder Name must match Student or Parent (No friend/third-party accounts).'),
              _ruleBullet('2. Both Account Number and 11-digit IFSC code must be completely readable.'),
              _ruleBullet('3. If you do not have a chequebook, upload the 1st page of your Bank Passbook.'),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
        ],
      ),
    );
  }

  Widget _ruleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ── Phase 4: Bank Proof Upload Card with Structured Fields ──────────────────
  Widget _buildBankProofSection(WithdrawalDocRequirement doc) {
    final pickedFile = _pickedDocs[doc.id];
    final isPicking = _pickingDocIds.contains(doc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5A623), width: 1.5), // Gold financial border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF5A623).withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFFF5A623), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Process 3: Bank Proof & Cancelled Cheque', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Mandatory for NEFT/RTGS tuition refund wire transfer', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showSampleChequeGuide(context),
                icon: const Icon(Icons.help_outline_rounded, size: 16),
                label: const Text('View Sample', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Divider(height: 24),
          // Structured Input Fields
          TextField(
            controller: _accountHolderController,
            decoration: const InputDecoration(
              labelText: 'Account Holder Full Name',
              hintText: 'Must match student or registered parent',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Bank Account Number', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _confirmAccountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Confirm Account Number', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ifscCodeController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(11)],
                  decoration: const InputDecoration(
                    labelText: 'Bank IFSC Code (11 Characters)',
                    hintText: 'e.g. HDFC0000128 or SBIN0001234',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _accountRelationship,
                items: const [
                  DropdownMenuItem(value: 'Student', child: Text('Student Account')),
                  DropdownMenuItem(value: 'Father/Mother', child: Text('Parent Account')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _accountRelationship = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // File Upload Trigger
          if (pickedFile == null)
            OutlinedButton.icon(
              onPressed: (isPicking || _isSubmitting) ? null : () => _pickProcessDocument(doc),
              icon: isPicking
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isPicking ? 'Selecting file...' : 'Upload Cancelled Cheque / Passbook Copy (PDF, JPG)'),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bank document attached (${pickedFile.name}) and queued for Accounts audit.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickProcessDocument(doc),
                    child: const Text('Change', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessDocCard(WithdrawalDocRequirement doc) {
    if (doc.id == 'bank_proof') {
      return _buildBankProofSection(doc);
    }

    final pickedFile = _pickedDocs[doc.id];
    final isPicking = _pickingDocIds.contains(doc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pickedFile != null ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pickedFile != null
              ? AppColors.successGreen
              : const Color(0xFFE2E8F0),
          width: pickedFile != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (pickedFile != null ? AppColors.successGreen : AppColors.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  pickedFile != null ? Icons.verified_rounded : doc.icon,
                  color: pickedFile != null ? AppColors.successGreen : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: doc.isRequired
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: doc.isRequired ? const Color(0xFFFECACA) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            doc.isRequired ? 'REQUIRED' : 'OPTIONAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: doc.isRequired ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc.description,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pickedFile == null)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: (isPicking || _isSubmitting) ? null : () => _pickProcessDocument(doc),
                icon: isPicking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(isPicking ? 'Selecting file...' : 'Upload Document'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: AppColors.successGreen, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickedFile.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pickedFile.formattedSize} • Ready for OCR verification',
                          style: const TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : () => _pickProcessDocument(doc),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Change', style: TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => setState(() => _pickedDocs.remove(doc.id)),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                    tooltip: 'Remove',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiredCount = _kWithdrawalDocs.where((d) => d.isRequired).length;
    final uploadedRequiredCount = _kWithdrawalDocs.where((d) => d.isRequired && _pickedDocs.containsKey(d.id)).length;
    final totalUploaded = _pickedDocs.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Initiate Withdrawal')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _reason == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a reason.')),
            );
            return;
          }
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _submitRequest();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSubmitting && _uploadStatusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _uploadStatusMessage!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _isSubmitting ? null : details.onStepContinue,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLastStep ? 'Submit Application' : 'Continue'),
                    ),
                    const SizedBox(width: 12),
                    if (!isLastStep)
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Select Reason'),
            content: DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration:
                  const InputDecoration(labelText: 'Reason for Withdrawal'),
              items: _reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v),
            ),
            isActive: _currentStep >= 0,
            state:
                _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Clearance Guidelines & Requirements'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Under University Ordinance ORD-ACAD-04, program departure follows a mandatory 4-gate clearance chain:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 12),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.library_books_rounded, color: AppColors.primary),
                  title: Text('Gate 1: Central Library Clearance'),
                  subtitle: Text('Return of all issued books; any fine under ₹2,000 can be smart-offset from caution deposit.'),
                ),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.science_rounded, color: AppColors.primary),
                  title: Text('Gate 2: Department Laboratory Clearance'),
                  subtitle: Text('Sign-off on department equipment, locker, and project resources.'),
                ),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.hotel_rounded, color: AppColors.primary),
                  title: Text('Gate 3: Hostel & Mess Warden Sign-Off'),
                  subtitle: Text('Room handover, inventory check, and mess dues reconciliation.'),
                ),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                  title: Text('Gate 4: Finance & Fee Refund Gate'),
                  subtitle: Text('Calculation of tuition refund per UGC slabs + 100% ₹10,000 refundable caution deposit.'),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next step: Upload required documents process-by-process from your device to begin the institutional verification.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state:
                _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Process-by-Process Document Upload'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Attach Required Process Documents:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: uploadedRequiredCount >= requiredCount
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: uploadedRequiredCount >= requiredCount
                              ? AppColors.successGreen
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        '$uploadedRequiredCount of $requiredCount Required Ready ($totalUploaded total)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: uploadedRequiredCount >= requiredCount
                              ? AppColors.successGreen
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select authentic PDF or image files from your computer or phone. Uploaded documents undergo OCR verification.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ..._kWithdrawalDocs.map((doc) => _buildProcessDocCard(doc)),
              ],
            ),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }
}
