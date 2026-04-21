import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 高德地图配置类
class AMapConfig {
  /// 是否已设置隐私合规
  static bool _privacySet = false;

  /// 设置隐私合规（高德 SDK 8.1.0+ 要求）
  static AMapPrivacyStatement getPrivacyStatement() {
    if (!_privacySet) {
      _privacySet = true;
    }
    return const AMapPrivacyStatement(
      hasContains: true,  // 隐私权政策是否包含高德开平隐私权政策
      hasShow: true,      // 隐私权政策是否已展示给用户
      hasAgree: true,     // 隐私权政策用户是否已同意
    );
  }
}

/// 老人位置地图组件
class ElderLocationMap extends StatefulWidget {
  /// 老人当前位置纬度
  final double latitude;

  /// 老人当前位置经度
  final double longitude;

  /// 老人名称
  final String elderName;

  /// 围栏中心纬度（可选）
  final double? fenceCenterLat;

  /// 围栏中心经度（可选）
  final double? fenceCenterLon;

  /// 围栏半径（米）
  final int? fenceRadius;

  /// 围栏是否启用
  final bool fenceEnabled;

  const ElderLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.elderName,
    this.fenceCenterLat,
    this.fenceCenterLon,
    this.fenceRadius,
    this.fenceEnabled = false,
  });

  @override
  State<ElderLocationMap> createState() => _ElderLocationMapState();
}

class _ElderLocationMapState extends State<ElderLocationMap> {
  @override
  Widget build(BuildContext context) {
    // 如果坐标无效，显示提示
    if (widget.latitude == 0 || widget.longitude == 0) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('暂无位置数据', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AMapWidget(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.latitude, widget.longitude),
            zoom: 15,
          ),
          privacyStatement: AMapConfig.getPrivacyStatement(),
          mapType: MapType.normal,
          markers: _buildMarkers(),
          polygons: _buildFencePolygon(),
        ),
      ),
    );
  }

  /// 构建标记点
  Set<Marker> _buildMarkers() {
    return {
      // 老人当前位置标记
      Marker(
        position: LatLng(widget.latitude, widget.longitude),
        infoWindow: InfoWindow(
          title: widget.elderName,
          snippet: '当前位置',
        ),
      ),
    };
  }

  /// 构建围栏多边形（圆形近似）
  Set<Polygon> _buildFencePolygon() {
    if (!widget.fenceEnabled ||
        widget.fenceCenterLat == null ||
        widget.fenceCenterLon == null ||
        widget.fenceRadius == null) {
      return {};
    }

    // 用多边形近似圆形（36个点）
    final points = _generateCirclePoints(
      widget.fenceCenterLat!,
      widget.fenceCenterLon!,
      widget.fenceRadius!,
      36,
    );

    return {
      Polygon(
        points: points,
        strokeWidth: 2,
        strokeColor: Colors.green,
        fillColor: Colors.green.withValues(alpha: 0.2),
      ),
    };
  }

  /// 生成圆形多边形的点
  List<LatLng> _generateCirclePoints(double centerLat, double centerLon, int radiusMeters, int segments) {
    final points = <LatLng>[];
    // 地球半径（米）
    const earthRadius = 6371000.0;

    for (int i = 0; i < segments; i++) {
      final angle = (2 * math.pi * i) / segments;
      // 计算纬度偏移
      final latOffset = (radiusMeters / earthRadius) * math.sin(angle);
      // 计算经度偏移（考虑纬度修正）
      final lonOffset = (radiusMeters / earthRadius) * math.cos(angle) / math.cos(centerLat * math.pi / 180);

      points.add(LatLng(
        centerLat + latOffset * 180 / math.pi,
        centerLon + lonOffset * 180 / math.pi,
      ));
    }

    return points;
  }
}