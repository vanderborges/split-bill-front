class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdByUserId,
    required this.active,
  });

  final String id;
  final String name;
  final String? description;
  final String createdByUserId;
  final bool active;

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdByUserId: json['createdByUserId'] as String,
      active: json['active'] as bool,
    );
  }
}
