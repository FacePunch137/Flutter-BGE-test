import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_client.dart';
import '../../../../core/onnx/onnx_inference_service.dart';
import '../../data/search_repository.dart';
import '../../data/hybrid_search_engine.dart';
import 'search_notifier.dart';
import 'document_notifier.dart';

// Core Services
final databaseClientProvider = Provider<DatabaseClient>((ref) {
  return DatabaseClient();
});

final onnxInferenceServiceProvider = Provider<OnnxInferenceService>((ref) {
  return OnnxInferenceService();
});

// Repository & Engine
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final db = ref.watch(databaseClientProvider);
  final onnx = ref.watch(onnxInferenceServiceProvider);
  return SearchRepository(db, onnx);
});

final hybridSearchEngineProvider = Provider<HybridSearchEngine>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return HybridSearchEngine(repo);
});

// State Notifiers
final searchNotifierProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final engine = ref.watch(hybridSearchEngineProvider);
  return SearchNotifier(engine);
});

final documentNotifierProvider = StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  final repo = ref.watch(searchRepositoryProvider);
  return DocumentNotifier(repo);
});
