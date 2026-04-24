import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/core/services/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('初始化不抛异常', () {
      expect(() => AppLogger.init(), returnsNormally);
    });

    test('debug 日志不抛异常', () {
      expect(() => AppLogger.debug('调试信息'), returnsNormally);
    });

    test('info 日志不抛异常', () {
      expect(() => AppLogger.info('一般信息'), returnsNormally);
    });

    test('warning 日志不抛异常', () {
      expect(() => AppLogger.warning('警告信息'), returnsNormally);
    });

    test('error 日志不抛异常', () {
      expect(() => AppLogger.error('错误信息'), returnsNormally);
    });

    test('带 error 和 stackTrace 参数不抛异常', () {
      expect(
        () => AppLogger.error(
          '错误信息',
          Exception('测试异常'),
          StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('多次初始化不抛异常', () {
      AppLogger.init();
      expect(() => AppLogger.init(), returnsNormally);
    });
  });
}
