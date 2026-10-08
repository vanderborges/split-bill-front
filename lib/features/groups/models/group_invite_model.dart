class GroupInviteModel {
  const GroupInviteModel({
    required this.id,
    required this.groupId,
    required this.createdByUserId,
    required this.active,
    required this.createdAt,
    this.eventId,
  });

  final String id;
  final String groupId;
  final String createdByUserId;
  final bool active;
  final DateTime createdAt;

  /// Convite temporário: evento ao qual quem entrar fica amarrado.
  final String? eventId;

  factory GroupInviteModel.fromJson(Map<String, dynamic> json) {
    return GroupInviteModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      createdByUserId: json['createdByUserId'] as String,
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      eventId: json['eventId'] as String?,
    );
  }
}
