import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  /// 主色调 - 温暖的橙色调，适合老人应用
  static const Color primaryColor = Color(0xFFE86B4A);
  static const Color primaryLight = Color(0xFFF5A68A);
  static const Color primaryDark = Color(0xFFC94E32);

  /// 辅助色
  static const Color secondaryColor = Color(0xFF4A90E2);
  static const Color successColor = Color(0xFF52C41A);
  static const Color warningColor = Color(0xFFFAAD14);
  static const Color errorColor = Color(0xFFFF4D4F);

  /// 辅助色变体（对应 MaterialColor shade）
  static const Color successLight = Color(0xFFA5D6A7);  // ~green.shade200
  static const Color successDark = Color(0xFF388E3C);   // ~green.shade700
  static const Color successMedium = Color(0xFF66BB6A); // ~green.shade400
  static const Color warningLight = Color(0xFFFFCC80);  // ~orange.shade200
  static const Color warningDark = Color(0xFFF57C00);   // ~orange.shade700
  static const Color errorLight = Color(0xFFFFCDD2);    // ~red.shade100
  static const Color errorMedium = Color(0xFFEF9A9A);   // ~red.shade200
  static const Color errorDark = Color(0xFFD32F2F);     // ~red.shade700
  static const Color errorAccent = Color(0xFFFF5252);   // ~redAccent
  static const Color infoBlue = Color(0xFF2196F3);      // ~blue.shade500
  static const Color infoBlueLight = Color(0xFFBBDEFB); // ~blue.shade100
  static const Color infoBlueDark = Color(0xFF1976D2);  // ~blue.shade700

  /// 背景色
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;

  /// 文字色（textHint 满足 WCAG AAA 对比度标准 7:1）
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF616161);

  /// 灰度色（统一项目中的灰色系使用）
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);

  /// 预定义文本样式（高频组合，统一管理）
  static const TextStyle textTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
  static const TextStyle textSubtitle = TextStyle(fontSize: 14, color: grey600);
  static const TextStyle textCaption = TextStyle(fontSize: 12, color: grey500);
  static const TextStyle textBody = TextStyle(fontSize: 14);
  static const TextStyle textCardTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  /// 渐变配置
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFE86B4A), Color(0xFFFF9A6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 卡片圆角
  static const double cardRadius = 16.0;
  static const double cardRadiusLarge = 20.0;

  /// 按钮圆角
  static const double buttonRadius = 12.0;

  /// 预定义 BorderRadius 常量（统一项目中圆角使用）
  static const BorderRadius radius4 = BorderRadius.all(Radius.circular(4));
  static const BorderRadius radiusXS = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radius6 = BorderRadius.all(Radius.circular(6));
  static const BorderRadius radiusS = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusM = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusL = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radius10 = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(20));
  static const BorderRadius radius2XL = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radius3XL = BorderRadius.all(Radius.circular(32));

  /// 统一间距常量
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacing20Lg = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  /// 预定义 EdgeInsets 常量（高频组合，统一管理）
  static const EdgeInsets paddingAll4 = EdgeInsets.all(4);
  static const EdgeInsets paddingAll8 = EdgeInsets.all(8);
  static const EdgeInsets paddingAll12 = EdgeInsets.all(12);
  static const EdgeInsets paddingAll16 = EdgeInsets.all(16);
  static const EdgeInsets paddingAll20 = EdgeInsets.all(20);
  static const EdgeInsets paddingAll24 = EdgeInsets.all(24);
  static const EdgeInsets paddingH16V8 = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets paddingH16V12 = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets paddingH8V4 = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const EdgeInsets marginBottom8 = EdgeInsets.only(bottom: 8);
  static const EdgeInsets marginBottom12 = EdgeInsets.only(bottom: 12);
  static const EdgeInsets marginTop8 = EdgeInsets.only(top: 8);
  static const EdgeInsets marginTop12 = EdgeInsets.only(top: 12);

  /// 统一用户消息常量
  static const String msgLoadFailed = '加载失败，请重试';
  static const String msgOperationFailed = '操作失败，请稍后重试';
  static const String msgNetworkError = '网络连接失败，请检查网络设置';
  static const String msgSaveSuccess = '保存成功';
  static const String msgDeleteSuccess = '删除成功';

  /// 业务常量
  /// 邻里圈搜索默认半径（米）
  static const double defaultNeighborSearchRadius = 2000.0;

  /// 老人端特殊配置 - 大字体、大按钮、更大圆角
  static ThemeData get elderTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'PingFangSC',
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadiusLarge),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      // 老人端使用更大的字体，适老化设计
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 22), // 老人端正文加大，适老化
      bodyMedium: TextStyle(fontSize: 18),
      bodySmall: TextStyle(fontSize: 16),
      labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontSize: 16),
      labelSmall: TextStyle(fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60), // 大按钮，适老化
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        textStyle: const TextStyle(fontSize: 18),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );

  /// 子女端主题 - 标准大小
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'PingFangSC',
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}