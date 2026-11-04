class SearchResultModel {
  final String id;
  final String caseNumber;
  final String date;
  final String result;
  
  final String chunkId;
  final String chunkText;
  
  final double vectorScore;
  final double ftsScore;
  double rrfScore;
  double rerankScore;

  SearchResultModel({
    required this.id,
    required this.caseNumber,
    required this.date,
    required this.result,
    required this.chunkId,
    required this.chunkText,
    this.vectorScore = 0.0,
    this.ftsScore = 0.0,
    this.rrfScore = 0.0,
    this.rerankScore = 0.0,
  });

  factory SearchResultModel.fromMap(Map<String, dynamic> map) {
    return SearchResultModel(
      id: map['id'] as String? ?? '',
      caseNumber: map['case_number'] as String? ?? 'Unknown',
      date: map['date'] as String? ?? '',
      result: map['result'] as String? ?? '',
      chunkId: map['chunk_id'] as String? ?? '',
      chunkText: map['chunk_text'] as String? ?? map['snippet'] as String? ?? '',
    );
  }
}
