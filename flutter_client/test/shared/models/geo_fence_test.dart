import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/shared/models/geo_fence.dart';

void main() {
  group('GeoFence 模型测试', () {
    Map<String, dynamic> createTestJson({Map<String, dynamic>? overrides}) {
      return {
        'id': 'fence-001',
        'elderId': 'elder-001',
        'elderName': '张大爷',
        'centerLatitude': 39.9042,
        'centerLongitude': 116.4074,
        'radius': 500,
        'isEnabled': true,
        'createdBy': 'child-001',
        'createdAt': '2026-04-20T10:00:00Z',
        'updatedAt': '2026-04-22T15:30:00Z',
        ...?overrides,
      };
    }

    test('fromJson 应正确解析完整数据', () {
      final fence = GeoFence.fromJson(createTestJson());

      expect(fence.id, 'fence-001');
      expect(fence.elderId, 'elder-001');
      expect(fence.elderName, '张大爷');
      expect(fence.centerLatitude, 39.9042);
      expect(fence.centerLongitude, 116.4074);
      expect(fence.radius, 500);
      expect(fence.isEnabled, true);
      expect(fence.createdBy, 'child-001');
    });

    test('fromJson elderName 缺失时应为 null', () {
      final fence = GeoFence.fromJson(createTestJson(overrides: {
        'elderName': null,
      }));
      expect(fence.elderName, null);
    });

    test('radiusDisplay 小于 1000 米应显示"米"', () {
      final fence = GeoFence.fromJson(createTestJson());
      expect(fence.radiusDisplay, '500 米');
    });

    test('radiusDisplay 大于等于 1000 米应显示"公里"', () {
      final fence = GeoFence.fromJson(
          createTestJson(overrides: {'radius': 2000}));
      expect(fence.radiusDisplay, '2.0 公里');
    });

    test('radiusDisplay 1500 米应显示 1.5 公里', () {
      final fence = GeoFence.fromJson(
          createTestJson(overrides: {'radius': 1500}));
      expect(fence.radiusDisplay, '1.5 公里');
    });

    test('formattedUpdatedAt 应正确格式化', () {
      final fence = GeoFence.fromJson(createTestJson());
      final local = fence.updatedAt.toLocal();
      final expected =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      expect(fence.formattedUpdatedAt, expected);
    });
  });
}