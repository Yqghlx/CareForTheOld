/// 统一的表单验证器
///
/// 所有验证规则与后端保持一致，避免前后端验证不匹配。
class FormValidators {
  FormValidators._();

  /// 中国手机号正则：1 开头，第二位 3-9，共 11 位
  static final _phoneRegex = RegExp(r'^1[3-9]\d{9}$');

  /// 手机号验证
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return '请输入手机号';
    if (!_phoneRegex.hasMatch(value)) return '手机号格式不正确';
    return null;
  }

  /// 密码验证：至少 8 位，必须包含字母和数字（与后端 PasswordValidator 一致）
  static String? password(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    if (value.length < 8) return '密码至少8位';
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) return '密码必须包含字母';
    if (!RegExp(r'\d').hasMatch(value)) return '密码必须包含数字';
    return null;
  }

  /// 姓名验证
  static String? name(String? value) {
    if (value == null || value.isEmpty) return '请输入姓名';
    return null;
  }

  /// 邀请码验证（6 位数字）
  static String? inviteCode(String? value) {
    if (value == null || value.isEmpty) return '请输入邀请码';
    if (value.length != 6) return '邀请码为6位数字';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return '邀请码只能为数字';
    return null;
  }
}
