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
    this.receiverUserId,
    this.receiverNickname,
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

  /// Quem recebe os pagamentos (escolhido no "Fechar evento"); null =
  /// sugestão de pagamentos entre devedores e credores.
  final String? receiverUserId;
  final String? receiverNickname;

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

  /// Ordem da Home e do seletor de evento: aguardando pagamento primeiro,
  /// depois abertos, depois fechados; dentro de cada um, do mais recente
  /// pro mais antigo.
  static int compareSettlingFirst(EventModel a, EventModel b) {
    int rank(EventModel event) => event.isSettling ? 0 : (event.isOpen ? 1 : 2);
    final byStatus = rank(a).compareTo(rank(b));
    if (byStatus != 0) {
      return byStatus;
    }
    final byDate = b.sortDate.compareTo(a.sortDate);
    if (byDate != 0) {
      return byDate;
    }
    return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
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
      receiverUserId: json['receiverUserId'] as String?,
      receiverNickname: json['receiverNickname'] as String?,
    );
  }
}
