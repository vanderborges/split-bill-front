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
  });

  final String expenseId;
  final String description;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final double consumed;
  final double paid;
  final double impact;

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
    );
  }
}
