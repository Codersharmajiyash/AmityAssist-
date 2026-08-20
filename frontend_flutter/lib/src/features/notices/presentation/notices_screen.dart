import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/api_client.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../auth/application/auth_provider.dart';

/// Fetch personalized notices from the backend.
final noticesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final studentId = ref.watch(authProvider).studentId;
  final cache = ref.watch(offlineCacheProvider);

  if (studentId == null) return [];

  try {
    final response = await dio.get('/student/notices', queryParameters: {
      'student_id': studentId,
    });

    final data = (response.data as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await cache.put('notices_$studentId', response.data);
    return data;
  } catch (e) {
    final cached = cache.get('notices_$studentId');
    if (cached != null) {
      return (cached as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
});

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: noticesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (notices) {
          if (notices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No notices available', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(noticesProvider),
            child: ListView.builder(
              itemCount: notices.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final notice = notices[index];
                return _NoticeTile(notice: notice)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: 50 * index),
                      duration: 300.ms,
                    )
                    .slideY(begin: 0.08);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});
  final Map<String, dynamic> notice;

  @override
  Widget build(BuildContext context) {
    final title = notice['title'] ?? 'Notice';
    final body = notice['body'] ?? notice['content'] ?? '';
    final category = notice['category'] ?? '';
    final date = notice['date'] ?? notice['created_at'] ?? '';
    final targetBranch = notice['target_branch'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category + date chips
            Row(
              children: [
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (targetBranch.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(targetBranch, style: const TextStyle(fontSize: 12)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
