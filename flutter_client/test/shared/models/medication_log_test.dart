import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/medication_log.dart';

void main() {
  group('MedicationLog 模型测试', () {
    Map<String, dynamic> createTestJson({Map<String, dynamic>? overrides}) {
      return {
        'id': 'log-001',
        'planId': 'plan-001',
        'medicineName': '阿司匹林',
        'elderId': 'elder-001',
        'elderName': '张大爷',
        'status': 0,
        'scheduledAt': '2026-04-22T08:00:00Z',
        'takenAt': '2026-04-22T08:05:00Z',
        'note': '饭后服用',
        ...?overrides,
      };
    }

    test('fromJson 应正确解析完整数据', () {
      final log = MedicationLog.fromJson(createTestJson());

      expect(log.id, 'log-001');
      expect(log.planId, 'plan-001');
      expect(log.medicineName, '阿司匹林');
      expect(log.elderId, 'elder-001');
      expect(log.elderName, '张大爷');
      expect(log.status.label, '已服');
      expect(log.takenAt, isNotNull);
      expect(log.note, '饭后服用');
    });

    test('fromJson 可选字段缺失时应安全处理', () {
      final log = MedicationLog.fromJson({
        'id': 'log-002',
        'planId': 'plan-002',
        'medicineName': '降压药',
        'elderId': 'elder-002',
        'status': 2,
        'scheduledAt': '2026-04-22T12:00:00Z',
      });

      expect(log.elderName, null);
      expect(log.takenAt, null);
      expect(log.note, null);
    });

    test('fromJson status 为已服时应正确解析', () {
      final log = MedicationLog.fromJson(
          createTestJson(overrides: {'status': 0}));
      expect(log.status.label, '已服');
    });

    test('fromJson status 为跳过时应正确解析', () {
      final log = MedicationLog.fromJson(
          createTestJson(overrides: {'status': 1}));
      expect(log.status.label, '跳过');
    });

    test('fromJson status 为漏服时应正确解析', () {
      final log = MedicationLog.fromJson(
          createTestJson(overrides: {'status': 2}));
      expect(log.status.label, '漏服');
    });

    test('isPending 漏服且无 takenAt 应返回 true', () {
      final log = MedicationLog.fromJson(
          createTestJson(overrides: {'status': 2, 'takenAt': null}));
      expect(log.isPending, true);
    });

    test('isPending 已服应返回 false', () {
      final log = MedicationLog.fromJson(createTestJson());
      expect(log.isPending, false);
    });

    test('isPending 跳过应返回 false', () {
      final log = MedicationLog.fromJson(
          createTestJson(overrides: {'status': 1}));
      expect(log.isPending, false);
    });
  });
}