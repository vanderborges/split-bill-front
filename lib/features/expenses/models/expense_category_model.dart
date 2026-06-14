class ExpenseCategoryModel {
  const ExpenseCategoryModel({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
