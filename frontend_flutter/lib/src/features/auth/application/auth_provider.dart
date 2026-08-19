import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
/// Models the verification state
class AuthState {
  final bool isLoading;
  final String? studentId;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.studentId,
    this.error,
  });

  AuthState copyWith({bool? isLoading, String? studentId, String? error}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      studentId: studentId ?? this.studentId,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;

  AuthNotifier(this._dio) : super(const AuthState());

  Future<bool> verify(String studentIdOrEmail) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final isEmail = studentIdOrEmail.contains('@');
      final response = await _dio.post('/auth/verify', data: {
        'student_id': isEmail ? null : studentIdOrEmail,
        'email': isEmail ? studentIdOrEmail : null,
      });

      if (response.statusCode == 200) {
        // Backend returns: {"verified": true, "session_id": "...", "student_id": "STU001"}
        final data = response.data;
        if (data['verified'] == true) {
          state = state.copyWith(
            isLoading: false,
            studentId: data['student_id'] ?? studentIdOrEmail.toUpperCase(),
          );
          return true;
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Verification failed. Please check your details.',
      );
      return false;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Network error occurred.';
      state = state.copyWith(isLoading: false, error: msg.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred.');
      return false;
    }
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AuthNotifier(dio);
});
