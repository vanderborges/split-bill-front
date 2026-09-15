class GroupInvitePreviewModel {
  const GroupInvitePreviewModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.active,
  });

  final String id;
  final String groupId;
  final String groupName;
  final bool active;

  factory GroupInvitePreviewModel.fromJson(Map<String, dynamic> json) {
    return GroupInvitePreviewModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      active: json['active'] as bool,
    );
  }
}
