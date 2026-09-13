class User {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? role;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.role,
  });
}
