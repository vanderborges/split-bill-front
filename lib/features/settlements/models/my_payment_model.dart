/// Botão "Pagar" do Relatório: o acerto de quem está logado, com o mesmo
/// texto da notificação de cobrança e a chave PIX (só quando há um único
/// destinatário).
class MyPaymentModel {
  const MyPaymentModel({
    required this.settlementId,
    required this.status,
    required this.amount,
    required this.message,
    required this.pixKey,
    required this.receiverName,
  });

  final String settlementId;
  final String status;
  final double amount;
  final String message;
  final String? pixKey;
  final String? receiverName;

  factory MyPaymentModel.fromJson(Map<String, dynamic> json) {
    return MyPaymentModel(
      settlementId: json['settlementId'] as String,
      status: json['status'] as String,
      amount: double.parse(json['amount'].toString()),
      message: json['message'] as String,
      pixKey: json['pixKey'] as String?,
      receiverName: json['receiverName'] as String?,
    );
  }
}
