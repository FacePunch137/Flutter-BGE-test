import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';

import '../../features/search/domain/search_result_model.dart';

class OnnxInferenceService {
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      OrtEnv.instance.init();
      _isInitialized = true;
    } catch (e) {
      print('[OnnxInferenceService] Init failed: $e');
    }
  }

  // --- STUB TOKENIZER ---
  // BGE-M3 requires an XLM-RoBERTa (SentencePiece) tokenizer.
  // Implementing this pure Dart is non-trivial. In a production app,
  // we would use a Rust FFI binding (e.g. `dart_tokenizers`) or
  // pass strings if the ONNX model embeds the tokenizer.
  Map<String, List<int>> _stubTokenize(String text, {int maxLength = 512}) {
    // This is a naive stub that just creates fake tokens.
    // Replace with a real tokenizer implementation.
    final tokens = List<int>.filled(maxLength, 0);
    final attentionMask = List<int>.filled(maxLength, 0);
    
    // Fake tokenization logic just to satisfy ONNX input shape
    tokens[0] = 101; // CLS
    for (int i = 0; i < text.length && i < maxLength - 2; i++) {
      tokens[i+1] = text.codeUnitAt(i) % 30000;
      attentionMask[i+1] = 1;
    }
    tokens[maxLength - 1] = 102; // SEP
    attentionMask[0] = 1;
    attentionMask[maxLength - 1] = 1;

    return {
      'input_ids': tokens,
      'attention_mask': attentionMask,
    };
  }

  Future<String> _getModelPath(String assetPath, String fileName) async {
    // Bypass rootBundle for massive ONNX models on desktop prototype
    final absolutePath = r'C:\Coding Projects\PROTOTYPE XKIL\georgian_legal_search\assets\models\' + fileName;
    if (!File(absolutePath).existsSync()) {
      print('[OnnxInferenceService] Warning: Model not found at $absolutePath');
    }
    return absolutePath;
  }

  Future<List<double>> generateQueryEmbedding(String queryText) async {
    if (!_isInitialized) return [];

    OrtSession? session;
    try {
      final modelPath = await _getModelPath('assets/models/bge-m3.onnx', 'bge-m3.onnx');
      if (!File(modelPath).existsSync()) {
        throw Exception('Model file not found');
      }

      final sessionOptions = OrtSessionOptions();
      final modelBytes = await File(modelPath).readAsBytes();
      session = OrtSession.fromBuffer(modelBytes, sessionOptions);

      final tokenized = _stubTokenize(queryText);
      final inputIds = tokenized['input_ids']!;
      final attentionMask = tokenized['attention_mask']!;

      final runOptions = OrtRunOptions();
      
      // Typical inputs for BGE-M3
      final inputs = {
        'input_ids': OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(inputIds.map((e) => e).toList()), [1, inputIds.length]
        ),
        'attention_mask': OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(attentionMask.map((e) => e).toList()), [1, attentionMask.length]
        ),
      };

      final outputs = session.run(runOptions, inputs);
      
      // Get the embeddings from outputs (usually first element or 'sentence_embedding')
      // BGE-M3 output is [1, 1024]
      // Helper to safely extract the [CLS] token embedding from multi-dimensional ONNX outputs
      List<double> extractClsEmbedding(dynamic tensorData) {
        if (tensorData is List && tensorData.isNotEmpty) {
          if (tensorData[0] is num) {
            return tensorData.map((e) => (e as num).toDouble()).toList();
          } else if (tensorData[0] is List) {
            // If it's [1, 1024], returning tensorData[0] extracts the 1024 list.
            // If it's [1, seq_len, 1024], returning tensorData[0][0] extracts the CLS token (first token).
            return extractClsEmbedding(tensorData[0]); 
          }
        }
        return [];
      }

      final outputValue = outputs.first?.value;
      return extractClsEmbedding(outputValue);
    } catch (e) {
      print('[OnnxInferenceService] Embeddings error: $e');
      return [];
    } finally {
      // IMMEDIATELY CLOSE SESSION TO FREE RAM
      session?.release();
    }
  }

  Future<List<SearchResultModel>> rerankCandidates(String queryText, List<SearchResultModel> candidates) async {
    if (!_isInitialized || candidates.isEmpty) return candidates;

    OrtSession? session;
    try {
      final modelPath = await _getModelPath('assets/models/bge-reranker-v2-m3.onnx', 'bge-reranker-v2-m3.onnx');
      if (!File(modelPath).existsSync()) {
        throw Exception('Reranker model file not found');
      }

      final sessionOptions = OrtSessionOptions();
      final modelBytes = await File(modelPath).readAsBytes();
      session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      final runOptions = OrtRunOptions();

      // Process individually or batch if supported by the wrapper
      for (var candidate in candidates) {
        // Cross-encoder tokenization pairs Query + Document
        final pairedText = queryText + " [SEP] " + candidate.chunkText;
        final tokenized = _stubTokenize(pairedText);
        final inputIds = tokenized['input_ids']!;
        final attentionMask = tokenized['attention_mask']!;

        final inputs = {
          'input_ids': OrtValueTensor.createTensorWithDataList(
            Int64List.fromList(inputIds.map((e) => e).toList()), [1, inputIds.length]
          ),
          'attention_mask': OrtValueTensor.createTensorWithDataList(
            Int64List.fromList(attentionMask.map((e) => e).toList()), [1, attentionMask.length]
          ),
        };

        final outputs = session.run(runOptions, inputs);
        final outputValue = outputs.first?.value;
        
        // Reranker usually returns a single logit per pair [1, 1]
        double score = 0.0;
        if (outputValue is List) {
          if (outputValue.isNotEmpty && outputValue[0] is List) {
            score = (outputValue[0][0] as num).toDouble();
          } else if (outputValue.isNotEmpty) {
            score = (outputValue[0] as num).toDouble();
          }
        }
        candidate.rerankScore = score;
      }

      // Sort by rerank score descending
      candidates.sort((a, b) => b.rerankScore.compareTo(a.rerankScore));
      // Return top 20
      return candidates.take(20).toList();
    } catch (e) {
      print('[OnnxInferenceService] Reranking error: $e');
      return candidates;
    } finally {
      // IMMEDIATELY CLOSE SESSION TO FREE RAM
      session?.release();
    }
  }
}
