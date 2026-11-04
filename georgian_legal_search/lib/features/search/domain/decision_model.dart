class DecisionModel {
  final String id;
  final String caseNumber;
  final String category;
  final String date;
  final String subject;
  final String result;
  final String fullText;

  DecisionModel({
    required this.id,
    required this.caseNumber,
    required this.category,
    required this.date,
    required this.subject,
    required this.result,
    required this.fullText,
  });

  factory DecisionModel.fromMap(Map<String, dynamic> map) {
    return DecisionModel(
      id: map['id'] as String,
      caseNumber: map['case_number'] as String? ?? '',
      category: map['category'] as String? ?? '',
      date: map['date'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      result: map['result'] as String? ?? '',
      fullText: map['full_text'] as String,
    );
  }
}
