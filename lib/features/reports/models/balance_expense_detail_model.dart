class BalanceExpenseDetailModel {
  const BalanceExpenseDetailModel({
    required this.expenseId,
    required this.description,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.consumed,
    required this.paid,
    required this.impact,
    this.installmentNumber,
    this.totalInstallments,
    this.isSubscription = false,
    this.subscriptionCancelled = false,
    this.shareCount = 1,
    this.totalShares = 1,
    this.shareDescription,
  });

  final String expenseId;
  final String description;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final double consumed;
  final double paid;
  final double impact;
  final int? installmentNumber;
  final int? totalInstallments;
  final bool isSubscription;
  final bool subscriptionCancelled;

  /// Cotas de quem está sendo detalhado, total de cotas da despesa e o
  /// motivo informado no cadastro (ex.: "levou acompanhante").
  final int shareCount;
  final int totalShares;
  final String? shareDescription;

  /// Título enxuto pro relatório: parcela vai junto da descrição
  /// ("Capa Chuva 01/04") em vez de numa linha separada.
  String get title {
    final total = totalInstallments;
    final number = installmentNumber;
    if (isSubscription || total == null || total <= 1 || number == null) {
      return description;
    }
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '$description ${twoDigits(number)}/${twoDigits(total)}';
  }

  /// Só para assinatura, e sem o "mês N" — no relatório o número do mês
  /// não ajuda e só polui. Parcela já aparece no [title].
  String? get installmentLabel {
    if (!isSubscription) {
      return null;
    }
    return subscriptionCancelled ? 'Assinatura — cancelada' : 'Assinatura';
  }

  /// "2 de 5 cotas — levou acompanhante". Só aparece quando a pessoa tem
  /// mais de uma cota ou há motivo registrado — cota única sem motivo é o
  /// caso comum e não precisa de explicação.
  String? get shareLabel {
    final description = shareDescription?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    if (shareCount <= 1 && !hasDescription) {
      return null;
    }
    final unit = totalShares == 1 ? 'cota' : 'cotas';
    final base = '$shareCount de $totalShares $unit';
    return hasDescription ? '$base — $description' : base;
  }

  factory BalanceExpenseDetailModel.fromJson(Map<String, dynamic> json) {
    return BalanceExpenseDetailModel(
      expenseId: json['expenseId'] as String,
      description: json['description'] as String,
      expenseDate: DateTime.parse(json['expenseDate'] as String),
      category: json['category'] as String,
      amount: double.parse(json['amount'].toString()),
      consumed: double.parse(json['consumed'].toString()),
      paid: double.parse(json['paid'].toString()),
      impact: double.parse(json['impact'].toString()),
      installmentNumber: json['installmentNumber'] as int?,
      totalInstallments: json['totalInstallments'] as int?,
      isSubscription: json['subscription'] as bool? ?? false,
      subscriptionCancelled: json['subscriptionCancelled'] as bool? ?? false,
      shareCount: json['shareCount'] as int? ?? 1,
      totalShares: json['totalShares'] as int? ?? 1,
      shareDescription: json['shareDescription'] as String?,
    );
  }
}
