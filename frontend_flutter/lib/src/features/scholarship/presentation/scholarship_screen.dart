import 'package:flutter/material.dart';

class ScholarshipScreen extends StatelessWidget {
  const ScholarshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scholarship Discovery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ScholarshipCard(
            title: 'Amity Merit Scholarship',
            description: '50% tuition fee waiver for academic toppers with CGPA 8.0 or above.',
            amount: '120,000 INR',
            cgpaReq: '8.0+',
          ),
          _ScholarshipCard(
            title: "Vice Chancellor's Fellowship",
            description: '100% tuition fee waiver for outstanding students with CGPA 9.0 or above.',
            amount: '240,000 INR',
            cgpaReq: '9.0+',
          ),
        ],
      ),
    );
  }
}

class _ScholarshipCard extends StatelessWidget {
  const _ScholarshipCard({
    required this.title,
    required this.description,
    required this.amount,
    required this.cgpaReq,
  });

  final String title;
  final String description;
  final String amount;
  final String cgpaReq;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(label: Text('CGPA Req: $cgpaReq')),
                Chip(label: Text(amount), backgroundColor: Colors.green.shade100),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('Apply Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
