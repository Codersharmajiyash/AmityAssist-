import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../domain/form_model.dart';

final formsCategoryFilterProvider = StateProvider<String?>((ref) => null);
final formsSearchQueryProvider = StateProvider<String>((ref) => '');

final formsCatalogProvider = FutureProvider<List<FormItem>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final category = ref.watch(formsCategoryFilterProvider);
  final query = ref.watch(formsSearchQueryProvider);

  final queryParams = <String, dynamic>{};
  if (category != null && category.isNotEmpty) {
    queryParams['category'] = category;
  }
  if (query.trim().isNotEmpty) {
    queryParams['q'] = query.trim();
  }

  final response = await dio.get('/forms/catalog', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  final list = data['forms'] as List<dynamic>? ?? [];

  return list.map((item) => FormItem.fromJson(item as Map<String, dynamic>)).toList();
});

final formCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get('/forms/categories');
  final data = response.data as Map<String, dynamic>;
  final list = data['categories'] as List<dynamic>? ?? [];
  return list.cast<Map<String, dynamic>>();
});
