import 'package:flutter_riverpod/flutter_riverpod.dart';

class StandbyCounselorState {
  final bool isStandbyActive;
  final String activeTopic;
  final String lastSpokenGuidance;
  final List<dynamic> history;

  const StandbyCounselorState({
    this.isStandbyActive = false,
    this.activeTopic = '',
    this.lastSpokenGuidance = '',
    this.history = const [],
  });

  StandbyCounselorState copyWith({
    bool? isStandbyActive,
    String? activeTopic,
    String? lastSpokenGuidance,
    List<dynamic>? history,
  }) {
    return StandbyCounselorState(
      isStandbyActive: isStandbyActive ?? this.isStandbyActive,
      activeTopic: activeTopic ?? this.activeTopic,
      lastSpokenGuidance: lastSpokenGuidance ?? this.lastSpokenGuidance,
      history: history ?? this.history,
    );
  }
}

class StandbyCounselorNotifier extends StateNotifier<StandbyCounselorState> {
  StandbyCounselorNotifier() : super(const StandbyCounselorState());

  void enterStandby({required String topic, required String lastGuidance, required List<dynamic> currentHistory}) {
    state = StandbyCounselorState(
      isStandbyActive: true,
      activeTopic: topic,
      lastSpokenGuidance: lastGuidance,
      history: List.from(currentHistory),
    );
  }

  void exitStandby() {
    state = state.copyWith(isStandbyActive: false);
  }

  void appendTurn(dynamic turn) {
    state = state.copyWith(history: [...state.history, turn]);
  }
}

final standbyCounselorProvider = StateNotifierProvider<StandbyCounselorNotifier, StandbyCounselorState>((ref) {
  return StandbyCounselorNotifier();
});
