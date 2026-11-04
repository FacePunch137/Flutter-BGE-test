import '../../../core/database/database_client.dart';
import '../../../core/onnx/onnx_inference_service.dart';
import '../domain/decision_model.dart';
import '../domain/search_result_model.dart';

class SearchRepository {
  final DatabaseClient _dbClient;
  final OnnxInferenceService _onnxService;

  SearchRepository(this._dbClient, this._onnxService);

  Future<void> init() async {
    await _dbClient.init();
    await _onnxService.init();
  }

  Future<List<SearchResultModel>> ftsSearch(String query, String category, {int limit = 50}) async {
    final rawResults = await _dbClient.rawFtsSearch(query, category, limit: limit);
    return rawResults.map((map) => SearchResultModel.fromMap(map)).toList();
  }

  Future<List<SearchResultModel>> vectorSearch(List<double> queryVector, String category, {int limit = 50}) async {
    final rawResults = await _dbClient.rawVectorSearch(queryVector, category, limit: limit);
    return rawResults.map((map) => SearchResultModel.fromMap(map)).toList();
  }

  Future<List<double>> generateEmbedding(String query) async {
    return await _onnxService.generateQueryEmbedding(query);
  }

  Future<List<SearchResultModel>> rerank(String query, List<SearchResultModel> candidates) async {
    return await _onnxService.rerankCandidates(query, candidates);
  }

  Future<DecisionModel?> getFullDecision(String caseId, String category) async {
    final map = await _dbClient.getFullDecisionText(caseId, category);
    if (map != null) {
      return DecisionModel.fromMap(map);
    }
    return null;
  }
}
