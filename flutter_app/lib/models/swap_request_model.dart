class SwapRequest {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final DateTime giveDate;
  final List<DateTime> takeDates;
  final String status; // "pending" | "matched" | "done"
  final List<MatchResult> matches;

  SwapRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.giveDate,
    required this.takeDates,
    this.status = 'pending',
    this.matches = const [],
  });

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    return SwapRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userRole: json['user_role'] as String,
      giveDate: DateTime.parse(json['give_date'] as String),
      takeDates: (json['take_dates'] as List)
          .map((d) => DateTime.parse(d as String))
          .toList(),
      status: json['status'] as String? ?? 'pending',
      matches: (json['matches'] as List? ?? [])
          .map((m) => MatchResult.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'user_role': userRole,
        'give_date': giveDate.toIso8601String().split('T')[0],
        'take_dates': takeDates.map((d) => d.toIso8601String().split('T')[0]).toList(),
        'status': status,
      };
}

class MatchResult {
  final String requestId;
  final String userName;
  final DateTime giveDate;
  final List<DateTime> takeDates;

  MatchResult({
    required this.requestId,
    required this.userName,
    required this.giveDate,
    required this.takeDates,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        requestId: json['request_id'] as String,
        userName: json['user_name'] as String,
        giveDate: DateTime.parse(json['give_date'] as String),
        takeDates: (json['take_dates'] as List)
            .map((d) => DateTime.parse(d as String))
            .toList(),
      );
}