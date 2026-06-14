class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.expenseDate,
    required this.category,
    required this.payerId,
    required this.payerNickname,
    required this.monthId,
    required this.eventId,
    required this.sourceEventId,
    required this.installmentGroupId,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.payers,
    required this.participants,
  });

  final String id;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final String category;
  final String payerId;
  final String payerNickname;
  final String? monthId;
  final String? eventId;
  final String? sourceEventId;
  final String? installmentGroupId;
  final int? installmentNumber;
  final int? totalInstallments;
  final List<ExpensePayerModel> payers;
  final List<ExpenseParticipantModel> participants;

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: double.parse(json['amount'].toString()),
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      category: json['category'] as String,
      payerId: json['payerId'] as String,
      payerNickname: json['payerNickname'] as String,
      monthId: json['monthId'] as String?,
      eventId: json['eventId'] as String?,
      sourceEventId: json['sourceEventId'] as String?,
      installmentGroupId: json['installmentGroupId'] as String?,
      installmentNumber: json['installmentNumber'] as int?,
      totalInstallments: json['totalInstallments'] as int?,
      payers: (json['payers'] as List<dynamic>? ?? [])
          .map((item) => ExpensePayerModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      participants: (json['participants'] as List<dynamic>)
          .map((item) => ExpenseParticipantModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExpensePayerModel {
  const ExpensePayerModel({
    required this.userId,
    required this.nickname,
    required this.amount,
  });

  final String userId;
  final String nickname;
  final double amount;

  factory ExpensePayerModel.fromJson(Map<String, dynamic> json) {
    return ExpensePayerModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class ExpenseParticipantModel {
  const ExpenseParticipantModel({
    required this.userId,
    required this.nickname,
    required this.shareAmount,
  });

  final String userId;
  final String nickname;
  final double shareAmount;

  factory ExpenseParticipantModel.fromJson(Map<String, dynamic> json) {
    return ExpenseParticipantModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      shareAmount: double.parse(json['shareAmount'].toString()),
    );
  }
}
