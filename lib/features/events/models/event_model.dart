class EventModel {
  const EventModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.groupId,
    required this.monthId,
    required this.month,
    required this.year,
  });

  final String id;
  final String name;
  final String? description;
  final String type;
  final String status;
  final String groupId;
  final String? monthId;
  final int? month;
  final int? year;

  bool get isClosed => status == 'CLOSED';

  String get typeLabel {
    return switch (type) {
      'MONTHLY' => 'Mensal',
      'SPORADIC' => 'Esporadico',
      _ => type,
    };
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: json['type'] as String,
      status: json['status'] as String,
      groupId: json['groupId'] as String,
      monthId: json['monthId'] as String?,
      month: json['month'] as int?,
      year: json['year'] as int?,
    );
  }
}
