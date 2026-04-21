# 高德地图配置指南

## 1. 注册高德开发者账号

1. 访问 [高德开放平台](https://lbs.amap.com/)
2. 注册账号并完成开发者认证（个人开发者认证后有每日 30万次免费额度）

## 2. 创建应用并获取 API Key

1. 登录高德开放平台，进入「应用管理」
2. 创建新应用，填写应用名称（如：关爱老人）
3. 为应用添加 Key：
   - **Android 平台**：
     - 选择「Android平台」
     - 填写包名：`com.example.care_for_the_old_client`
     - 获取 Android Key
   - **iOS 平台**（如需支持）：
     - 选择「iOS平台」
     - 填写 Bundle ID
     - 获取 iOS Key

## 3. 配置 Android Key

修改 `android/app/src/main/AndroidManifest.xml`：

```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="YOUR_AMAP_ANDROID_KEY" />  <!-- 替换为你的 Android Key -->
```

## 4. 配置 iOS Key（可选）

如果支持 iOS，修改 `ios/Runner/Info.plist`：

```xml
<key>AMapApiKey</key>
<string>YOUR_AMAP_IOS_KEY</string>
```

并添加隐私合规配置：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要获取您的位置信息以追踪老人位置</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>需要持续获取位置以实时追踪老人</string>
```

## 5. 验证配置

运行应用，打开子女端的老人位置页面，应能看到地图和老人位置标记。

## 注意事项

- **隐私合规**：首次使用时需要用户同意隐私政策，代码中已配置默认同意声明
- **免费额度**：个人开发者认证后每日 30万次调用，足够小规模应用使用
- **商用说明**：个人开发者认证后可用于商业项目

## 相关链接

- [高德开放平台](https://lbs.amap.com/)
- [开发者认证说明](https://lbs.amap.com/faq/quota/cons/44815)
- [个人开发者商用FAQ](https://lbs.amap.com/faq/quota/cons/44968)
- [API配额说明](https://lbs.amap.com/api/static-resource-summary)