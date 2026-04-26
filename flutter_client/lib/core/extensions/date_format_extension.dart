import 'package:intl/intl.dart';

/// DateTime 格式化扩展方法
/// 统一项目中日期/时间的格式化逻辑，避免重复手写格式字符串
extension DateTimeFormatting on DateTime {
  /// 格式化为日期字符串：2024-01-15
  String toDateString() => DateFormat('yyyy-MM-dd').format(this);

  /// 格式化为时间字符串：14:30
  String toTimeString() => DateFormat('HH:mm').format(this);

  /// 格式化为日期时间字符串：2024-01-15 14:30
  String toDateTimeString() => DateFormat('yyyy-MM-dd HH:mm').format(this);

  /// 格式为短日期时间：1/15 14:30（通知列表、围栏记录等紧凑展示）
  String toShortDateTimeString() => DateFormat('M/d HH:mm').format(this);

  /// 格式化为友好日期：1月15日
  String toFriendlyDate() => '$month月$day日';

  /// 格式化为友好时间范围：14:30 - 15:00
  String toTimeRange(DateTime end) => '${toTimeString()} - ${end.toTimeString()}';
}
