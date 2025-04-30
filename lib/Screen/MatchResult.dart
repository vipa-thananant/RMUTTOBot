class MatchResult {
  final String question;
  final double score;
  MatchResult({required this.question, required this.score});
  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      question: json['sentence'],
      score: json['score'],
    );
  }
}