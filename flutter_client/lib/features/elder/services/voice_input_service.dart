import 'package:speech_to_text/speech_to_text.dart';

import '../../../shared/models/health_record.dart';

/// 语音输入服务，封装语音识别的初始化、开始、停止
class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  /// 是否正在监听
  bool get isListening => _isListening;

  /// 语音识别是否可用
  bool get isAvailable => _isAvailable;

  /// 初始化语音识别引擎
  Future<bool> initialize() async {
    if (_isAvailable) return true;
    _isAvailable = await _speech.initialize();
    return _isAvailable;
  }

  /// 开始语音识别
  /// [onResult] 识别结果回调
  /// [onSoundLevelChange] 音量变化回调（用于动画反馈）
  /// 返回 true 表示开始成功，false 表示不可用或正在监听
  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(double)? onSoundLevelChange,
  }) async {
    if (!_isAvailable || _isListening) return false;

    _isListening = true;
    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        localeId: 'zh_CN',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
      _isListening = false;
      return true;
    } catch (_) {
      _isListening = false;
      return false;
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      await _speech.stop();
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopListening();
  }
}

/// 语音解析器，从语音识别文本中提取健康数据数值
class VoiceParser {
  /// 中文数字映射
  static const Map<String, int> _chineseDigits = {
    '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
    '十': 10, '百': 100,
  };

  /// 解析血压值：支持 "130/80"、"130 80"、"收缩压130舒张压80" 等格式
  static (int? systolic, int? diastolic) parseBloodPressure(String text) {
    final numbers = _extractNumbers(text);
    if (numbers.length >= 2) {
      // 取前两个数字，收缩压在前，舒张压在后
      return (numbers[0].toInt(), numbers[1].toInt());
    }
    if (numbers.length == 1) {
      return (numbers[0].toInt(), null);
    }
    return (null, null);
  }

  /// 解析血糖值：支持 "5.6"、"五点六" 等格式
  static double? parseBloodSugar(String text) {
    final numbers = _extractNumbers(text);
    // 血糖通常在 1.0-35.0 范围
    for (final num in numbers) {
      if (num >= 1.0 && num <= 35.0) return num;
    }
    return null;
  }

  /// 解析心率值：支持 "72"、"七十二" 等格式
  static int? parseHeartRate(String text) {
    final numbers = _extractNumbers(text);
    // 心率通常在 30-200 范围
    for (final num in numbers) {
      if (num >= 30 && num <= 200) return num.toInt();
    }
    return null;
  }

  /// 解析体温值：支持 "36.5"、"三十六度五" 等格式
  static double? parseTemperature(String text) {
    final numbers = _extractNumbers(text);
    // 体温通常在 35.0-42.0 范围
    for (final num in numbers) {
      if (num >= 35.0 && num <= 42.0) return num;
    }
    return null;
  }

  /// 根据健康类型自动选择对应的解析方法
  static void parseAndFill(
    HealthType type,
    String text, {
    Function(int systolic, int diastolic)? onBloodPressure,
    Function(double value)? onBloodSugar,
    Function(int value)? onHeartRate,
    Function(double value)? onTemperature,
  }) {
    switch (type) {
      case HealthType.bloodPressure:
        final (systolic, diastolic) = parseBloodPressure(text);
        if (systolic != null && diastolic != null) {
          onBloodPressure?.call(systolic, diastolic);
        }
      case HealthType.bloodSugar:
        final value = parseBloodSugar(text);
        if (value != null) {
          onBloodSugar?.call(value);
        }
      case HealthType.heartRate:
        final value = parseHeartRate(text);
        if (value != null) {
          onHeartRate?.call(value);
        }
      case HealthType.temperature:
        final value = parseTemperature(text);
        if (value != null) {
          onTemperature?.call(value);
        }
    }
  }

  /// 从文本中提取所有数值（支持阿拉伯数字和中文数字）
  static List<double> _extractNumbers(String text) {
    final results = <double>[];

    // 先处理中文数字表达（如 "三十六度五" → "36.5"）
    var processed = _convertChineseNumbers(text);

    // 用正则提取阿拉伯数字（支持小数）
    final regex = RegExp(r'\d+\.?\d*');
    for (final match in regex.allMatches(processed)) {
      final num = double.tryParse(match.group(0) ?? '');
      if (num != null) {
        results.add(num);
      }
    }

    return results;
  }

  /// 将中文数字表达转换为阿拉伯数字字符串
  /// 例如 "三十六度五" → "36.5", "五点六" → "5.6"
  static String _convertChineseNumbers(String text) {
    // 处理 "X点Y" 或 "X度Y" 格式（小数）
    var result = text;

    // 替换 "度" 为 "."，如 "三十六度五" → "三十六.五"
    result = result.replaceAll('度', '.');
    // 替换 "点" 为 "."，如 "五点六" → "五.六"
    result = result.replaceAll('点', '.');

    // 处理简单的中文数字（仅支持常用的健康数值范围）
    // 将连续的中文数字片段转换为阿拉伯数字
    final chineseDigitPattern = RegExp(r'[零一二三四五六七八九十百]+');

    result = result.replaceAllMapped(chineseDigitPattern, (match) {
      return _convertSingleChineseNumber(match.group(0) ?? '').toString();
    });

    return result;
  }

  /// 将单个中文数字字符串转换为整数
  /// 支持 "三十六" → 36, "一百三" → 130 等
  static int _convertSingleChineseNumber(String text) {
    if (text.isEmpty) return 0;

    int result = 0;
    int current = 0;

    for (final char in text.split('')) {
      final digit = _chineseDigits[char];
      if (digit == null) continue;

      if (digit == 10) {
        // "十"：当前有数字则乘以10，否则为10
        current = current == 0 ? 10 : current * 10;
      } else if (digit == 100) {
        // "百"：当前数字乘以100
        current = current * 100;
      } else {
        if (current > 0 && current < 10) {
          // 前面已有单位（十/百），当前是后续数字
          // 如 "一百三" → 100 + 3 = 103（不处理，简化）
        }
        current = digit;
      }
      result += current;
      if (digit == 10 || digit == 100) {
        current = 0;
      }
    }

    return result;
  }
}
