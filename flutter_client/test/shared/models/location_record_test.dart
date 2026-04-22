import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/location_record.dart';

void main() {
  group('LocationRecord 模型测试', () {
    Map<String, dynamic> createTestJson({Map<String, dynamic>? overrides}) {
      return {
        'id': 'loc-001',
        'userId': 'user-001',
        'realName': '张大爷',
        'latitude': 39.9042,
        'longitude': 116.4074,
        'recordedAt': '2026-04-22T10:30:00Z',
        ...?overrides,
      };
    }

    test('fromJson 应正确解析完整数据', () {
      final record = LocationRecord.fromJson(createTestJson());

      expect(record.id, 'loc-001');
      expect(record.userId, 'user-001');
      expect(record.realName, '张大爷');
      expect(record.latitude, 39.9042);
      expect(record.longitude, 116.4074);
      expect(record.recordedAt, isNotNull);
    });

    test('fromJson realName 缺失时应为 null', () {
      final record = LocationRecord.fromJson({
        'id': 'loc-002',
        'userId': 'user-002',
        'latitude': 31.2304,
        'longitude': 121.4737,
        'recordedAt': '2026-04-22T08:00:00Z',
      });

      expect(record.realName, null);
    });

    test('formattedCoordinates 应正确格式化经纬度', () {
      final record = LocationRecord.fromJson(createTestJson());

      expect(record.formattedCoordinates, contains('39.904200'));
      expect(record.formattedCoordinates, contains('116.407400'));
      expect(record.formattedCoordinates, contains('纬度'));
      expect(record.formattedCoordinates, contains('经度'));
    });

    test('formattedTime 应正确格式化时间', () {
      final record = LocationRecord.fromJson(createTestJson());
      final localTime = record.recordedAt.toLocal();
      final expected =
          '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
          '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
      expect(record.formattedTime, expected);
    });

    test('relativeTime 应返回刚刚（当时间非常接近）', () {
      final record = LocationRecord.fromJson(
        createTestJson(overrides: {'recordedAt': DateTime.now().toUtc().toIso8601String()}),
      );
      expect(record.relativeTime, '刚刚');
    });

    test('relativeTime 应返回分钟前', () {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final record = LocationRecord.fromJson(
        createTestJson(overrides: {'recordedAt': fiveMinutesAgo.toUtc().toIso8601String()}),
      );
      expect(record.relativeTime, contains('分钟前'));
    });

    test('relativeTime 应返回小时前', () {
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      final record = LocationRecord.fromJson(
        createTestJson(overrides: {'recordedAt': twoHoursAgo.toUtc().toIso8601String()}),
      );
      expect(record.relativeTime, contains('小时前'));
    });

    test('relativeTime 超过 7 天应返回 formattedTime', () {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final record = LocationRecord.fromJson(
        createTestJson(overrides: {'recordedAt': tenDaysAgo.toUtc().toIso8601String()}),
      );
      // 超过 7 天应使用 formattedTime 格式
      expect(record.relativeTime, record.formattedTime);
    });
  });
}