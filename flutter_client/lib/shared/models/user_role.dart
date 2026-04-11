/// 用户角色枚举
enum UserRole {
  elder('老人'),
  child('子女');

  final String label;
  const UserRole(this.label);

  String get value => name;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.elder,
    );
  }
}