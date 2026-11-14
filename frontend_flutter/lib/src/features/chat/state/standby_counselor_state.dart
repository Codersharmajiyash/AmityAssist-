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

  void enterStandby({
    required String topic,
    required String lastGuidance,
    List<dynamic>? currentHistory,
  }) {
    state = StandbyCounselorState(
      isStandbyActive: true,
      activeTopic: topic.isNotEmpty ? topic : (state.activeTopic.isNotEmpty ? state.activeTopic : 'Campus Guidance'),
      lastSpokenGuidance: lastGuidance.isNotEmpty ? lastGuidance : state.lastSpokenGuidance,
      history: (currentHistory != null && currentHistory.isNotEmpty)
          ? List.from(currentHistory)
          : state.history,
    );
  }

  void exitStandby() {
    state = state.copyWith(isStandbyActive: false);
  }

  void updateHistory(List<dynamic> newHistory) {
    if (newHistory.isNotEmpty) {
      state = state.copyWith(history: List.from(newHistory));
    }
  }

  void appendTurn(dynamic turn) {
    state = state.copyWith(history: [...state.history, turn]);
  }

  void clearHistory() {
    state = const StandbyCounselorState();
  }
}

final standbyCounselorProvider = StateNotifierProvider<StandbyCounselorNotifier, StandbyCounselorState>((ref) {
  return StandbyCounselorNotifier();
});
