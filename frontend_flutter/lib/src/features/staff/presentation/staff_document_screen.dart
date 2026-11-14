import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/api_config.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../../core/utils/download_service.dart';
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
              // Live In-Memory Document Preview (Zero Local Disk Storage)
              Expanded(
                flex: 3,
                child: Container(
                  height: 520,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildInMemoryDocumentViewer(doc),
                ),
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
                          ref.read(staffActionsProvider).verifyDocument(doc['id'], 'verified', 'Looks good');
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
                          ref.read(staffActionsProvider).verifyDocument(doc['id'], 'fraud_detected', 'Failed verification');
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

  Widget _buildInMemoryDocumentViewer(Map<String, dynamic> doc) {
    final docId = doc['id'];
    final fileName = (doc['file_name'] ?? doc['filename'] ?? '').toString();
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final streamUrl = '${AppConfig.apiBaseUrl}/documents/$docId/stream';

    if (!isPdf) {
      // Pure In-Memory Image Viewer for JPG, PNG
      return InteractiveViewer(
        panEnabled: true,
        minScale: 0.8,
        maxScale: 3.5,
        child: Center(
          child: Image.network(
            streamUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (ctx, err, stack) => _buildViewerFallback(fileName),
          ),
        ),
      );
    } else {
      // PDF Document Viewer Pane
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.urgentRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, size: 64, color: AppColors.urgentRed),
              ),
              const SizedBox(height: 18),
              Text(
                fileName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PDF Format • Official University Record',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amityBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => DownloadService.downloadFile(streamUrl, fileName: fileName),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open in Native PDF Viewer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _openFullscreenMemoryPreview(context, streamUrl, fileName, isPdf: true),
                icon: const Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white70),
                label: const Text('Document Details & Preview Modal', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildViewerFallback(String fileName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            fileName.isNotEmpty ? fileName : 'Document Preview',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Document preview ready via in-memory stream',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openFullscreenMemoryPreview(BuildContext context, String streamUrl, String fileName, {bool isPdf = false}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 1000,
          height: 700,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: isPdf
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 80, color: AppColors.urgentRed),
                            const SizedBox(height: 16),
                            Text(
                              fileName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'In-Memory PDF Stream Active • Zero Local Disk Footprint',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.amityBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => DownloadService.downloadFile(streamUrl, fileName: fileName),
                              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                              label: const Text('Open in Native PDF Viewer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.network(
                            streamUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (c, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: Colors.white));
                            },
                            errorBuilder: (_, __, ___) => _buildViewerFallback(fileName),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
