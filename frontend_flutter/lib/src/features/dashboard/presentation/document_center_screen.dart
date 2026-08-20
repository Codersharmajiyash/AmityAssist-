import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../auth/application/auth_provider.dart';

final studentDocumentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final studentId = ref.watch(authProvider).studentId;
  if (studentId == null) throw Exception('Not logged in');

  final dio = ref.watch(apiClientProvider);
  try {
    final response = await dio.get('/documents/list/$studentId');
    return (response.data as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (e) {
    return [];
  }
});

class DocumentCenterScreen extends ConsumerStatefulWidget {
  const DocumentCenterScreen({super.key});

  @override
  ConsumerState<DocumentCenterScreen> createState() => _DocumentCenterScreenState();
}

class _DocumentCenterScreenState extends ConsumerState<DocumentCenterScreen> {
  bool _isUploading = false;
  Map<String, dynamic>? _lastUploadResult;

  /// Simulates a document upload to the backend.
  Future<void> _uploadDocument(String docType) async {
    setState(() {
      _isUploading = true;
      _lastUploadResult = null;
    });

    try {
      final dio = ref.read(apiClientProvider);
      final studentId = ref.read(authProvider).studentId;

      // Create a mock multipart upload.
      // In a real kiosk, this would use file_picker or camera.
      final formData = FormData.fromMap({
        'student_id': studentId,
        'document_type': docType,
        'file': MultipartFile.fromString(
          'Mock document content for $docType — this simulates a kiosk scan.',
          filename: '${docType.toLowerCase().replaceAll(' ', '_')}.pdf',
          contentType: DioMediaType('application', 'pdf'),
        ),
      });

      final response = await dio.post('/documents/upload', data: formData);

      setState(() {
        _lastUploadResult = response.data is Map
            ? Map<String, dynamic>.from(response.data)
            : {'status': 'uploaded'};
      });

      ref.invalidate(studentDocumentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully!')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.response?.data?['detail'] ?? e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(studentDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Document Center')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Upload area ────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.cloud_upload_rounded,
                              color: Color(0xFF00897B), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Text('Upload Document',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select a document type to upload. On a kiosk, this would open the scanner.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _uploadChip('ID Card'),
                        _uploadChip('Marksheet'),
                        _uploadChip('Medical Certificate'),
                        _uploadChip('Fee Receipt'),
                        _uploadChip('No-Dues Certificate'),
                      ],
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Scanning & analysing document...'),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),

            // ── OCR result card ────────────────────────────
            if (_lastUploadResult != null) ...[
              const SizedBox(height: 16),
              _OcrResultCard(result: _lastUploadResult!).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            ],

            // ── Document list ──────────────────────────────
            const SizedBox(height: 16),
            Text('Your Documents', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
              data: (docs) {
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No documents uploaded yet.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _DocumentTile(doc: doc);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadChip(String docType) {
    return ActionChip(
      avatar: const Icon(Icons.upload_file_rounded, size: 18),
      label: Text(docType),
      onPressed: _isUploading ? null : () => _uploadDocument(docType),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc});
  final Map<String, dynamic> doc;

  @override
  Widget build(BuildContext context) {
    final status = doc['status'] ?? 'PENDING';
    final type = doc['document_type'] ?? 'Document';

    final statusIcon = switch (status.toUpperCase()) {
      'VERIFIED' => const Icon(Icons.check_circle, color: AppColors.successGreen),
      'FLAGGED' => const Icon(Icons.warning_rounded, color: Color(0xFFEF6C00)),
      _ => const Icon(Icons.hourglass_empty, color: Colors.grey),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.amityBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.file_present_rounded, size: 28, color: AppColors.amityBlue),
        ),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Status: $status'),
        trailing: statusIcon,
      ),
    );
  }
}

class _OcrResultCard extends StatelessWidget {
  const _OcrResultCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final ocrData = result['ocr_data'] as Map<String, dynamic>? ?? {};
    final fraudFlags = (result['fraud_flags'] as List?)?.cast<String>() ?? [];
    final overallStatus = result['overall_status'] ?? result['status'] ?? 'UNKNOWN';
    final isFraud = overallStatus == 'FRAUD_DETECTED';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isFraud ? AppColors.urgentRed.withValues(alpha: 0.4) : AppColors.successGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFraud ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded,
                  color: isFraud ? AppColors.urgentRed : AppColors.successGreen,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  'Document AI Analysis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFraud
                        ? AppColors.urgentRed.withValues(alpha: 0.12)
                        : AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    overallStatus.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isFraud ? AppColors.urgentRed : AppColors.successGreen,
                    ),
                  ),
                ),
              ],
            ),
            if (ocrData.isNotEmpty) ...[
              const Divider(height: 20),
              _ocrRow('Name', ocrData['extracted_name']),
              _ocrRow('Student ID', ocrData['extracted_student_id']),
              _ocrRow('Date', ocrData['extracted_date']),
              _ocrRow('Type', ocrData['document_type']),
              _ocrRow('Confidence', '${((ocrData['confidence_score'] ?? 0) * 100).toStringAsFixed(0)}%'),
              _ocrRow('Signature', ocrData['signature_detected'] == true ? '✓ Detected' : '✗ Not found'),
              _ocrRow('Stamp', ocrData['stamp_detected'] == true ? '✓ Detected' : '✗ Not found'),
            ],
            if (fraudFlags.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...fraudFlags.map(
                (flag) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.urgentRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(flag,
                            style: const TextStyle(fontSize: 14, color: AppColors.urgentRed)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ocrRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(child: Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
