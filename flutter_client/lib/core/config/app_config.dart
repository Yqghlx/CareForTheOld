/// 应用环境配置
///
/// 通过编译时常量区分 dev/staging/prod 环境，
/// 避免在代码中硬编码 IP 地址和端口。
///
/// 切换环境：修改 [current] 的值即可。
class AppConfig {
  final String apiBaseUrl;
  final String signalrBaseUrl;
  final String environment;

  const AppConfig({
    required this.apiBaseUrl,
    required this.signalrBaseUrl,
    required this.environment,
  });

  /// 开发环境：使用宿主机局域网 IP，模拟器和真机均可访问
  static const dev = AppConfig(
    apiBaseUrl: 'http://192.168.100.200:5001/api/v1',
    signalrBaseUrl: 'http://192.168.100.200:5001/hubs/notification',
    environment: 'development',
  );

  /// 预发布环境
  static const staging = AppConfig(
    apiBaseUrl: 'https://staging-api.example.com/api/v1',
    signalrBaseUrl: 'https://staging-api.example.com/hubs/notification',
    environment: 'staging',
  );

  /// 生产环境
  static const production = AppConfig(
    apiBaseUrl: 'https://api.example.com/api/v1',
    signalrBaseUrl: 'https://api.example.com/hubs/notification',
    environment: 'production',
  );

  /// 当前生效的配置
  /// 通过编译参数选择环境：--dart-define=APP_ENV=production|staging
  /// 未指定时默认使用开发环境
  static const current = String.fromEnvironment('APP_ENV') == 'production'
      ? production
      : String.fromEnvironment('APP_ENV') == 'staging'
          ? staging
          : dev;

  /// 外部服务 URL 常量
  /// OpenStreetMap 瓦片服务地址（地图底图）
  static const String openStreetMapTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// 紧急呼叫警报铃声地址
  static const String emergencyAlarmSoundUrl =
      'https://actions.google.com/sounds/v1/alarms/beep_full.ogg';
}
