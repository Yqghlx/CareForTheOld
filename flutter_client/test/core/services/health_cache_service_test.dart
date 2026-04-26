import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:care_for_the_old_client/core/services/health_cache_service.dart';
import 'package:care_for_the_old_client/shared/models/health_record.dart';
import 'package:care_for_the_old_client/shared/models/medication_plan.dart';

void main() {
  late HealthCacheService service;
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hive_health_cache_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    // 清理旧数据
    try {
      await Hive.deleteBoxFromDisk('health_cache');
    } catch (_) {}
    try {
      await Hive.deleteBoxFromDisk('medication_cache');
    } catch (_) {}

    service = HealthCacheService();
    await service.init();
  });

  group('HealthCacheService - 健康记录缓存', () {
    final testRecords = [
      HealthRecord(
        id: 'r1',
        userId: 'u1',
        type: HealthType.bloodPressure,
        systolic: 130,
        diastolic: 85,
        recordedAt: DateTime(2026, 4, 25),
        createdAt: DateTime(2026, 4, 25),
      ),
      HealthRecord(
        id: 'r2',
        userId: 'u1',
        type: HealthType.bloodSugar,
        bloodSugar: 6.5,
        recordedAt: DateTime(2026, 4, 26),
        createdAt: DateTime(2026, 4, 26),
      ),
      HealthRecord(
        id: 'r3',
        userId: 'u1',
        type: HealthType.heartRate,
        heartRate: 72,
        recordedAt: DateTime(2026, 4, 26),
        createdAt: DateTime(2026, 4, 26),
      ),
    ];

    test('缓存后读取应返回相同数据', () async {
      await service.cacheMyRecords(testRecords);
      final cached = service.getCachedMyRecords();

      expect(cached.length, 3);
      expect(cached[0].id, 'r1');
      expect(cached[0].systolic, 130);
      expect(cached[1].type, HealthType.bloodSugar);
      expect(cached[1].bloodSugar, 6.5);
      expect(cached[2].heartRate, 72);
    });

    test('空缓存应返回空列表', () {
      final cached = service.getCachedMyRecords();
      expect(cached, isEmpty);
    });

    test('按类型筛选应返回匹配记录', () async {
      await service.cacheMyRecords(testRecords);

      final bpRecords = service.getCachedRecordsByType(HealthType.bloodPressure);
      expect(bpRecords.length, 1);
      expect(bpRecords[0].systolic, 130);

      final bsRecords = service.getCachedRecordsByType(HealthType.bloodSugar);
      expect(bsRecords.length, 1);
      expect(bsRecords[0].bloodSugar, 6.5);

      final tempRecords = service.getCachedRecordsByType(HealthType.temperature);
      expect(tempRecords, isEmpty);
    });

    test('重复缓存应覆盖旧数据', () async {
      await service.cacheMyRecords(testRecords);
      expect(service.getCachedMyRecords().length, 3);

      final newRecords = [
        HealthRecord(
          id: 'r4',
          userId: 'u1',
          type: HealthType.temperature,
          temperature: 36.8,
          recordedAt: DateTime(2026, 4, 26),
          createdAt: DateTime(2026, 4, 26),
        ),
      ];
      await service.cacheMyRecords(newRecords);

      final cached = service.getCachedMyRecords();
      expect(cached.length, 1);
      expect(cached[0].id, 'r4');
    });
  });

  group('HealthCacheService - 用药计划缓存', () {
    final testPlans = [
      MedicationPlan(
        id: 'p1',
        elderId: 'e1',
        elderName: '张大爷',
        medicineName: '降压药',
        dosage: '10mg',
        frequency: Frequency.onceDaily,
        reminderTimes: ['08:00', '20:00'],
        startDate: DateTime(2026, 4, 1),
        isActive: true,
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
      ),
    ];

    test('缓存后读取应返回相同数据', () async {
      await service.cacheMedicationPlans(testPlans);
      final cached = service.getCachedMedicationPlans();

      expect(cached.length, 1);
      expect(cached[0].id, 'p1');
      expect(cached[0].medicineName, '降压药');
      expect(cached[0].frequency, Frequency.onceDaily);
      expect(cached[0].reminderTimes, ['08:00', '20:00']);
    });

    test('空缓存应返回空列表', () {
      final cached = service.getCachedMedicationPlans();
      expect(cached, isEmpty);
    });
  });

  group('HealthCacheService - 序列化完整性', () {
    test('血压记录含收缩压和舒张压', () async {
      final records = [
        HealthRecord(
          id: 'bp1',
          userId: 'u1',
          type: HealthType.bloodPressure,
          systolic: 145,
          diastolic: 92,
          note: '运动后测量',
          recordedAt: DateTime(2026, 4, 26, 10, 30),
          createdAt: DateTime(2026, 4, 26, 10, 30),
        ),
      ];
      await service.cacheMyRecords(records);
      final cached = service.getCachedMyRecords();

      expect(cached.length, 1);
      expect(cached[0].systolic, 145);
      expect(cached[0].diastolic, 92);
      expect(cached[0].note, '运动后测量');
    });

    test('体温记录含小数值', () async {
      final records = [
        HealthRecord(
          id: 't1',
          userId: 'u1',
          type: HealthType.temperature,
          temperature: 37.2,
          recordedAt: DateTime(2026, 4, 26),
          createdAt: DateTime(2026, 4, 26),
        ),
      ];
      await service.cacheMyRecords(records);
      final cached = service.getCachedMyRecords();

      expect(cached[0].temperature, closeTo(37.2, 0.01));
    });
  });
}
