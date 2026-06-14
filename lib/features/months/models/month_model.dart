class MonthModel {
  const MonthModel({
    required this.id,
    required this.eventId,
    required this.month,
    required this.year,
    required this.status,
  });

  final String id;
  final String? eventId;
  final int month;
  final int year;
  final String status;

  String get label => '${month.toString().padLeft(2, '0')}/$year';

  factory MonthModel.fromJson(Map<String, dynamic> json) {
    return MonthModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String?,
      month: json['month'] as int,
      year: json['year'] as int,
      status: json['status'] as String,
    );
  }
}
