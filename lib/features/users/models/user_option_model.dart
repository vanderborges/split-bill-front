class UserOptionModel {
  const UserOptionModel({
    required this.id,
    required this.nickname,
    required this.active,
  });

  final String id;
  final String nickname;
  final bool active;

  factory UserOptionModel.fromJson(Map<String, dynamic> json) {
    return UserOptionModel(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      active: json['active'] as bool,
    );
  }
}
