import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:care_for_the_old_client/features/elder/services/voice_input_service.dart';

/// Mock SpeechToText
class MockSpeechToText extends Mock implements SpeechToText {}

void main() {
  // VoiceInputService 内部直接创建 SpeechToText 实例，
  // 无法通过构造函数注入 mock。
  // 因此测试聚焦于可验证的属性和边界行为。

  group('VoiceInputService', () {
    test('初始状态 isListening 应为 false', () {
      final service = VoiceInputService();
      expect(service.isListening, false);
    });

    test('初始状态 isAvailable 应为 false', () {
      final service = VoiceInputService();
      expect(service.isAvailable, false);
    });

    test('未初始化时 startListening 应返回 false', () async {
      final service = VoiceInputService();
      final result = await service.startListening(
        onResult: (_, __) {},
      );
      expect(result, false);
    });

    test('未初始化时 stopListening 不应抛异常', () async {
      final service = VoiceInputService();
      await service.stopListening();
      expect(service.isListening, false);
    });

    test('dispose 不应抛异常', () async {
      final service = VoiceInputService();
      await service.dispose();
      expect(service.isListening, false);
    });

    test('重复 dispose 不应抛异常', () async {
      final service = VoiceInputService();
      await service.dispose();
      await service.dispose();
      expect(service.isListening, false);
    });
  });
}
