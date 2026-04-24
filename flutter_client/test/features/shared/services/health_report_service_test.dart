import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:care_for_the_old_client/features/shared/services/health_report_service.dart';
import '../../../core/helpers/mock_dio_helper.dart';

void main() {
  late MockDio mockDio;
  late HealthReportService service;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockDio = MockDio();
    service = HealthReportService(mockDio);
  });

  group('HealthReportService 健康报告服务测试', () {
    group('downloadAndShareReport 下载并分享报告', () {
      test('老人端（无 elderId）应调用正确路径', () async {
        // 模拟 Dio 返回 PDF 字节数据
        when(() => mockDio.get(
              '/health/me/report?days=7',
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([1, 2, 3, 4, 5]),
            ));

        // 由于 path_provider 和 share_plus 是平台插件，测试环境中会抛出
        // MissingPluginException，因此我们验证 Dio 被正确调用即可。
        // 捕获异常后，downloadAndShareReport 应返回 false。
        try {
          await service.downloadAndShareReport(days: 7);
        } catch (_) {
          // 平台插件异常，忽略
        }

        verify(() => mockDio.get(
              '/health/me/report?days=7',
              options: any(named: 'options'),
            )).called(1);
      });

      test('老人端（无 elderId）days=30 应正确传递', () async {
        when(() => mockDio.get(
              '/health/me/report?days=30',
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([1, 2, 3]),
            ));

        try {
          await service.downloadAndShareReport(days: 30);
        } catch (_) {
          // 平台插件异常，忽略
        }

        verify(() => mockDio.get(
              '/health/me/report?days=30',
              options: any(named: 'options'),
            )).called(1);
      });

      test('子女端（有 elderId + familyId）应调用正确的家庭路径', () async {
        when(() => mockDio.get(
              '/health/family/fam-001/member/elder-002/report?days=7',
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([10, 20, 30]),
            ));

        try {
          await service.downloadAndShareReport(
            days: 7,
            elderId: 'elder-002',
            familyId: 'fam-001',
          );
        } catch (_) {
          // 平台插件异常，忽略
        }

        verify(() => mockDio.get(
              '/health/family/fam-001/member/elder-002/report?days=7',
              options: any(named: 'options'),
            )).called(1);
      });

      test('子女端 days 参数应正确拼接到 URL', () async {
        when(() => mockDio.get(
              '/health/family/fam-100/member/elder-200/report?days=30',
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([1]),
            ));

        try {
          await service.downloadAndShareReport(
            days: 30,
            elderId: 'elder-200',
            familyId: 'fam-100',
          );
        } catch (_) {
          // 平台插件异常，忽略
        }

        verify(() => mockDio.get(
              '/health/family/fam-100/member/elder-200/report?days=30',
              options: any(named: 'options'),
            )).called(1);
      });

      test('仅传 elderId 不传 familyId 应使用老人端路径', () async {
        // 当 elderId 不为 null 但 familyId 为 null 时，走老人端逻辑
        when(() => mockDio.get(
              '/health/me/report?days=7',
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([1]),
            ));

        try {
          await service.downloadAndShareReport(
            days: 7,
            elderId: 'elder-only',
            // familyId 未传
          );
        } catch (_) {
          // 平台插件异常，忽略
        }

        verify(() => mockDio.get(
              '/health/me/report?days=7',
              options: any(named: 'options'),
            )).called(1);
      });

      test('仅传 familyId 不传 elderId 应使用老人端路径', () async {
        // 当 familyId 不为 null 但 elderId 为 null 时，走老人端逻辑
        when(() => mockDio.get(
              '/health/me/report?days=7',
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([1]),
            ));

        try {
          await service.downloadAndShareReport(
            days: 7,
            familyId: 'fam-only',
            // elderId 未传
          );
        } catch (_) {
          // 平台插件异常，忽略
        }

        verify(() => mockDio.get(
              '/health/me/report?days=7',
              options: any(named: 'options'),
            )).called(1);
      });

      test('Dio 请求应指定 responseType 为 bytes', () async {
        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse(
              Uint8List.fromList([1]),
            ));

        try {
          await service.downloadAndShareReport(days: 7);
        } catch (_) {
          // 平台插件异常，忽略
        }

        // 验证 options 参数中 responseType 为 bytes
        final verification = verify(() => mockDio.get(
              any(),
              options: captureAny(named: 'options'),
            ));
        verification.called(1);

        final capturedOptions = verification.captured.single as Options?;
        expect(capturedOptions?.responseType, ResponseType.bytes);
      });

      test('网络请求失败时应返回 false', () async {
        when(() => mockDio.get(
              any(),
              options: any(named: 'options'),
              queryParameters: any(named: 'queryParameters'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              message: '网络错误',
            ));

        final result = await service.downloadAndShareReport(days: 7);

        expect(result, false);
      });
    });
  });
}
