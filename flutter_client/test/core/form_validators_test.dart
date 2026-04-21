import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/core/validators/form_validators.dart';

void main() {
  group('FormValidators.phone 手机号验证', () {
    test('有效的手机号应返回 null', () {
      expect(FormValidators.phone('13800138000'), isNull);
      expect(FormValidators.phone('15912345678'), isNull);
      expect(FormValidators.phone('19999999999'), isNull);
    });

    test('null 或空值应提示输入手机号', () {
      expect(FormValidators.phone(null), '请输入手机号');
      expect(FormValidators.phone(''), '请输入手机号');
    });

    test('非 1 开头应提示格式不正确', () {
      expect(FormValidators.phone('23800138000'), '手机号格式不正确');
      expect(FormValidators.phone('0138001380'), '手机号格式不正确');
    });

    test('第二位不在 3-9 范围应提示格式不正确', () {
      expect(FormValidators.phone('12000000000'), '手机号格式不正确');
      expect(FormValidators.phone('11000000000'), '手机号格式不正确');
    });

    test('位数不对应提示格式不正确', () {
      expect(FormValidators.phone('1380013800'), '手机号格式不正确');  // 10位
      expect(FormValidators.phone('138001380000'), '手机号格式不正确'); // 12位
    });
  });

  group('FormValidators.password 密码验证', () {
    test('有效的密码应返回 null', () {
      expect(FormValidators.password('Test1234'), isNull);
      expect(FormValidators.password('abcd1234'), isNull);
      expect(FormValidators.password('ABCD1234'), isNull);
      expect(FormValidators.password('MyP@ss99'), isNull);
    });

    test('null 或空值应提示输入密码', () {
      expect(FormValidators.password(null), '请输入密码');
      expect(FormValidators.password(''), '请输入密码');
    });

    test('少于 8 位应提示至少 8 位', () {
      expect(FormValidators.password('Ab12345'), '密码至少8位');
      expect(FormValidators.password('A1b2c3'), '密码至少8位');
    });

    test('纯数字应提示必须包含字母', () {
      expect(FormValidators.password('12345678'), '密码必须包含字母');
    });

    test('纯字母应提示必须包含数字', () {
      expect(FormValidators.password('abcdefgh'), '密码必须包含数字');
      expect(FormValidators.password('ABCDEFGH'), '密码必须包含数字');
    });
  });

  group('FormValidators.name 姓名验证', () {
    test('有效的姓名应返回 null', () {
      expect(FormValidators.name('张三'), isNull);
      expect(FormValidators.name('John'), isNull);
    });

    test('null 或空值应提示输入姓名', () {
      expect(FormValidators.name(null), '请输入姓名');
      expect(FormValidators.name(''), '请输入姓名');
    });
  });

  group('FormValidators.inviteCode 邀请码验证', () {
    test('有效的邀请码应返回 null', () {
      expect(FormValidators.inviteCode('123456'), isNull);
      expect(FormValidators.inviteCode('000000'), isNull);
      expect(FormValidators.inviteCode('999999'), isNull);
    });

    test('null 或空值应提示输入邀请码', () {
      expect(FormValidators.inviteCode(null), '请输入邀请码');
      expect(FormValidators.inviteCode(''), '请输入邀请码');
    });

    test('位数不对应提示为 6 位数字', () {
      expect(FormValidators.inviteCode('12345'), '邀请码为6位数字');
      expect(FormValidators.inviteCode('1234567'), '邀请码为6位数字');
    });

    test('包含非数字应提示只能为数字', () {
      expect(FormValidators.inviteCode('12345a'), '邀请码只能为数字');
      expect(FormValidators.inviteCode('abcdef'), '邀请码只能为数字');
    });
  });
}