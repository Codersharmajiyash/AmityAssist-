import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/kiosk_theme.dart';
import '../application/staff_provider.dart';

class StaffDocumentScreen extends ConsumerStatefulWidget {
  const StaffDocumentScreen({super.key});

  @override
  ConsumerState<StaffDocumentScreen> createState() => _StaffDocumentScreenState();
}

class _StaffDocumentScreenState extends ConsumerState<StaffDocumentScreen> {
  Map<String, dynamic>? _selectedDocument;

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(adminDocumentsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Document Review'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (documents) {
          final pendingDocs = documents.where((d) => d['status'] == 'PENDING').toList();

          if (pendingDocs.isEmpty) {
            return const Center(child: Text('No pending documents for review.'));
          }

          // Default select the first document if none is selected
          if (_selectedDocument == null && pendingDocs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedDocument = pendingDocs.first;
              });
            });
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Document List
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade300)),
                    color: Colors.white,
                  ),
                  child: ListView.separated(
                    itemCount: pendingDocs.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = pendingDocs[index];
                      final isSelected = _selectedDocument?['id'] == doc['id'];

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.amityBlue.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.all(16),
                        leading: Icon(
                          Icons.description,
                          color: isSelected ? AppColors.amityBlue : Colors.grey,
                          size: 32,
                        ),
                        title: Text(
                          doc['document_type'],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('Student: ${doc['student_id']}\nDate: ${doc['upload_date']}'),
                        trailing: doc['fraud_flags'] != null && (doc['fraud_flags'] as List).isNotEmpty
                            ? const Icon(Icons.warning, color: AppColors.urgentRed)
                            : const Icon(Icons.check_circle_outline, color: AppColors.successGreen),
                        onTap: () {
                          setState(() {
                            _selectedDocument = doc;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),

              // Right Pane: Document Review Detail
              Expanded(
                flex: 5,
                child: _selectedDocument == null
                    ? const Center(child: Text('Select a document to review'))
                    : _buildReviewPanel(context, _selectedDocument!),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewPanel(BuildContext context, Map<String, dynamic> doc) {
    final flags = doc['fraud_flags'] as List? ?? [];
    final confidence = (doc['ocr_confidence'] as double? ?? 0.0) * 100;
    final isHighRisk = flags.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                doc['document_type'],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isHighRisk ? AppColors.urgentRed.withValues(alpha: 0.1) : AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  isHighRisk ? 'HIGH RISK' : 'LOW RISK',
                  style: TextStyle(
                    color: isHighRisk ? AppColors.urgentRed : AppColors.successGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Uploaded by ${doc['student_id']} on ${doc['upload_date']}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 32),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document Preview (Mock)
              Expanded(
                flex: 3,
                child: Container(
                  height: 500,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_drive_file, size: 100, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Document Preview\n(PDF/Image Viewer)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        )
                      ],
                    ),
                  ),
                ).animate().fadeIn().scale(),
              ),
              const SizedBox(width: 32),

              // Analysis Results & Actions
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Analysis', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildInfoRow('OCR Confidence', '${confidence.toStringAsFixed(1)}%'),
                    const SizedBox(height: 16),
                    
                    if (flags.isNotEmpty) ...[
                      const Text('Fraud Flags Detected:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.urgentRed)),
                      const SizedBox(height: 8),
                      ...flags.map((flag) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.urgentRed, size: 16),
                            const SizedBox(width: 8),
                            Text(flag.toString()),
                          ],
                        ),
                      )),
                      const SizedBox(height: 24),
                    ],

                    const Divider(),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {
                          ref.read(staffActionsProvider).verifyDocument(doc['id'], 'VERIFIED', 'Looks good');
                          setState(() => _selectedDocument = null);
                        },
                        icon: const Icon(Icons.verified),
                        label: const Text('Approve Document'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(staffActionsProvider).verifyDocument(doc['id'], 'REJECTED', 'Failed verification');
                          setState(() => _selectedDocument = null);
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject Document'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.urgentRed,
                          side: const BorderSide(color: AppColors.urgentRed),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
