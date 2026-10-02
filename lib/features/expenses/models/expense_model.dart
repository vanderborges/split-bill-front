class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.expenseDate,
    required this.category,
    required this.payerId,
    required this.payerNickname,
    required this.createdByUserId,
    required this.monthId,
    required this.eventId,
    required this.sourceEventId,
    required this.installmentGroupId,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.payers,
    required this.participants,
    required this.isSubscription,
    required this.subscriptionCancelled,
    required this.createdAt,
  });

  final String id;
  final String description;
  final double amount;
  final DateTime expenseDate;
  final String category;
  final String payerId;
  final String payerNickname;
  final String createdByUserId;
  final String? monthId;
  final String? eventId;
  final String? sourceEventId;
  final String? installmentGroupId;
  final int? installmentNumber;
  final int? totalInstallments;
  final List<ExpensePayerModel> payers;
  final List<ExpenseParticipantModel> participants;
  final bool isSubscription;
  final bool subscriptionCancelled;
  final DateTime createdAt;

  /// Rótulo "1/3", "2/3"... para despesas de fato parceladas, ou
  /// "Assinatura (mês N)" para assinaturas — despesas únicas (sem grupo,
  /// ou parceladas em 1x) retornam null. Usa os campos vindos da API em
  /// vez de recalcular, já que cada parcela/mês vive num evento diferente.
  String? get installmentLabel {
    if (installmentGroupId == null) {
      return null;
    }
    if (isSubscription) {
      final number = installmentNumber;
      final base = number == null ? 'Assinatura' : 'Assinatura (mês $number)';
      return subscriptionCancelled ? '$base — cancelada' : base;
    }
    final total = totalInstallments;
    final number = installmentNumber;
    if (total == null || total <= 1 || number == null) {
      return null;
    }
    return 'Parcela $number/$total';
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: double.parse(json['amount'].toString()),
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      category: json['category'] as String,
      payerId: json['payerId'] as String,
      payerNickname: json['payerNickname'] as String,
      createdByUserId:
          json['createdByUserId'] as String? ?? json['payerId'] as String,
      monthId: json['monthId'] as String?,
      eventId: json['eventId'] as String?,
      sourceEventId: json['sourceEventId'] as String?,
      installmentGroupId: json['installmentGroupId'] as String?,
      installmentNumber: json['installmentNumber'] as int?,
      totalInstallments: json['totalInstallments'] as int?,
      payers: (json['payers'] as List<dynamic>? ?? [])
          .map((item) =>
              ExpensePayerModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      participants: (json['participants'] as List<dynamic>)
          .map((item) =>
              ExpenseParticipantModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      isSubscription: json['isSubscription'] as bool? ?? false,
      subscriptionCancelled: json['subscriptionCancelled'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? DateTime.parse(json['expenseDate'] as String)
          : DateTime.parse(json['createdAt'] as String),
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
    required this.shareCount,
    required this.shareDescription,
  });

  final String userId;
  final String nickname;
  final double shareAmount;
  final int shareCount;
  final String? shareDescription;

  factory ExpenseParticipantModel.fromJson(Map<String, dynamic> json) {
    return ExpenseParticipantModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      shareAmount: double.parse(json['shareAmount'].toString()),
      shareCount: json['shareCount'] as int? ?? 1,
      shareDescription: json['shareDescription'] as String?,
    );
  }
}
