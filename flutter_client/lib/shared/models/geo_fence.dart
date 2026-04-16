/// 电子围栏模型
class GeoFence {
  final String id;
  final String elderId;
  final String? elderName;
  final double centerLatitude;
  final double centerLongitude;
  final int radius;
  final bool isEnabled;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GeoFence({
    required this.id,
    required this.elderId,
    this.elderName,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radius,
    required this.isEnabled,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GeoFence.fromJson(Map<String, dynamic> json) {
    return GeoFence(
      id: json['id'] as String,
      elderId: json['elderId'] as String,
      elderName: json['elderName'] as String?,
      centerLatitude: (json['centerLatitude'] as num).toDouble(),
      centerLongitude: (json['centerLongitude'] as num).toDouble(),
      radius: json['radius'] as int,
      isEnabled: json['isEnabled'] as bool,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 获取格式化的更新时间
  String get formattedUpdatedAt {
    final local = updatedAt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化半径显示
  String get radiusDisplay {
    if (radius >= 1000) {
      return '${(radius / 1000).toStringAsFixed(1)} 公里';
    }
    return '$radius 米';
  }
}