import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../../core/widgets/uniassist_logo.dart';
import '../../chat/presentation/digital_counselor_modal.dart';
import '../../forms/domain/form_model.dart';

class GuestServicesScreen extends ConsumerStatefulWidget {
  const GuestServicesScreen({super.key});

  @override
  ConsumerState<GuestServicesScreen> createState() => _GuestServicesScreenState();
}

class _GuestServicesScreenState extends ConsumerState<GuestServicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  List<FormItem> _forms = [];
  List<dynamic> _notices = [];
  List<dynamic> _faqs = [];
  List<dynamic> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadServicesData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServicesData() async {
    setState(() => _isLoading = true);
    final dio = ref.read(apiClientProvider);

    try {
      // 1. Load Forms
      final formsRes = await dio.get('/forms/catalog');
      if (formsRes.statusCode == 200 && formsRes.data != null) {
        final list = formsRes.data['forms'] as List<dynamic>? ?? [];
        _forms = list.map((e) => FormItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {
      // Fallback sample forms
      _forms = [
        const FormItem(
          id: 1,
          formKey: 'withdrawal_application',
          name: 'Withdrawal Application Form',
          category: 'Academics',
          department: 'Registrar Office',
          description: 'Official application for university program withdrawal.',
          fileName: 'Withdrawal_Application.pdf',
          downloadUrl: '/forms/withdrawal-application.pdf',
          fileType: 'pdf',
        ),
        const FormItem(
          id: 2,
          formKey: 'migration_certificate',
          name: 'Migration Certificate Application',
          category: 'Academics',
          department: 'Registrar Office',
          description: 'Application for issuing migration certificate.',
          fileName: 'Migration_Certificate.pdf',
          downloadUrl: '/forms/migration-certificate.pdf',
          fileType: 'pdf',
        ),
        const FormItem(
          id: 3,
          formKey: 'fee_clearance',
          name: 'Fee Clearance Form',
          category: 'Finance',
          department: 'Finance Office',
          description: 'Finance and accounts clearance proforma.',
          fileName: 'Fee_Clearance.pdf',
          downloadUrl: '/forms/fee-clearance.pdf',
          fileType: 'pdf',
        ),
      ];
    }

    try {
      // 2. Load Notices
      final noticesRes = await dio.get('/services/notices');
      if (noticesRes.statusCode == 200 && noticesRes.data != null) {
        _notices = noticesRes.data['notices'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      _notices = [
        {
          'title': 'Mid-Semester Examinations Datesheet 2026',
          'content': 'Examinations commence on Oct 12, 2026. Hall tickets available on portal.',
          'category': 'exam',
          'timestamp': '2026-08-20',
        },
        {
          'title': 'Merit Scholarship Renewal Application Open',
          'content': 'Applications for merit and fellowship waivers are open till Sept 15, 2026.',
          'category': 'scholarship',
          'timestamp': '2026-08-18',
        },
        {
          'title': 'Student Grievance Redressal Committee Open House',
          'content': 'Open house session scheduled every Wednesday in Block F-3, Ground Floor.',
          'category': 'general',
          'timestamp': '2026-08-15',
        }
      ];
    }

    try {
      // 3. Load FAQs
      final faqsRes = await dio.get('/services/faqs');
      if (faqsRes.statusCode == 200 && faqsRes.data != null) {
        _faqs = faqsRes.data['faqs'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      _faqs = [
        {
          'category': 'Withdrawal',
          'question': 'How long does withdrawal processing take?',
          'answer': 'Initial check: 1-2 days. Clearances: 3-5 days. Finance & Refund: 7-10 working days.'
        },
        {
          'category': 'Certificates',
          'question': 'How to get a Bonafide Certificate?',
          'answer': 'Download Bonafide form from repository, fill and submit to Registrar Window. Ready in 2 days.'
        }
      ];
    }

    try {
      // 4. Load Contacts
      final contactsRes = await dio.get('/services/directory');
      if (contactsRes.statusCode == 200 && contactsRes.data != null) {
        _contacts = contactsRes.data['contacts'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      _contacts = [
        {
          'department': 'Registrar Office',
          'location': 'Block A, Ground Floor, Room 102',
          'email': 'registrar@uniassist.edu',
          'phone': '+91 (120) 439-2001',
          'hours': 'Mon-Fri: 9:00 AM - 5:00 PM',
          'lead': 'Dr. R. K. Sharma'
        },
        {
          'department': 'Controller of Examinations',
          'location': 'Block B, Second Floor, Room 204',
          'email': 'examcell@uniassist.edu',
          'phone': '+91 (120) 439-2015',
          'hours': 'Mon-Fri: 9:30 AM - 5:30 PM',
          'lead': 'Prof. S. Sengupta'
        },
        {
          'department': 'Finance & Accounts Desk',
          'location': 'Block A, First Floor, Room 115',
          'email': 'accounts@uniassist.edu',
          'phone': '+91 (120) 439-2030',
          'hours': 'Mon-Fri: 9:00 AM - 4:30 PM',
          'lead': 'Mr. Amit Verma'
        },
      ];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Welcome Kiosk',
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            const UniAssistLogo(size: 38, showWordmark: true),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'GUEST MODE',
                style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(120, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: const Text('Ask Counselor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            onPressed: () => showDigitalCounselor(context),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(110, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('Student Login', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.teal,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          tabs: const [
            Tab(icon: Icon(Icons.exit_to_app_rounded, size: 18), text: 'Withdrawal Process'),
            Tab(icon: Icon(Icons.school_rounded, size: 18), text: 'Scholarships & Aid'),
            Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Certificates & Transcripts'),
            Tab(icon: Icon(Icons.file_download_outlined, size: 18), text: 'Document Repository'),
            Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Notices Board'),
            Tab(icon: Icon(Icons.help_outline_rounded, size: 18), text: 'FAQs & Directory'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _WithdrawalGuideTab(
                  onAskCounselor: () => showDigitalCounselor(context, initialQuery: 'I want withdrawal'),
                  onLoginToSubmit: () => context.go('/login'),
                ),
                _ScholarshipsTab(
                  onAskCounselor: () => showDigitalCounselor(context, initialQuery: 'Scholarship eligibility'),
                ),
                _CertificatesTab(
                  forms: _forms.where((f) => f.category == 'Academics' || f.category == 'Admissions & Registrar').toList(),
                ),
                _DocumentRepositoryTab(
                  forms: _forms,
                  searchQuery: _searchQuery,
                  onSearchChanged: (val) => setState(() => _searchQuery = val),
                ),
                _NoticesTab(notices: _notices),
                _FaqsAndDirectoryTab(faqs: _faqs, contacts: _contacts),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Withdrawal Process Tab (Comprehensive Guide & Roadmap)
// ─────────────────────────────────────────────────────────────────────────────
class _WithdrawalGuideTab extends StatelessWidget {
  const _WithdrawalGuideTab({
    required this.onAskCounselor,
    required this.onLoginToSubmit,
  });

  final VoidCallback onAskCounselor;
  final VoidCallback onLoginToSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Hero Guidance Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Official University Withdrawal Intelligence System',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Complete structured roadmap for students and parents. Understand required documents, clearance departments, timelines, and refund policies before submitting.',
                          style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(160, 46),
                        ),
                        icon: const Icon(Icons.support_agent_rounded, size: 18),
                        label: const Text('Talk to Counselor', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: onAskCounselor,
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(160, 40),
                          backgroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: const Text('Login to Request', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: onLoginToSubmit,
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 28),

            // 3-Stage Timeline Bands
            const Text(
              'Official Timeline Bands & Clearances',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: _TimelineCard(
                    stage: 'Stage 1: Verification',
                    duration: '1-2 Working Days',
                    desc: 'Identity matching, reason logging, and checklist issuance at Registrar Window.',
                    color: AppColors.teal,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _TimelineCard(
                    stage: 'Stage 2: Clearances',
                    duration: '3-5 Working Days',
                    desc: 'Library book settlement, hostel handover, academic records, and fee audit.',
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _TimelineCard(
                    stage: 'Stage 3: Finance & Refund',
                    duration: '7-10 Working Days',
                    desc: 'Final fee adjustment, caution deposit release, and bank account transfer.',
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Required Documents Checklist
            const Text(
              'Required Documents & Forms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            const _DocumentItem(
              title: 'Withdrawal Application Form',
              mandatory: true,
              desc: 'Official request form duly signed by student and parent/guardian.',
              issuingDept: 'Registrar Office',
            ),
            const _DocumentItem(
              title: 'Student Identity Proof (University ID)',
              mandatory: true,
              desc: 'Original student ID card or official identity letter from the department.',
              issuingDept: 'Student / IT Cell',
            ),
            const _DocumentItem(
              title: 'Fee Clearance Statement',
              mandatory: true,
              desc: 'Statement showing paid fees, outstanding dues (if any), and refund eligibility.',
              issuingDept: 'Finance & Accounts',
            ),
            const _DocumentItem(
              title: 'Central Library No-Dues Certificate',
              mandatory: true,
              desc: 'Clearance certificate confirming all books and borrowed assets are returned.',
              issuingDept: 'Central Library',
            ),
            const _DocumentItem(
              title: 'Hostel No-Dues & Handover Form',
              mandatory: false,
              desc: 'Required only for hostellers. Room inventory check signed by Chief Warden.',
              issuingDept: 'Hostel Administration',
            ),
            const _DocumentItem(
              title: 'Medical Certificate / Supporting Proof',
              mandatory: false,
              desc: 'Required when program withdrawal is requested due to medical or relocation reasons.',
              issuingDept: 'Registered Medical Practitioner',
            ),

            const SizedBox(height: 28),

            // 6 Departments Involved Flow
            const Text(
              'Departments Involved in Processing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: const [
                _DeptChip(dept: '1. Student Services Desk', role: 'Initial intake & checklist issuance'),
                _DeptChip(dept: '2. Academic Department', role: 'Mentor interview & grade record check'),
                _DeptChip(dept: '3. Central Library', role: 'Book return & penalty waiver'),
                _DeptChip(dept: '4. Hostel Office', role: 'Room handover & mess dues settlement'),
                _DeptChip(dept: '5. Finance & Accounts', role: 'Caution deposit & fee refund calculation'),
                _DeptChip(dept: '6. Registrar Office', role: 'Final order & TC / Migration dispatch'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.stage,
    required this.duration,
    required this.desc,
    required this.color,
  });

  final String stage;
  final String duration;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stage,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            duration,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DocumentItem extends StatelessWidget {
  const _DocumentItem({
    required this.title,
    required this.mandatory,
    required this.desc,
    required this.issuingDept,
  });

  final String title;
  final bool mandatory;
  final String desc;
  final String issuingDept;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            mandatory ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: mandatory ? AppColors.teal : AppColors.muted,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: mandatory ? AppColors.dangerSoft : AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mandatory ? 'MANDATORY' : 'CONDITIONAL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: mandatory ? AppColors.danger : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              issuingDept,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptChip extends StatelessWidget {
  const _DeptChip({required this.dept, required this.role});

  final String dept;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dept, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(role, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Scholarships Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ScholarshipsTab extends StatelessWidget {
  const _ScholarshipsTab({required this.onAskCounselor});

  final VoidCallback onAskCounselor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_rounded, color: AppColors.gold, size: 36),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scholarships & Financial Assistance Schemes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Over ₹5 Crores disbursed annually to deserving meritorious and sports students.', style: TextStyle(fontSize: 13, color: AppColors.ink)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Check Eligibility'),
                    onPressed: onAskCounselor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SchemeCard(
              title: 'Vice Chancellor\'s Fellowship',
              benefit: '100% Tuition Fee Waiver',
              criteria: 'CGPA 9.0 and above with zero backpapers. Awarded to branch rank toppers.',
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            _SchemeCard(
              title: 'Amity Merit Scholarship',
              benefit: '50% Tuition Fee Waiver',
              criteria: 'CGPA 8.0 or above in semester-end examinations. Renewable each academic year.',
              color: AppColors.teal,
            ),
            const SizedBox(height: 14),
            _SchemeCard(
              title: 'Sports Excellence Waiver',
              benefit: '25% - 50% Fee Concession',
              criteria: 'Representation at National / State level inter-university sporting events.',
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  const _SchemeCard({
    required this.title,
    required this.benefit,
    required this.criteria,
    required this.color,
  });

  final String title;
  final String benefit;
  final String criteria;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(criteria, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              benefit,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Certificates & Transcripts Tab
// ─────────────────────────────────────────────────────────────────────────────
class _CertificatesTab extends StatelessWidget {
  const _CertificatesTab({required this.forms});

  final List<FormItem> forms;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Official Certificates & Transcripts Guide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Apply for bonafide certificates, character verification, provisional degrees, and migration documents.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            ...forms.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppColors.primary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('${f.department} • ${f.description}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(120, 40),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download Form', style: TextStyle(fontSize: 12.5)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Downloading ${f.fileName}...')),
                          );
                        },
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Document Repository Tab
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentRepositoryTab extends StatelessWidget {
  const _DocumentRepositoryTab({
    required this.forms,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final List<FormItem> forms;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final filtered = forms.where((f) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q) ||
          f.department.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search 30+ official forms (e.g. Migration, Rechecking, ID card, Leave)...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Showing ${filtered.length} official documents available for download',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final form = filtered[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          form.fileType.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(form.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                            const SizedBox(height: 3),
                            Text('${form.category} • ${form.department}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Download', style: TextStyle(fontSize: 12.5)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Downloading ${form.fileName}...')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Notices Tab
// ─────────────────────────────────────────────────────────────────────────────
class _NoticesTab extends StatelessWidget {
  const _NoticesTab({required this.notices});

  final List<dynamic> notices;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'University Public Notice Board',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            const Text('Campus-wide notices, examination circulars, and official orders.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notice = notices[index] as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.tealSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (notice['category'] ?? 'GENERAL').toString().toUpperCase(),
                              style: const TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const Spacer(),
                          Text(notice['timestamp'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        notice['title'] ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice['content'] ?? '',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.4),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. FAQs & Directory Tab
// ─────────────────────────────────────────────────────────────────────────────
class _FaqsAndDirectoryTab extends StatelessWidget {
  const _FaqsAndDirectoryTab({required this.faqs, required this.contacts});

  final List<dynamic> faqs;
  final List<dynamic> contacts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            ...faqs.map((faq) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      faq['question'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.ink),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          faq['answer'] ?? '',
                          style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 28),
            const Text(
              'Administrative Contact Directory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            ...contacts.map((contact) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.contacts_rounded, color: AppColors.primary, size: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(contact['department'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('${contact['lead'] ?? ''} • ${contact['location'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                            const SizedBox(height: 2),
                            Text('Email: ${contact['email'] ?? ''}  |  Phone: ${contact['phone'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
