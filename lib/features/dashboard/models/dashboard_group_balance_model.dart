class DashboardEventBalanceModel {
  const DashboardEventBalanceModel({
    required this.eventId,
    required this.eventName,
    required this.eventStatus,
    required this.balance,
  });

  final String eventId;
  final String eventName;
  final String eventStatus;
  final double balance;

  factory DashboardEventBalanceModel.fromJson(Map<String, dynamic> json) {
    return DashboardEventBalanceModel(
      eventId: json['eventId'] as String,
      eventName: json['eventName'] as String,
      eventStatus: json['eventStatus'] as String,
      balance: double.parse(json['balance'].toString()),
    );
  }
}

class DashboardGroupBalanceModel {
  const DashboardGroupBalanceModel({
    required this.groupId,
    required this.groupName,
    required this.events,
  });

  final String groupId;
  final String groupName;
  final List<DashboardEventBalanceModel> events;

  factory DashboardGroupBalanceModel.fromJson(Map<String, dynamic> json) {
    return DashboardGroupBalanceModel(
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((item) => DashboardEventBalanceModel.fromJson(
              item as Map<String, dynamic>))
          .toList(),
    );
  }
}
