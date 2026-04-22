import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/health_stats.dart';

void main() {
  group('HealthStats 模型测试', () {
    Map<String, dynamic> createTestJson({Map<String, dynamic>? overrides}) {
      return {
        'typeName': '血压',
        'average7Days': 125.5,
        'average30Days': 130.2,
        'latestValue': 118.0,
        'latestRecordedAt': '2026-04-22T08:00:00Z',
        'totalCount': 45,
        'trend': 'falling',
        'trendWarning': '血压呈下降趋势',
        ...?overrides,
      };
    }

    test('fromJson 应正确解析完整数据', () {
      final stats = HealthStats.fromJson(createTestJson());

      expect(stats.typeName, '血压');
      expect(stats.average7Days, 125.5);
      expect(stats.average30Days, 130.2);
      expect(stats.latestValue, 118.0);
      expect(stats.latestRecordedAt, isNotNull);
      expect(stats.totalCount, 45);
      expect(stats.trend, 'falling');
      expect(stats.trendWarning, '血压呈下降趋势');
    });

    test('fromJson 可选字段为 null 时应安全处理', () {
      final stats = HealthStats.fromJson({
        'typeName': '血糖',
        'totalCount': 0,
      });

      expect(stats.average7Days, null);
      expect(stats.average30Days, null);
      expect(stats.latestValue, null);
      expect(stats.latestRecordedAt, null);
      expect(stats.trend, null);
      expect(stats.trendWarning, null);
    });

    test('hasWarning 趋势为 stable 时应返回 false', () {
      final stats = HealthStats.fromJson(
          createTestJson(overrides: {'trend': 'stable'}));
      expect(stats.hasWarning, false);
    });

    test('hasWarning 趋势为 rising 且有 warning 时应返回 true', () {
      final stats = HealthStats.fromJson(
          createTestJson(overrides: {'trend': 'rising'}));
      expect(stats.hasWarning, true);
    });

    test('hasWarning trend 为 null 时应返回 false', () {
      final stats = HealthStats.fromJson(
          createTestJson(overrides: {'trend': null}));
      expect(stats.hasWarning, false);
    });

    test('trendIcon 应正确映射', () {
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': 'rising'}))
              .trendIcon,
          Icons.trending_up);
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': 'falling'}))
              .trendIcon,
          Icons.trending_down);
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': 'stable'}))
              .trendIcon,
          Icons.trending_flat);
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': null}))
              .trendIcon,
          Icons.trending_flat);
    });

    test('trendColor 应正确映射', () {
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': 'rising'}))
              .trendColor,
          Colors.orange);
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': 'falling'}))
              .trendColor,
          Colors.blue);
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': 'stable'}))
              .trendColor,
          Colors.green);
      expect(
          HealthStats.fromJson(createTestJson(overrides: {'trend': null}))
              .trendColor,
          Colors.grey);
    });
  });
}