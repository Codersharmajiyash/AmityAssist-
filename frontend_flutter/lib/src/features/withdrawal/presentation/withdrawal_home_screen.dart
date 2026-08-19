import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'withdrawal_providers.dart';

class WithdrawalHomeScreen extends ConsumerWidget {
  const WithdrawalHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(withdrawalGuideProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal Services'),
      ),
      body: guide.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load withdrawal guide: $error'),
          ),
        ),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: data.title,
                subtitle: data.summary,
                child: Text(data.principle),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Required Documents',
                subtitle: 'Generated from the official withdrawal procedure',
                child: Column(
                  children: data.documents
                      .map(
                        (document) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            document.mandatory ? Icons.assignment_turned_in : Icons.assignment_outlined,
                          ),
                          title: Text(document.name),
                          subtitle: Text(document.description),
                          trailing: Text(document.mandatory ? 'Required' : 'If needed'),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Official Steps',
                subtitle: 'Follow the procedure without skipping stages',
                child: Column(
                  children: data.steps
                      .map(
                        (step) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text('${step.stepNumber}')),
                          title: Text(step.title),
                          subtitle: Text('${step.department}\n${step.timelineText}\n${step.description}'),
                          isThreeLine: true,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Form Repository',
                subtitle: 'Official forms for download or kiosk printing',
                child: Column(
                  children: data.forms
                      .map(
                        (form) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(form.name),
                          subtitle: Text('${form.issuingDepartment}\n${form.description}'),
                          trailing: const Icon(Icons.download_outlined),
                          isThreeLine: true,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Timeline Guidance',
                subtitle: 'Official timeline bands, not predictions',
                child: Column(
                  children: data.officialTimeline
                      .map(
                        (band) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_outlined),
                          title: Text(band.stage),
                          subtitle: Text(band.timeline),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/withdrawal/flow'),
        icon: const Icon(Icons.add),
        label: const Text('Initiate Withdrawal'),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
