/// Próxima parcela/assinatura do mês anterior que só entra no mês novo se a
/// pessoa quiser (ver `askInstallmentsToContinue`).
class PendingInstallmentModel {
  const PendingInstallmentModel({
    required this.installmentGroupId,
    required this.description,
    required this.amount,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.subscription,
  });

  final String installmentGroupId;
  final String description;
  final double amount;
  final int installmentNumber;
  final int? totalInstallments;
  final bool subscription;

  String get label => subscription
      ? 'Assinatura'
      : 'Parcela $installmentNumber de $totalInstallments';

  factory PendingInstallmentModel.fromJson(Map<String, dynamic> json) {
    return PendingInstallmentModel(
      installmentGroupId: json['installmentGroupId'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      installmentNumber: json['installmentNumber'] as int,
      totalInstallments: json['totalInstallments'] as int?,
      subscription: json['subscription'] as bool,
    );
  }
}
