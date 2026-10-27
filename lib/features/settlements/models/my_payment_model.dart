/// Botão "Pagar" do Relatório: o acerto de quem está logado, com o mesmo
/// texto da notificação de cobrança e a chave PIX (só quando há um único
/// destinatário). [headline] e [payees] montam o pop-up linha a linha.
class MyPaymentModel {
  const MyPaymentModel({
    required this.settlementId,
    required this.status,
    required this.amount,
    required this.message,
    required this.pixKey,
    required this.receiverName,
    this.headline,
    this.payees = const [],
  });

  final String settlementId;
  final String status;
  final double amount;
  final String message;
  final String? pixKey;
  final String? receiverName;

  /// Valor devido no evento ("Grupo: no evento X, você tem R$ Y pendente.").
  final String? headline;

  /// Para quem pagar: um item por pessoa, com valor e chave PIX.
  final List<PayeeModel> payees;

  factory MyPaymentModel.fromJson(Map<String, dynamic> json) {
    return MyPaymentModel(
      settlementId: json['settlementId'] as String,
      status: json['status'] as String,
      amount: double.parse(json['amount'].toString()),
      message: json['message'] as String,
      pixKey: json['pixKey'] as String?,
      receiverName: json['receiverName'] as String?,
      headline: json['headline'] as String?,
      payees: (json['payees'] as List<dynamic>? ?? [])
          .map((item) => PayeeModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PayeeModel {
  const PayeeModel({
    required this.name,
    required this.amount,
    required this.pixKey,
  });

  final String name;
  final double amount;
  final String? pixKey;

  factory PayeeModel.fromJson(Map<String, dynamic> json) {
    return PayeeModel(
      name: json['name'] as String,
      amount: double.parse(json['amount'].toString()),
      pixKey: json['pixKey'] as String?,
    );
  }
}
