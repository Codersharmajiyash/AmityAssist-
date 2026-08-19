import 'package:flutter/material.dart';

class ClearanceQueueScreen extends StatelessWidget {
  const ClearanceQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Department Clearance Queue',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1B325D)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DataTable(
                    headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: [
                      _buildRow('STU001', 'John Doe', 'Computer Science', 'Pending', Colors.orange),
                      _buildRow('STU002', 'Jane Smith', 'Mechanical', 'Pending', Colors.orange),
                      _buildRow('STU003', 'Bob Johnson', 'Civil', 'Approved', Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(String id, String name, String dept, String status, Color statusColor) {
    return DataRow(
      cells: [
        DataCell(Text(id)),
        DataCell(Text(name)),
        DataCell(Text(dept)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          ),
        ),
        DataCell(
          ElevatedButton(
            onPressed: status == 'Pending' ? () {} : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B325D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Review'),
          ),
        ),
      ],
    );
  }
}
