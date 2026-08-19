import 'package:flutter/material.dart';

class GrievanceResponseScreen extends StatelessWidget {
  const GrievanceResponseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grievance Response Desk',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1B325D)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 2,
                    child: ListView.separated(
                      itemCount: 2,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: const Text('Delay in fee receipt generation'),
                          subtitle: const Text('Category: Finance | Pending'),
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
                            'Grievance Details',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          const Text('Student ID: STU001', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Description:'),
                          const Text('I paid my semester fee 3 days ago but the receipt is still not generated in the portal. I need it for scholarship renewal.'),
                          const Spacer(),
                          const TextField(
                            decoration: InputDecoration(
                              labelText: 'Official Response',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B325D), foregroundColor: Colors.white),
                                child: const Text('Submit Resolution'),
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
}
