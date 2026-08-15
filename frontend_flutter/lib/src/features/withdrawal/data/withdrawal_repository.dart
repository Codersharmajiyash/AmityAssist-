import '../../../core/network/api_client.dart';
import '../domain/withdrawal_models.dart';

class WithdrawalRepository {
  WithdrawalRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<WithdrawalGuide> fetchGuide() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/api/withdrawal/guide');
    return WithdrawalGuide.fromJson(response.data ?? {});
  }
}
