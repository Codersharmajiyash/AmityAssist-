import 'package:flutter/material.dart';

class DocumentApprovalsScreen extends StatelessWidget {
  const DocumentApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Document Approvals',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1B325D)),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check_circle),
                label: const Text('Batch Approve Verified'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // List of documents
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 2,
                    child: ListView.separated(
                      itemCount: 3,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                          title: Text('Medical_Certificate_STU00${index + 1}.pdf'),
                          subtitle: const Text('Uploaded 2 hours ago'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {},
                          selected: index == 0,
                          selectedTileColor: Colors.blue.withOpacity(0.1),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // OCR Panel
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Document AI Analysis',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey[100],
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildOcrResult('Document Type', 'Medical Certificate', true),
                                _buildOcrResult('Student ID Match', 'Yes (STU001)', true),
                                _buildOcrResult('Signature Detected', 'Yes', true),
                                _buildOcrResult('Fraud Check', 'Passed (No alteration detected)', true),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Reject (Fraudulent)'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B325D), foregroundColor: Colors.white),
                                child: const Text('Approve Document'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrResult(String label, String value, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
