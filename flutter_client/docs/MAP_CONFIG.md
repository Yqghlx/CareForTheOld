# 地图配置说明

本项目使用 **flutter_map** + **OpenStreetMap** 作为地图解决方案。

## 为什么选择 OpenStreetMap？

- **完全免费**：无需 API Key，无需注册账号
- **无调用限制**：不像高德/腾讯地图有每日配额限制
- **开源透明**：数据来源于 OpenStreetMap 社区
- **全球覆盖**：支持全球地图数据

## 配置说明

无需任何额外配置，地图功能即可使用。

**注意**：OpenStreetMap 服务器在国内访问可能较慢，如有需要可以替换为国内镜像：
- 高德地图瓦片：`https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}`
- 腾讯地图瓦片：需要申请 Key

## 如果需要高德地图

如需使用高德地图（更快的国内访问速度），可替换瓦片源：

```dart
TileLayer(
  urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
  subdomains: ['1', '2', '3', '4'],
  userAgentPackageName: 'com.example.care_for_the_old_client',
)
```

注意：使用高德瓦片仍需遵守高德地图的使用条款。

## 地图功能

- 显示老人当前位置（红色标记点）
- 显示安全围栏范围（绿色圆圈）
- 支持缩放和拖动

## 相关链接

- [flutter_map 文档](https://docs.fleaflet.dev/)
- [OpenStreetMap](https://www.openstreetmap.org/)
- [flutter_map pub.dev](https://pub.dev/packages/flutter_map)