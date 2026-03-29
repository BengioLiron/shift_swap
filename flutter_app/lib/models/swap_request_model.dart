class SwapRequest {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String giveDay;
  final List<String> takeDays;
  final String status; // "pending" | "matched" | "done"
  final List<MatchResult> matches;

  SwapRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.giveDay,
    required this.takeDays,
    this.status = 'pending',
    this.matches = const [],
  });

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    return SwapRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userRole: json['user_role'] as String,
      giveDay: json['give_day'] as String,
      takeDays: List<String>.from(json['take_days'] as List),
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
        'give_day': giveDay,
        'take_days': takeDays,
        'status': status,
      };
}

class MatchResult {
  final String requestId;
  final String userName;
  final String giveDay;
  final List<String> takeDays;

  MatchResult({
    required this.requestId,
    required this.userName,
    required this.giveDay,
    required this.takeDays,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        requestId: json['request_id'] as String,
        userName: json['user_name'] as String,
        giveDay: json['give_day'] as String,
        takeDays: List<String>.from(json['take_days'] as List),
      );
}