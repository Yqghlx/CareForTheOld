/// 用户角色枚举
enum UserRole {
  elder('老人'),
  child('子女');

  final String label;
  const UserRole(this.label);

  String get value => name;

  bool get isElder => this == UserRole.elder;
  bool get isChild => this == UserRole.child;

  /// 从字符串解析角色（兼容字符串和整数值）
  static UserRole fromString(dynamic value) {
    // 处理后端返回的整数枚举值（C# 默认序列化行为）
    if (value is int) {
      return UserRole.values[value];
    }
    // 处理字符串形式
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.elder,
    );
  }
}