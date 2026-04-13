/// 位置记录模型
class LocationRecord {
  final String id;
  final String userId;
  final String? realName;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  LocationRecord({
    required this.id,
    required this.userId,
    this.realName,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  /// 从 JSON 解析
  factory LocationRecord.fromJson(Map<String, dynamic> json) {
    return LocationRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      realName: json['realName'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt']),
    );
  }

  /// 格式化时间
  String get formattedTime {
    final localTime = recordedAt.toLocal();
    return '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  /// 相对时间描述
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(recordedAt);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formattedTime;
    }
  }

  /// 格式化坐标显示
  String get formattedCoordinates {
    return '纬度: ${latitude.toStringAsFixed(6)}\n经度: ${longitude.toStringAsFixed(6)}';
  }
}