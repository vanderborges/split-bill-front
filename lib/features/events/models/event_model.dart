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
    this.createdAt,
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
  final DateTime? createdAt;

  bool get isClosed => status == 'CLOSED';

  bool get isOpen => status == 'OPEN';

  /// Aberto para pagamento: despesas congeladas, aguardando confirmação de
  /// todo mundo antes do fechamento definitivo.
  bool get isSettling => status == 'SETTLING';

  /// Referência pra ordenar do mais recente pro mais antigo: mês/ano do
  /// evento mensal; data de criação do avulso.
  DateTime get sortDate {
    if (month != null && year != null) {
      return DateTime(year!, month!);
    }
    return createdAt ?? DateTime(0);
  }

  String get typeLabel {
    return switch (type) {
      'MONTHLY' => 'Mensal',
      'SPORADIC' => 'Avulso',
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
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}
