import 'dart:core';
import '../domain/search_result_model.dart';
import 'search_repository.dart';

class HybridSearchEngine {
  final SearchRepository _repository;

  HybridSearchEngine(this._repository);

  Future<List<SearchResultModel>> executeHybridSearch(String userQuery, String category) async {
    final stopwatch = Stopwatch()..start();

    // 1. Generate Query Embedding
    final embedStopwatch = Stopwatch()..start();
    List<double> queryVector = [];
    try {
      queryVector = await _repository.generateEmbedding(userQuery);
    } catch (e) {
      print('[SearchEngine] Embedding generation failed. Falling back to pure FTS.');
    }
    embedStopwatch.stop();
    print('[SearchEngine] Query Embedding: ${embedStopwatch.elapsedMilliseconds}ms');

    // 2. Run Retrieval in Parallel
    final retrievalStopwatch = Stopwatch()..start();
    
    final ftsFuture = _repository.ftsSearch(userQuery, category, limit: 50);
    
    final vectorFuture = queryVector.isNotEmpty 
        ? _repository.vectorSearch(queryVector, category, limit: 50)
        : Future.value(<SearchResultModel>[]);

    final results = await Future.wait([ftsFuture, vectorFuture]);
    final ftsResults = results[0];
    final vectorResults = results[1];
    
    retrievalStopwatch.stop();
    print('[SearchEngine] DB Vector + FTS Retrieval: ${retrievalStopwatch.elapsedMilliseconds}ms');

    // 3. Execute Reciprocal Rank Fusion (RRF)
    final Map<String, SearchResultModel> fusionMap = {};

    for (int i = 0; i < ftsResults.length; i++) {
      final doc = ftsResults[i];
      final key = doc.chunkId.isNotEmpty ? doc.chunkId : doc.id;
      if (!fusionMap.containsKey(key)) {
        fusionMap[key] = doc;
      }
      fusionMap[key]!.rrfScore += 1.0 / (60.0 + (i + 1));
    }

    for (int i = 0; i < vectorResults.length; i++) {
      final doc = vectorResults[i];
      final key = doc.chunkId.isNotEmpty ? doc.chunkId : doc.id;
      if (!fusionMap.containsKey(key)) {
        fusionMap[key] = doc;
      }
      fusionMap[key]!.rrfScore += 1.0 / (60.0 + (i + 1));
    }

    // 4. Merge and sort candidate list by RRF score; select top 30 candidates.
    final candidateList = fusionMap.values.toList();
    candidateList.sort((a, b) => b.rrfScore.compareTo(a.rrfScore));
    
    final top30 = candidateList.take(30).toList();

    // 5. Cross-Encoder Reranking
    final rerankStopwatch = Stopwatch()..start();
    final rerankedList = await _repository.rerank(userQuery, top30);
    rerankStopwatch.stop();
    print('[SearchEngine] Cross-Encoder Reranking: ${rerankStopwatch.elapsedMilliseconds}ms');

    stopwatch.stop();
    print('[SearchEngine] Total Pipeline Latency: ${stopwatch.elapsedMilliseconds}ms');

    return rerankedList;
  }
}
