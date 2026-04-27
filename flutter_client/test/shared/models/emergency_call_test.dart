import 'package:care_for_the_old_client/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/emergency_call.dart';

void main() {
  group('EmergencyStatus 枚举测试', () {
    test('fromInt null 应返回 pending', () {
      expect(EmergencyStatus.fromInt(null), EmergencyStatus.pending);
    });

    test('fromInt 0 应返回 pending', () {
      expect(EmergencyStatus.fromInt(0), EmergencyStatus.pending);
    });

    test('fromInt 1 应返回 responded', () {
      expect(EmergencyStatus.fromInt(1), EmergencyStatus.responded);
    });

    test('fromInt 越界应返回 pending', () {
      expect(EmergencyStatus.fromInt(99), EmergencyStatus.pending);
    });

    test('label 应正确', () {
      expect(EmergencyStatus.pending.label, '待处理');
      expect(EmergencyStatus.responded.label, '已响应');
    });
  });

  group('EmergencyCall 模型测试', () {
    // 构造标准测试数据
    Map<String, dynamic> createTestJson({Map<String, dynamic>? overrides}) {
      return {
        'id': 'call-001',
        'elderId': 'elder-001',
        'elderName': '张大爷',
        'elderPhoneNumber': '13800138000',
        'familyId': 'family-001',
        'calledAt': '2026-04-22T10:30:00Z',
        'status': 0,
        'respondedBy': null,
        'respondedByRealName': null,
        'respondedAt': null,
        'latitude': 39.9042,
        'longitude': 116.4074,
        'batteryLevel': 75,
        ...?overrides,
      };
    }

    test('fromJson 应正确解析完整数据', () {
      final call = EmergencyCall.fromJson(createTestJson());

      expect(call.id, 'call-001');
      expect(call.elderId, 'elder-001');
      expect(call.elderName, '张大爷');
      expect(call.elderPhoneNumber, '13800138000');
      expect(call.familyId, 'family-001');
      expect(call.status, EmergencyStatus.pending);
      expect(call.latitude, 39.9042);
      expect(call.longitude, 116.4074);
      expect(call.batteryLevel, 75);
      expect(call.respondedBy, null);
    });

    test('fromJson 已响应状态应正确解析', () {
      final call = EmergencyCall.fromJson(createTestJson(overrides: {
        'status': 1,
        'respondedBy': 'child-001',
        'respondedByRealName': '李小明',
        'respondedAt': '2026-04-22T10:35:00Z',
      }));

      expect(call.status, EmergencyStatus.responded);
      expect(call.respondedBy, 'child-001');
      expect(call.respondedByRealName, '李小明');
      expect(call.respondedAt, isNotNull);
    });

    test('fromJson 可选字段缺失时应安全处理', () {
      final call = EmergencyCall.fromJson({
        'id': 'call-002',
        'elderId': 'elder-002',
        'elderName': '王奶奶',
        'familyId': 'family-002',
        'calledAt': '2026-04-22T10:30:00Z',
        'status': 0,
      });

      expect(call.elderPhoneNumber, null);
      expect(call.latitude, null);
      expect(call.longitude, null);
      expect(call.batteryLevel, null);
    });

    test('isPending getter 应正确判断', () {
      final pending = EmergencyCall.fromJson(createTestJson());
      expect(pending.isPending, true);

      final responded = EmergencyCall.fromJson(
          createTestJson(overrides: {'status': 1}));
      expect(responded.isPending, false);
    });

    test('hasLocation getter 应正确判断', () {
      final withLocation = EmergencyCall.fromJson(createTestJson());
      expect(withLocation.hasLocation, true);

      final withoutLocation = EmergencyCall.fromJson(
          createTestJson(overrides: {'latitude': null, 'longitude': null}));
      expect(withoutLocation.hasLocation, false);
    });

    test('batteryText 应正确格式化', () {
      final withBattery = EmergencyCall.fromJson(createTestJson());
      expect(withBattery.batteryText, '75%');

      final noBattery = EmergencyCall.fromJson(
          createTestJson(overrides: {'batteryLevel': null}));
      expect(noBattery.batteryText, '未知');
    });

    test('batteryColor 应根据电量返回正确颜色', () {
      final high = EmergencyCall.fromJson(
          createTestJson(overrides: {'batteryLevel': 80}));
      expect(high.batteryColor, AppTheme.successColor);

      final medium = EmergencyCall.fromJson(
          createTestJson(overrides: {'batteryLevel': 30}));
      expect(medium.batteryColor, AppTheme.warningColor);

      final low = EmergencyCall.fromJson(
          createTestJson(overrides: {'batteryLevel': 10}));
      expect(low.batteryColor, AppTheme.errorColor);

      final unknown = EmergencyCall.fromJson(
          createTestJson(overrides: {'batteryLevel': null}));
      expect(unknown.batteryColor, AppTheme.grey500);
    });

    test('formattedTime 应正确格式化', () {
      final call = EmergencyCall.fromJson(createTestJson());
      // calledAt 为 UTC 2026-04-22T10:30:00Z，转换为本地时间后格式化
      final localTime = call.calledAt.toLocal();
      final expected =
          '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
          '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
      expect(call.formattedTime, expected);
    });
  });
}