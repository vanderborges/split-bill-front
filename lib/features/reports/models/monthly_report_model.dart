class MonthlyReportModel {
  const MonthlyReportModel({
    required this.monthId,
    required this.eventId,
    required this.eventName,
    required this.groupId,
    required this.groupName,
    required this.month,
    required this.year,
    required this.status,
    required this.totalExpenses,
    required this.balances,
  });

  final String? monthId;
  final String? eventId;
  final String? eventName;
  final String groupId;
  final String groupName;
  final int month;
  final int year;
  final String status;
  final double totalExpenses;
  final List<MonthlyBalanceModel> balances;

  factory MonthlyReportModel.fromJson(Map<String, dynamic> json) {
    return MonthlyReportModel(
      monthId: json['monthId'] as String?,
      eventId: json['eventId'] as String?,
      eventName: json['eventName'] as String?,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      status: json['status'] as String? ?? 'OPEN',
      totalExpenses: double.parse(json['totalExpenses'].toString()),
      balances: (json['balances'] as List<dynamic>)
          .map((item) =>
              MonthlyBalanceModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthlyBalanceModel {
  const MonthlyBalanceModel({
    required this.userId,
    required this.nickname,
    required this.totalConsumed,
    required this.totalPaid,
    required this.balance,
    this.pixKey,
    this.members = const [],
  });

  final String userId;
  final String nickname;
  final double totalConsumed;
  final double totalPaid;
  final double balance;

  /// Chave PIX da pessoa (para o texto de compartilhar); null = sem chave.
  final String? pixKey;

  /// Quem está somado nesta linha: o titular e quem tem cobrança vinculada
  /// a ele (backend antigo não manda: lista vazia).
  final List<BalanceMemberModel> members;

  /// Pessoas com gasto neste evento (as outras não entram no "Você + ...").
  List<BalanceMemberModel> get activeMembers =>
      members.where((member) => member.active).toList();

  /// Linha que inclui [userId] (titular ou vinculado).
  bool includes(String? userId) =>
      userId != null &&
      (this.userId == userId ||
          members.any((member) => member.userId == userId));

  factory MonthlyBalanceModel.fromJson(Map<String, dynamic> json) {
    return MonthlyBalanceModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      totalConsumed: double.parse(json['totalConsumed'].toString()),
      totalPaid: double.parse(json['totalPaid'].toString()),
      balance: double.parse(json['balance'].toString()),
      pixKey: json['pixKey'] as String?,
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((item) =>
              BalanceMemberModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Uma pessoa dentro da linha de saldo de um titular de cobrança, com o
/// saldo só dela.
class BalanceMemberModel {
  const BalanceMemberModel({
    required this.userId,
    required this.nickname,
    required this.balance,
    required this.active,
  });

  final String userId;
  final String nickname;
  final double balance;
  final bool active;

  factory BalanceMemberModel.fromJson(Map<String, dynamic> json) {
    return BalanceMemberModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      balance: double.parse(json['balance'].toString()),
      active: json['active'] as bool? ?? true,
    );
  }
}
