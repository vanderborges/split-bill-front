class EventSettlementModel {
  const EventSettlementModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.nickname,
    required this.role,
    required this.amount,
    required this.status,
  });

  final String id;
  final String eventId;
  final String userId;
  final String nickname;
  final String role;
  final double amount;
  final String status;

  String get roleLabel {
    return switch (role) {
      'DEBTOR' => 'Paga',
      'CREDITOR' => 'Recebe',
      _ => 'Neutro',
    };
  }

  String get statusLabel {
    return switch (normalizedStatus) {
      'PENDING' => 'Pendente',
      'PAID' => 'Pago',
      _ => status,
    };
  }

  String get normalizedStatus {
    return switch (status) {
      'PAID_TO_ADMIN' || 'RECEIVED_FROM_ADMIN' || 'CONFIRMED' => 'PAID',
      _ => status,
    };
  }

  factory EventSettlementModel.fromJson(Map<String, dynamic> json) {
    return EventSettlementModel(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String,
      amount: double.parse(json['amount'].toString()),
      status: json['status'] as String,
    );
  }
}
