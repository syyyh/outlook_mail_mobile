enum AccountStatus { validating, success, failed }

class MailAccount {
  const MailAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.clientId,
    required this.refreshToken,
    required this.rawLine,
    required this.status,
    this.errorMessage,
    this.lastCheckedAt,
    this.unreadCount = 0,
    this.isFavorite = false,
  });

  final String id;
  final String email;
  final String password;
  final String clientId;
  final String refreshToken;
  final String rawLine;
  final AccountStatus status;
  final String? errorMessage;
  final DateTime? lastCheckedAt;
  final int unreadCount;
  final bool isFavorite;

  bool get isUsable => status == AccountStatus.success;

  String get exportLine {
    if (email.isEmpty || clientId.isEmpty || refreshToken.isEmpty) {
      return rawLine;
    }
    return '$email----$password----$clientId----$refreshToken';
  }

  MailAccount copyWith({
    String? email,
    String? password,
    String? clientId,
    String? refreshToken,
    String? rawLine,
    AccountStatus? status,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastCheckedAt,
    int? unreadCount,
    bool? isFavorite,
  }) {
    return MailAccount(
      id: id,
      email: email ?? this.email,
      password: password ?? this.password,
      clientId: clientId ?? this.clientId,
      refreshToken: refreshToken ?? this.refreshToken,
      rawLine: rawLine ?? this.rawLine,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'password': password,
    'clientId': clientId,
    'refreshToken': refreshToken,
    'rawLine': rawLine,
    'status': status.name,
    'errorMessage': errorMessage,
    'lastCheckedAt': lastCheckedAt?.toIso8601String(),
    'unreadCount': unreadCount,
    'isFavorite': isFavorite,
  };

  factory MailAccount.fromJson(Map<String, dynamic> json) {
    return MailAccount(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      rawLine: json['rawLine'] as String? ?? '',
      status: AccountStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => AccountStatus.failed,
      ),
      errorMessage: json['errorMessage'] as String?,
      lastCheckedAt: DateTime.tryParse(json['lastCheckedAt'] as String? ?? ''),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      isFavorite: json['isFavorite'] == true,
    );
  }
}
