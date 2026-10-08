class GroupInvitePreviewModel {
  const GroupInvitePreviewModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.active,
    this.eventId,
    this.eventName,
  });

  final String id;
  final String groupId;
  final String groupName;
  final bool active;

  /// Preenchidos só em convite temporário (entra só para esse evento).
  final String? eventId;
  final String? eventName;

  factory GroupInvitePreviewModel.fromJson(Map<String, dynamic> json) {
    return GroupInvitePreviewModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      active: json['active'] as bool,
      eventId: json['eventId'] as String?,
      eventName: json['eventName'] as String?,
    );
  }
}
