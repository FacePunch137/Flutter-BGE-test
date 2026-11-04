import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/decision_model.dart';
import '../../data/search_repository.dart';

class DocumentState {
  final bool isLoading;
  final DecisionModel? currentDecision;
  final String? errorMessage;

  DocumentState({
    this.isLoading = false,
    this.currentDecision,
    this.errorMessage,
  });

  DocumentState copyWith({
    bool? isLoading,
    DecisionModel? currentDecision,
    String? errorMessage,
  }) {
    return DocumentState(
      isLoading: isLoading ?? this.isLoading,
      currentDecision: currentDecision ?? this.currentDecision,
      errorMessage: errorMessage,
    );
  }
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  final SearchRepository _repository;

  DocumentNotifier(this._repository) : super(DocumentState());

  Future<void> loadDecision(String caseId, String category) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final decision = await _repository.getFullDecision(caseId, category);
      if (decision != null) {
        state = state.copyWith(isLoading: false, currentDecision: decision);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Decision not found in $category database');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load document: $e');
    }
  }

  void clearDocument() {
    state = DocumentState();
  }
}
