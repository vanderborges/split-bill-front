class DashboardGroupBalanceModel {
  const DashboardGroupBalanceModel({
    required this.groupId,
    required this.groupName,
    required this.balance,
  });

  final String groupId;
  final String groupName;
  final double balance;

  factory DashboardGroupBalanceModel.fromJson(Map<String, dynamic> json) {
    return DashboardGroupBalanceModel(
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      balance: double.parse(json['balance'].toString()),
    );
  }
}
