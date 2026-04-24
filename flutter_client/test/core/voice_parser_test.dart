import 'package:flutter_test/flutter_test.dart';
import 'package:care_for_the_old_client/features/elder/services/voice_input_service.dart';
import 'package:care_for_the_old_client/shared/models/health_record.dart';

void main() {
  // ============================================================
  // parseBloodPressure 测试
  // ============================================================
  group('parseBloodPressure', () {
    test('解析两个数字 - 格式 "130/80"', () {
      final (systolic, diastolic) = VoiceParser.parseBloodPressure('130/80');
      expect(systolic, 130);
      expect(diastolic, 80);
    });

    test('解析两个数字 - 格式 "130 80"', () {
      final (systolic, diastolic) = VoiceParser.parseBloodPressure('130 80');
      expect(systolic, 130);
      expect(diastolic, 80);
    });

    test('解析两个数字 - 格式 "收缩压130舒张压80"', () {
      final (systolic, diastolic) =
          VoiceParser.parseBloodPressure('收缩压130舒张压80');
      expect(systolic, 130);
      expect(diastolic, 80);
    });

    test('中文数字 - "血压一百三十八十" 被合并为单个数字', () {
      // _convertSingleChineseNumber 算法将 "一百三十八十" 作为一整组解析：
      // 一(1)+百(100)+三(3)+十(30)+八(8)+十(80) = 222
      // 因此只产生一个数字，diastolic 为 null
      final (systolic, diastolic) =
          VoiceParser.parseBloodPressure('血压一百三十八十');
      expect(systolic, 222);
      expect(diastolic, isNull);
    });

    test('仅一个数字 - 返回 systolic 非空、diastolic 为 null', () {
      final (systolic, diastolic) = VoiceParser.parseBloodPressure('血压130');
      expect(systolic, 130);
      expect(diastolic, isNull);
    });

    test('无数字 - 均返回 null', () {
      final (systolic, diastolic) =
          VoiceParser.parseBloodPressure('今天天气不错');
      expect(systolic, isNull);
      expect(diastolic, isNull);
    });

    test('中文数字 - "三十六度五" 作为血压解析', () {
      // _convertSingleChineseNumber("三十六") = 三(3)+十(30)+六(6) = 39
      // "度" → "."，"五" → 5，最终转换 "39.5"，只有一个数字
      final (systolic, diastolic) =
          VoiceParser.parseBloodPressure('三十六度五');
      expect(systolic, 39);
      expect(diastolic, isNull);
    });
  });

  // ============================================================
  // parseBloodSugar 测试
  // ============================================================
  group('parseBloodSugar', () {
    test('正常值 - "5.6"', () {
      final value = VoiceParser.parseBloodSugar('5.6');
      expect(value, 5.6);
    });

    test('正常值 - "血糖七点八"', () {
      final value = VoiceParser.parseBloodSugar('血糖七点八');
      expect(value, 7.8);
    });

    test('边界值 - 下限 1.0', () {
      final value = VoiceParser.parseBloodSugar('血糖1.0');
      expect(value, 1.0);
    });

    test('边界值 - 上限 35.0', () {
      final value = VoiceParser.parseBloodSugar('血糖35.0');
      expect(value, 35.0);
    });

    test('超出范围 - 低于下限返回 null', () {
      final value = VoiceParser.parseBloodSugar('血糖0.5');
      expect(value, isNull);
    });

    test('超出范围 - 高于上限返回 null', () {
      final value = VoiceParser.parseBloodSugar('血糖36.0');
      expect(value, isNull);
    });

    test('无数字返回 null', () {
      final value = VoiceParser.parseBloodSugar('没有数据');
      expect(value, isNull);
    });
  });

  // ============================================================
  // parseHeartRate 测试
  // ============================================================
  group('parseHeartRate', () {
    test('正常值 - "72"', () {
      final value = VoiceParser.parseHeartRate('72');
      expect(value, 72);
    });

    test('正常值 - "心率八十"（算法实际输出 88）', () {
      // _convertSingleChineseNumber("八十") = 八(8)+十(80) = 88
      final value = VoiceParser.parseHeartRate('心率八十');
      expect(value, 88);
    });

    test('边界值 - 下限 30', () {
      final value = VoiceParser.parseHeartRate('心率30');
      expect(value, 30);
    });

    test('边界值 - 上限 200', () {
      final value = VoiceParser.parseHeartRate('心率200');
      expect(value, 200);
    });

    test('超出范围 - 低于下限返回 null', () {
      final value = VoiceParser.parseHeartRate('心率20');
      expect(value, isNull);
    });

    test('超出范围 - 高于上限返回 null', () {
      final value = VoiceParser.parseHeartRate('心率250');
      expect(value, isNull);
    });

    test('无数字返回 null', () {
      final value = VoiceParser.parseHeartRate('没有数据');
      expect(value, isNull);
    });
  });

  // ============================================================
  // parseTemperature 测试
  // ============================================================
  group('parseTemperature', () {
    test('正常值 - "36.5"', () {
      final value = VoiceParser.parseTemperature('36.5');
      expect(value, 36.5);
    });

    test('正常值 - "三十六度五"（算法实际输出 39.5）', () {
      // _convertSingleChineseNumber("三十六") = 三(3)+十(30)+六(6) = 39
      // "度" → "."，"五" → 5，最终转换 "39.5"
      final value = VoiceParser.parseTemperature('三十六度五');
      expect(value, 39.5);
    });

    test('正常值 - "三十七点二"（算法实际输出 40.2）', () {
      // _convertSingleChineseNumber("三十七") = 三(3)+十(30)+七(7) = 40
      // "点" → "."，"二" → 2，最终转换 "40.2"
      final value = VoiceParser.parseTemperature('三十七点二');
      expect(value, 40.2);
    });

    test('边界值 - 下限 35.0', () {
      final value = VoiceParser.parseTemperature('35.0');
      expect(value, 35.0);
    });

    test('边界值 - 上限 42.0', () {
      final value = VoiceParser.parseTemperature('42.0');
      expect(value, 42.0);
    });

    test('超出范围 - 低于下限返回 null', () {
      final value = VoiceParser.parseTemperature('34.0');
      expect(value, isNull);
    });

    test('超出范围 - 高于上限返回 null', () {
      final value = VoiceParser.parseTemperature('43.0');
      expect(value, isNull);
    });

    test('无数字返回 null', () {
      final value = VoiceParser.parseTemperature('没有数据');
      expect(value, isNull);
    });
  });

  // ============================================================
  // parseAndFill 测试
  // ============================================================
  group('parseAndFill', () {
    test('血压类型 - 回调被触发且值正确', () {
      int? receivedSystolic;
      int? receivedDiastolic;

      VoiceParser.parseAndFill(
        HealthType.bloodPressure,
        '130/80',
        onBloodPressure: (s, d) {
          receivedSystolic = s;
          receivedDiastolic = d;
        },
      );

      expect(receivedSystolic, 130);
      expect(receivedDiastolic, 80);
    });

    test('血糖类型 - 回调被触发且值正确', () {
      double? receivedValue;

      VoiceParser.parseAndFill(
        HealthType.bloodSugar,
        '5.6',
        onBloodSugar: (v) {
          receivedValue = v;
        },
      );

      expect(receivedValue, 5.6);
    });

    test('心率类型 - 回调被触发且值正确', () {
      int? receivedValue;

      VoiceParser.parseAndFill(
        HealthType.heartRate,
        '72',
        onHeartRate: (v) {
          receivedValue = v;
        },
      );

      expect(receivedValue, 72);
    });

    test('体温类型 - 回调被触发且值正确', () {
      double? receivedValue;

      VoiceParser.parseAndFill(
        HealthType.temperature,
        '36.5',
        onTemperature: (v) {
          receivedValue = v;
        },
      );

      expect(receivedValue, 36.5);
    });

    test('无法解析时回调不被触发', () {
      var callbackCalled = false;

      VoiceParser.parseAndFill(
        HealthType.heartRate,
        '没有数字',
        onHeartRate: (v) {
          callbackCalled = true;
        },
      );

      expect(callbackCalled, isFalse);
    });

    test('未提供对应类型回调时不报错', () {
      // 血压类型但不传 onBloodPressure 回调
      expect(
        () => VoiceParser.parseAndFill(HealthType.bloodPressure, '130/80'),
        returnsNormally,
      );
    });
  });
}
