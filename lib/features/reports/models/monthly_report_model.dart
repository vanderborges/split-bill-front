class MonthlyReportModel {
  const MonthlyReportModel({
    required this.monthId,
    required this.eventId,
    required this.eventName,
    required this.month,
    required this.year,
    required this.status,
    required this.totalExpenses,
    required this.balances,
  });

  final String? monthId;
  final String? eventId;
  final String? eventName;
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
      month: json['month'] as int,
      year: json['year'] as int,
      status: json['status'] as String? ?? 'OPEN',
      totalExpenses: double.parse(json['totalExpenses'].toString()),
      balances: (json['balances'] as List<dynamic>)
          .map((item) => MonthlyBalanceModel.fromJson(item as Map<String, dynamic>))
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
  });

  final String userId;
  final String nickname;
  final double totalConsumed;
  final double totalPaid;
  final double balance;

  factory MonthlyBalanceModel.fromJson(Map<String, dynamic> json) {
    return MonthlyBalanceModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      totalConsumed: double.parse(json['totalConsumed'].toString()),
      totalPaid: double.parse(json['totalPaid'].toString()),
      balance: double.parse(json['balance'].toString()),
    );
  }
}
