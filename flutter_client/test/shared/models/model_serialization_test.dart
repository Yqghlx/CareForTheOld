import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/user_role.dart';
import 'package:care_for_the_old_client/shared/models/health_record.dart';
import 'package:care_for_the_old_client/shared/models/medication_plan.dart';

void main() {
  group('UserRole 用户角色', () {
    test('枚举值应正确', () {
      expect(UserRole.elder.value, 'elder');
      expect(UserRole.child.value, 'child');
    });

    test('isElder/isChild 属性应正确', () {
      expect(UserRole.elder.isElder, isTrue);
      expect(UserRole.elder.isChild, isFalse);
      expect(UserRole.child.isChild, isTrue);
      expect(UserRole.child.isElder, isFalse);
    });

    test('fromString 整数值解析应正确', () {
      expect(UserRole.fromString(0), UserRole.elder);
      expect(UserRole.fromString(1), UserRole.child);
    });

    test('fromString 字符串值解析应正确', () {
      expect(UserRole.fromString('elder'), UserRole.elder);
      expect(UserRole.fromString('child'), UserRole.child);
    });

    test('fromString 未知值应返回默认值', () {
      expect(UserRole.fromString('unknown'), UserRole.elder);
    });
  });

  group('HealthType 健康数据类型', () {
    test('枚举值应与后端对应', () {
      expect(HealthType.bloodPressure.value, 0);
      expect(HealthType.bloodSugar.value, 1);
      expect(HealthType.heartRate.value, 2);
      expect(HealthType.temperature.value, 3);
    });

    test('fromInt 应正确解析', () {
      expect(HealthType.fromInt(0), HealthType.bloodPressure);
      expect(HealthType.fromInt(1), HealthType.bloodSugar);
      expect(HealthType.fromInt(2), HealthType.heartRate);
      expect(HealthType.fromInt(3), HealthType.temperature);
    });

    test('fromInt null 应返回默认值', () {
      expect(HealthType.fromInt(null), HealthType.bloodPressure);
    });

    test('fromInt 越界应返回默认值', () {
      expect(HealthType.fromInt(99), HealthType.bloodPressure);
    });

    test('计量单位应正确', () {
      expect(HealthType.bloodPressure.unit, 'mmHg');
      expect(HealthType.bloodSugar.unit, 'mmol/L');
      expect(HealthType.heartRate.unit, '次/分');
      expect(HealthType.temperature.unit, '°C');
    });
  });

  group('HealthRecord 健康记录', () {
    test('fromJson 应正确解析血压记录', () {
      final json = {
        'id': 'record-1',
        'userId': 'user-1',
        'realName': '张大爷',
        'type': 0,
        'systolic': 120,
        'diastolic': 80,
        'bloodSugar': null,
        'heartRate': null,
        'temperature': null,
        'note': '饭后测量',
        'recordedAt': '2026-04-21T08:00:00Z',
        'createdAt': '2026-04-21T08:01:00Z',
      };

      final record = HealthRecord.fromJson(json);

      expect(record.id, 'record-1');
      expect(record.userId, 'user-1');
      expect(record.realName, '张大爷');
      expect(record.type, HealthType.bloodPressure);
      expect(record.systolic, 120);
      expect(record.diastolic, 80);
      expect(record.note, '饭后测量');
      expect(record.recordedAt.isUtc, isTrue);
    });

    test('fromJson 应正确解析血糖记录', () {
      final json = {
        'id': 'record-2',
        'userId': 'user-1',
        'realName': null,
        'type': 1,
        'systolic': null,
        'diastolic': null,
        'bloodSugar': 5.6,
        'heartRate': null,
        'temperature': null,
        'note': null,
        'recordedAt': '2026-04-21T09:00:00Z',
        'createdAt': '2026-04-21T09:01:00Z',
      };

      final record = HealthRecord.fromJson(json);

      expect(record.type, HealthType.bloodSugar);
      expect(record.bloodSugar, 5.6);
      expect(record.realName, isNull);
      expect(record.note, isNull);
    });

    test('displayValue 应正确格式化', () {
      final bpRecord = HealthRecord(
        id: 'r1', userId: 'u1', type: HealthType.bloodPressure,
        systolic: 130, diastolic: 85,
        recordedAt: DateTime.utc(2026, 4, 21), createdAt: DateTime.utc(2026, 4, 21),
      );
      expect(bpRecord.displayValue, '130/85');

      final hrRecord = HealthRecord(
        id: 'r2', userId: 'u1', type: HealthType.heartRate,
        heartRate: 72,
        recordedAt: DateTime.utc(2026, 4, 21), createdAt: DateTime.utc(2026, 4, 21),
      );
      expect(hrRecord.displayValue, '72');
    });
  });

  group('Frequency 用药频率', () {
    test('枚举值应与后端对应', () {
      expect(Frequency.onceDaily.value, 0);
      expect(Frequency.twiceDaily.value, 1);
      expect(Frequency.threeTimesDaily.value, 2);
      expect(Frequency.asNeeded.value, 3);
    });

    test('fromInt 应正确解析', () {
      expect(Frequency.fromInt(0), Frequency.onceDaily);
      expect(Frequency.fromInt(1), Frequency.twiceDaily);
      expect(Frequency.fromInt(null), Frequency.onceDaily);
    });
  });

  group('MedicationStatus 服药状态', () {
    test('枚举值应与后端对应', () {
      expect(MedicationStatus.taken.value, 0);
      expect(MedicationStatus.skipped.value, 1);
      expect(MedicationStatus.missed.value, 2);
    });

    test('fromInt null 应默认为漏服', () {
      expect(MedicationStatus.fromInt(null), MedicationStatus.missed);
    });
  });

  group('MedicationPlan 用药计划', () {
    test('fromJson 应正确解析', () {
      final json = {
        'id': 'plan-1',
        'elderId': 'elder-1',
        'elderName': '张大爷',
        'medicineName': '降压药',
        'dosage': '1片',
        'frequency': 1,
        'reminderTimes': ['08:00', '20:00'],
        'startDate': '2026-04-01',
        'endDate': null,
        'isActive': true,
        'createdAt': '2026-04-01T10:00:00Z',
        'updatedAt': '2026-04-01T10:00:00Z',
      };

      final plan = MedicationPlan.fromJson(json);

      expect(plan.id, 'plan-1');
      expect(plan.elderId, 'elder-1');
      expect(plan.medicineName, '降压药');
      expect(plan.dosage, '1片');
      expect(plan.frequency, Frequency.twiceDaily);
      expect(plan.reminderTimes, ['08:00', '20:00']);
      expect(plan.isActive, isTrue);
      expect(plan.endDate, isNull);
    });

    test('reminderTimesText 应正确格式化', () {
      final plan = MedicationPlan(
        id: 'p1', elderId: 'e1', medicineName: '药', dosage: '1片',
        frequency: Frequency.threeTimesDaily,
        reminderTimes: ['08:00', '14:00', '20:00'],
        startDate: DateTime(2026, 4, 1), isActive: true,
        createdAt: DateTime.utc(2026, 4, 1), updatedAt: DateTime.utc(2026, 4, 1),
      );
      expect(plan.reminderTimesText, '08:00、14:00、20:00');
    });
  });
}