class UserData {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final List<String> permissions;

  UserData({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.permissions,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }
}