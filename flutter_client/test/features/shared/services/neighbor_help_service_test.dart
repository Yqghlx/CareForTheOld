import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../core/helpers/mock_dio_helper.dart';
import 'package:care_for_the_old_client/features/shared/services/neighbor_help_service.dart';
import 'package:care_for_the_old_client/shared/models/neighbor_help_request.dart';

void main() {
  late MockDio mockDio;
  late NeighborHelpService service;

  setUpAll(() => registerFallbackValues());

  setUp(() {
    mockDio = MockDio();
    service = NeighborHelpService(mockDio);
  });

  const requestJson = {
    'id': 'request-001',
    'emergencyCallId': 'call-001',
    'circleId': 'circle-001',
    'requesterId': 'user-001',
    'requesterName': '张大爷',
    'responderId': null,
    'responderName': null,
    'status': 'pending',
    'latitude': 39.9042,
    'longitude': 116.4074,
    'requestedAt': '2026-04-20T08:00:00Z',
    'respondedAt': null,
    'expiresAt': '2026-04-20T08:15:00Z',
  };

  group('getPendingRequests', () {
    test('成功获取待响应列表', () async {
      when(() => mockDio.get('/neighborhelp/pending'))
          .thenAnswer((_) async => mockResponse({'data': [requestJson]}));

      final result = await service.getPendingRequests();

      expect(result.length, 1);
      expect(result[0].requesterName, '张大爷');
      expect(result[0].status, HelpRequestStatus.pending);
      verify(() => mockDio.get('/neighborhelp/pending')).called(1);
    });

    test('无待响应请求应返回空列表', () async {
      when(() => mockDio.get('/neighborhelp/pending'))
          .thenAnswer((_) async => mockResponse({'data': []}));

      final result = await service.getPendingRequests();

      expect(result, isEmpty);
    });
  });

  group('acceptRequest', () {
    test('成功接受求助', () async {
      final acceptedJson = Map<String, dynamic>.from(requestJson)
        ..['status'] = 'accepted'
        ..['responderId'] = 'user-002'
        ..['responderName'] = '李阿姨';

      when(() => mockDio.put('/neighborhelp/request-001/accept'))
          .thenAnswer((_) async => mockResponse({'data': acceptedJson}));

      final result = await service.acceptRequest('request-001');

      expect(result.status, HelpRequestStatus.accepted);
      expect(result.responderName, '李阿姨');
      verify(() => mockDio.put('/neighborhelp/request-001/accept')).called(1);
    });
  });

  group('cancelRequest', () {
    test('成功取消求助', () async {
      when(() => mockDio.put('/neighborhelp/request-001/cancel'))
          .thenAnswer((_) async => mockResponse({'data': null}));

      await service.cancelRequest('request-001');

      verify(() => mockDio.put('/neighborhelp/request-001/cancel')).called(1);
    });
  });

  group('rateRequest', () {
    test('成功提交评价', () async {
      when(() => mockDio.post('/neighborhelp/request-001/rate', data: any(named: 'data')))
          .thenAnswer((_) async => mockResponse({
                'data': {
                  'id': 'rating-001',
                  'helpRequestId': 'request-001',
                  'raterId': 'user-001',
                  'rateeId': 'user-002',
                  'rating': 5,
                  'comment': '非常感谢',
                  'createdAt': '2026-04-20T09:00:00Z',
                },
              }));

      final result = await service.rateRequest(
        requestId: 'request-001',
        rating: 5,
        comment: '非常感谢',
      );

      expect(result.rating, 5);
      expect(result.comment, '非常感谢');
    });
  });

  group('getHistory', () {
    test('成功获取历史记录', () async {
      when(() => mockDio.get(
            '/neighborhelp/history',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => mockResponse({'data': [requestJson]}));

      final result = await service.getHistory(skip: 0, limit: 20);

      expect(result.length, 1);
    });
  });
}
