import '../../expenses/models/expense_model.dart';

class UserExpenseSummaryModel {
  const UserExpenseSummaryModel({
    required this.userId,
    required this.nickname,
    required this.from,
    required this.to,
    required this.totalConsumed,
    required this.totalPaid,
    required this.balance,
    required this.expenses,
  });

  final String? userId;
  final String nickname;
  final DateTime from;
  final DateTime to;
  final double totalConsumed;
  final double totalPaid;
  final double balance;
  final List<ExpenseModel> expenses;

  factory UserExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    return UserExpenseSummaryModel(
      userId: json['userId'] as String?,
      nickname: json['nickname'] as String,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      totalConsumed: double.parse(json['totalConsumed'].toString()),
      totalPaid: double.parse(json['totalPaid'].toString()),
      balance: double.parse(json['balance'].toString()),
      expenses: (json['expenses'] as List<dynamic>)
          .map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
