import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR 解析出的健康数据结果
class OcrHealthResult {
  /// 血压收缩压（mmHg）
  final int? systolic;

  /// 血压舒张压（mmHg）
  final int? diastolic;

  /// 血糖（mmol/L）
  final double? bloodSugar;

  /// 心率（bpm）
  final int? heartRate;

  /// 体温（°C）
  final double? temperature;

  /// 原始识别文本（供用户参考）
  final String rawText;

  const OcrHealthResult({
    this.systolic,
    this.diastolic,
    this.bloodSugar,
    this.heartRate,
    this.temperature,
    this.rawText = '',
  });

  /// 是否识别到任何有效数据
  bool hasAnyData() =>
      systolic != null ||
      diastolic != null ||
      bloodSugar != null ||
      heartRate != null ||
      temperature != null;
}

/// OCR 健康数据识别服务
///
/// 使用 Google ML Kit 本地识别图片中的文字，
/// 并从血压计、血糖仪等设备屏幕中提取健康数值。
/// 支持：血压（收缩压/舒张压）、血糖、心率、体温。
class OcrParserService {
  final TextRecognizer _textRecognizer;

  OcrParserService() : _textRecognizer = TextRecognizer();

  /// 从图片文件识别健康数据
  ///
  /// [imageFile] 图片文件路径
  /// 返回识别结果，包含解析出的健康数值
  Future<OcrHealthResult> parseHealthData(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final rawText = recognizedText.text;
    final result = _parseText(rawText);

    return OcrHealthResult(
      systolic: result['systolic'] as int?,
      diastolic: result['diastolic'] as int?,
      bloodSugar: result['bloodSugar'] as double?,
      heartRate: result['heartRate'] as int?,
      temperature: result['temperature'] as double?,
      rawText: rawText,
    );
  }

  /// 解析文本，提取健康数值
  Map<String, dynamic> _parseText(String text) {
    final result = <String, dynamic>{};

    // 预处理：移除多余空格，统一格式
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 1. 解析血压：常见格式如 "120/80 mmHg"、"120/80"、"S:120 D:80"
    final bpPatterns = [
      // 标准格式：120/80 mmHg
      RegExp(r'(\d{2,3})/(\d{2,3})\s*(mmHg|mmhg)?', caseSensitive: false),
      // 分离格式：S:120 D:80 或 SYS:120 DIA:80
      RegExp(r'(S|SYS|收缩压)[:\s]*(\d{2,3})\s*(D|DIA|舒张压)[:\s]*(\d{2,3})', caseSensitive: false),
      // 中文格式：收缩压 120 舒张压 80
      RegExp(r'收缩压[:\s]*(\d{2,3})\s*舒张压[:\s]*(\d{2,3})'),
    ];

    for (final pattern in bpPatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        if (pattern == bpPatterns[0]) {
          // 标准格式：第一组是收缩压，第二组是舒张压
          result['systolic'] = int.tryParse(match.group(1) ?? '');
          result['diastolic'] = int.tryParse(match.group(2) ?? '');
        } else if (pattern == bpPatterns[1] || pattern == bpPatterns[2]) {
          // 分离格式：需要根据分组位置提取
          // 对于 S:120 D:80 格式，group(2) 是收缩压，group(4) 是舒张压
          // 对于中文格式，group(1) 是收缩压，group(2) 是舒张压
          if (pattern == bpPatterns[1]) {
            result['systolic'] = int.tryParse(match.group(2) ?? '');
            result['diastolic'] = int.tryParse(match.group(4) ?? '');
          } else {
            result['systolic'] = int.tryParse(match.group(1) ?? '');
            result['diastolic'] = int.tryParse(match.group(2) ?? '');
          }
        }
        if (result['systolic'] != null && result['diastolic'] != null) {
          break; // 已找到血压数据，跳出循环
        }
      }
    }

    // 2. 解析血糖：常见格式如 "5.2 mmol/L"、"GLU:5.2"
    final sugarPatterns = [
      RegExp(r'(\d{1,2}\.?\d?)\s*(mmol/L|mmol/l)', caseSensitive: false),
      RegExp(r'(GLU|血糖)[:\s]*(\d{1,2}\.?\d?)', caseSensitive: false),
    ];

    for (final pattern in sugarPatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        if (pattern == sugarPatterns[0]) {
          result['bloodSugar'] = double.tryParse(match.group(1) ?? '');
        } else {
          result['bloodSugar'] = double.tryParse(match.group(2) ?? '');
        }
        if (result['bloodSugar'] != null) {
          // 验证血糖值范围（1-30 mmol/L）
          if (result['bloodSugar']! < 1 || result['bloodSugar']! > 30) {
            result['bloodSugar'] = null; // 超出合理范围，可能是误识别
          }
          break;
        }
      }
    }

    // 3. 解析心率：常见格式如 "72 bpm"、"Pulse:72"、"心率:72"
    final hrPatterns = [
      RegExp(r'(\d{2,3})\s*(bpm|BPM)', caseSensitive: false),
      RegExp(r'(Pulse|心率|HR)[:\s]*(\d{2,3})', caseSensitive: false),
    ];

    for (final pattern in hrPatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        if (pattern == hrPatterns[0]) {
          result['heartRate'] = int.tryParse(match.group(1) ?? '');
        } else {
          result['heartRate'] = int.tryParse(match.group(2) ?? '');
        }
        if (result['heartRate'] != null) {
          // 验证心率范围（30-200 bpm）
          if (result['heartRate']! < 30 || result['heartRate']! > 200) {
            result['heartRate'] = null; // 超出合理范围
          }
          break;
        }
      }
    }

    // 4. 解析体温：常见格式如 "36.5°C"、"Temp:36.5"
    final tempPatterns = [
      RegExp(r'(\d{2}\.?\d?)\s*°C', caseSensitive: false),
      RegExp(r'(Temp|体温|T)[:\s]*(\d{2}\.?\d?)', caseSensitive: false),
    ];

    for (final pattern in tempPatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        if (pattern == tempPatterns[0]) {
          result['temperature'] = double.tryParse(match.group(1) ?? '');
        } else {
          result['temperature'] = double.tryParse(match.group(2) ?? '');
        }
        if (result['temperature'] != null) {
          // 验证体温范围（35-42 °C）
          if (result['temperature']! < 35 || result['temperature']! > 42) {
            result['temperature'] = null; // 超出合理范围
          }
          break;
        }
      }
    }

    return result;
  }

  /// 释放资源
  void dispose() {
    _textRecognizer.close();
  }
}