import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// 老人位置地图组件
/// 使用 OpenStreetMap（免费，无需 API Key）
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
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(ElderLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果位置变化，重新定位地图中心
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _mapController.move(
        LatLng(widget.latitude, widget.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果坐标无效，显示提示
    if (widget.latitude == 0 || widget.longitude == 0) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: AppTheme.radiusL,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: AppTheme.grey400),
              const SizedBox(height: 12),
              const Text('暂无位置数据', style: AppTheme.textGreyLight),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: AppTheme.radiusL,
        border: Border.all(color: AppTheme.grey300),
      ),
      child: ClipRRect(
        borderRadius: AppTheme.radiusL,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(widget.latitude, widget.longitude),
            initialZoom: 15,
            minZoom: 10,
            maxZoom: 18,
          ),
          children: [
            // OpenStreetMap 图层
            TileLayer(
              urlTemplate: AppConfig.openStreetMapTileUrl,
              userAgentPackageName: 'com.example.care_for_the_old_client',
              maxZoom: 19,
            ),
            // 围栏圆圈图层
            if (widget.fenceEnabled &&
                widget.fenceCenterLat != null &&
                widget.fenceCenterLon != null &&
                widget.fenceRadius != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(widget.fenceCenterLat!, widget.fenceCenterLon!),
                    radius: widget.fenceRadius!.toDouble(),
                    color: AppTheme.successColor.withValues(alpha: 0.2),
                    borderStrokeWidth: 2.0,
                    borderColor: AppTheme.successColor,
                    useRadiusInMeter: true,
                  ),
                ],
              ),
            // 老人位置标记图层
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(widget.latitude, widget.longitude),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}