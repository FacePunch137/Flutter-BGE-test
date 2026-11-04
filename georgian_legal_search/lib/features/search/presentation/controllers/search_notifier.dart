import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/search_result_model.dart';
import '../../data/hybrid_search_engine.dart';

class SearchState {
  final bool isLoading;
  final List<SearchResultModel> results;
  final String latencyMessage;
  final String? errorMessage;
  final String query;
  final String category;

  SearchState({
    this.isLoading = false,
    this.results = const [],
    this.latencyMessage = '',
    this.errorMessage,
    this.query = '',
    this.category = 'Civil',
  });

  SearchState copyWith({
    bool? isLoading,
    List<SearchResultModel>? results,
    String? latencyMessage,
    String? errorMessage,
    String? query,
    String? category,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      latencyMessage: latencyMessage ?? this.latencyMessage,
      errorMessage: errorMessage,
      query: query ?? this.query,
      category: category ?? this.category,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final HybridSearchEngine _engine;

  SearchNotifier(this._engine) : super(SearchState());

  Future<void> executeSearch(String query) async {
    if (query.trim().isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null, query: query, results: []);
    
    final stopwatch = Stopwatch()..start();
    try {
      final results = await _engine.executeHybridSearch(query, state.category);
      stopwatch.stop();
      state = state.copyWith(
        isLoading: false,
        results: results,
        latencyMessage: 'Search completed in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed: $e',
      );
    }
  }

  void setCategory(String category) {
    state = state.copyWith(category: category);
    if (state.query.isNotEmpty) {
      executeSearch(state.query);
    }
  }

  void clearSearch() {
    state = state.copyWith(query: '', results: [], latencyMessage: '', errorMessage: null);
  }
}
