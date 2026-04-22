import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/notification_record.dart';

void main() {
  group('NotificationRecord 模型测试', () {
    Map<String, dynamic> createTestJson({Map<String, dynamic>? overrides}) {
      return {
        'id': 'notif-001',
        'type': 'MedicationReminder',
        'title': '用药提醒',
        'content': '请按时服用阿司匹林',
        'isRead': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        ...?overrides,
      };
    }

    test('fromJson 应正确解析完整数据', () {
      final record = NotificationRecord.fromJson(createTestJson());

      expect(record.id, 'notif-001');
      expect(record.type, 'MedicationReminder');
      expect(record.title, '用药提醒');
      expect(record.content, '请按时服用阿司匹林');
      expect(record.isRead, false);
    });

    test('fromJson 字段缺失时应使用默认值', () {
      final record = NotificationRecord.fromJson({
        'id': 'notif-002',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });

      expect(record.type, '');
      expect(record.title, '');
      expect(record.content, '');
      expect(record.isRead, false);
    });

    test('fromJson isRead 为 true 时应正确解析', () {
      final record = NotificationRecord.fromJson(
          createTestJson(overrides: {'isRead': true}));
      expect(record.isRead, true);
    });

    group('icon getter 测试', () {
      test('用药相关类型应返回 medication 图标', () {
        for (final type in [
          'MedicationReminder',
          'MedicationReminderFamily',
          'MedicationReminderUrgent',
          'MedicationMissed',
        ]) {
          final record = NotificationRecord.fromJson(
              createTestJson(overrides: {'type': type}));
          expect(record.icon, Icons.medication, reason: type);
        }
      });

      test('紧急呼叫类型应返回 emergency 图标', () {
        for (final type in ['EmergencyCall', 'EmergencyCallReminder']) {
          final record = NotificationRecord.fromJson(
              createTestJson(overrides: {'type': type}));
          expect(record.icon, Icons.emergency, reason: type);
        }
      });

      test('围栏警报应返回 location_off 图标', () {
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'type': 'GeoFenceAlert'}));
        expect(record.icon, Icons.location_off);
      });

      test('未知类型应返回默认 notifications 图标', () {
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'type': 'UnknownType'}));
        expect(record.icon, Icons.notifications);
      });
    });

    group('color getter 测试', () {
      test('紧急呼叫应返回红色', () {
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'type': 'EmergencyCall'}));
        expect(record.color, Colors.red);
      });

      test('围栏警报应返回紫色', () {
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'type': 'GeoFenceAlert'}));
        expect(record.color, Colors.purple);
      });

      test('未知类型应返回绿色', () {
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'type': 'CustomType'}));
        expect(record.color, Colors.green);
      });
    });

    group('formattedTime 测试', () {
      test('刚刚创建应返回 "刚刚"', () {
        final record = NotificationRecord.fromJson(createTestJson());
        expect(record.formattedTime, '刚刚');
      });

      test('30 分钟前应返回分钟前', () {
        final time = DateTime.now().subtract(const Duration(minutes: 30));
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'createdAt': time.toUtc().toIso8601String()}));
        expect(record.formattedTime, contains('分钟前'));
      });

      test('超过 7 天应返回月/日格式', () {
        final time = DateTime.now().subtract(const Duration(days: 10));
        final record = NotificationRecord.fromJson(
            createTestJson(overrides: {'createdAt': time.toUtc().toIso8601String()}));
        expect(record.formattedTime, contains('/'));
      });
    });
  });
}