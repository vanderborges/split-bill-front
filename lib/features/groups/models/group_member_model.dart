class GroupMemberModel {
  const GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.role,
    required this.active,
  });

  final String id;
  final String groupId;
  final String userId;
  final String nickname;
  final String role;
  final bool active;

  String get roleLabel => role == 'ADMIN' ? 'Admin' : 'Integrante';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String,
      active: json['active'] as bool,
    );
  }
}
