class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.nickname,
    required this.email,
    required this.phone,
    required this.pixKey,
    required this.admin,
    required this.active,
  });

  final String id;
  final String fullName;
  final String nickname;
  final String email;
  final String phone;
  final String pixKey;
  final bool admin;
  final bool active;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      nickname: json['nickname'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      pixKey: json['pixKey'] as String,
      admin: json['admin'] as bool,
      active: json['active'] as bool,
    );
  }
}
