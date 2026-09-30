class PaymentSuggestionModel {
  const PaymentSuggestionModel({
    required this.fromUserId,
    required this.fromNickname,
    required this.toUserId,
    required this.toNickname,
    required this.amount,
  });

  final String fromUserId;
  final String fromNickname;
  final String toUserId;
  final String toNickname;
  final double amount;

  factory PaymentSuggestionModel.fromJson(Map<String, dynamic> json) {
    return PaymentSuggestionModel(
      fromUserId: json['fromUserId'] as String,
      fromNickname: json['fromNickname'] as String,
      toUserId: json['toUserId'] as String,
      toNickname: json['toNickname'] as String,
      amount: double.parse(json['amount'].toString()),
    );
  }
}
