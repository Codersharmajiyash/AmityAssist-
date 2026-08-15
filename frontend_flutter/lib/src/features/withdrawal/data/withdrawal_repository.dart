import 'package:dio/dio.dart';
import '../domain/withdrawal_models.dart';

class WithdrawalRepository {
  WithdrawalRepository(this._dio);

  final Dio _dio;

  Future<WithdrawalGuide> fetchGuide() async {
    final response = await _dio.get<Map<String, dynamic>>('/withdrawal/guide');
    return WithdrawalGuide.fromJson(response.data ?? {});
  }
}
