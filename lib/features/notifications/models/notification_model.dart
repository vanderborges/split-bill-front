class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.message,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String? eventId;
  final String? eventName;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String?,
      eventName: json['eventName'] as String?,
      message: json['message'] as String,
      // O backend manda createdAt/readAt como instante UTC (sufixo "Z") -
      // toLocal() converte pro fuso do aparelho, pra exibir o horário que
      // a pessoa realmente vê no relógio dela, não o horário do servidor.
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String).toLocal(),
    );
  }
}
