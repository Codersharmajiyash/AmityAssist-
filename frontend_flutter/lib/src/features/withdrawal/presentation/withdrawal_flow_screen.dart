import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/theme/kiosk_theme.dart';
import '../../auth/application/auth_provider.dart';

class WithdrawalFlowScreen extends ConsumerStatefulWidget {
  const WithdrawalFlowScreen({super.key});

  @override
  ConsumerState<WithdrawalFlowScreen> createState() => _WithdrawalFlowScreenState();
}

class _WithdrawalFlowScreenState extends ConsumerState<WithdrawalFlowScreen> {
  int _currentStep = 0;
  String? _reason;
  bool _isSubmitting = false;

  final _reasons = [
    'Medical Reasons',
    'Financial Hardship',
    'Transferring to another university',
    'Personal Reasons',
    'Other'
  ];

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);
    final studentId = ref.read(authProvider).studentId;

    try {
      final dio = ref.read(apiClientProvider);

      // Create a withdrawal workflow via the Workflow API.
      await dio.post('/workflows', data: {
        'student_id': studentId,
        'procedure_type': 'withdrawal',
        'reason': _reason,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.response?.data?['detail'] ?? e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: Row(
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
                      : Text(isLastStep ? 'Submit Request' : 'Continue'),
                ),
                const SizedBox(width: 12),
                if (!isLastStep)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Cancel'),
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
            title: const Text('Required Documents'),
            content: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Based on your reason, the following documents are required:'),
                SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Withdrawal Application Form'),
                  subtitle: Text('Please download, sign, and upload.'),
                ),
                ListTile(
                  leading: Icon(Icons.receipt),
                  title: Text('Fee Clearance Form'),
                  subtitle: Text('Clearance from Finance Dept.'),
                ),
                ListTile(
                  leading: Icon(Icons.library_books),
                  title: Text('Library No-Dues Certificate'),
                  subtitle: Text('Clearance from Central Library.'),
                ),
              ],
            ),
            isActive: _currentStep >= 1,
            state:
                _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Upload & Submit'),
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.grey.shade400, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.upload_file, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Tap to scan or upload your signed documents'),
                  ],
                ),
              ),
            ),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }
}
