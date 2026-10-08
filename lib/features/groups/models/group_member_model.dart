class GroupMemberModel {
  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.role,
    required this.active,
    this.temporary = false,
    this.temporaryEventId,
    this.temporaryEventName,
    this.temporaryEventStatus,
  });

  final String id;
  final String groupId;
  final String userId;
  final String nickname;
  final String role;
  final bool active;

  /// Pessoa temporária: só participa do evento [temporaryEventId]. Quando
  /// esse evento fecha ela some das listas, mas continua no grupo e pode
  /// ser reativada em outro evento.
  final bool temporary;
  final String? temporaryEventId;
  final String? temporaryEventName;
  final String? temporaryEventStatus;

  String get roleLabel {
    if (temporary) {
      return temporaryEventName == null
          ? 'Temporário'
          : 'Temporário · $temporaryEventName';
    }
    return role == 'ADMIN' ? 'Admin' : 'Integrante';
  }

  bool get temporaryEventClosed => temporaryEventStatus == 'CLOSED';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String,
      active: json['active'] as bool,
      temporary: json['temporary'] as bool? ?? false,
      temporaryEventId: json['temporaryEventId'] as String?,
      temporaryEventName: json['temporaryEventName'] as String?,
      temporaryEventStatus: json['temporaryEventStatus'] as String?,
    );
  }
}
