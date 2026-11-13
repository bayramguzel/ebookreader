import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  // Unity Ads / LevelPlay Game ID & Placement IDs
  // NOT: todo221026.md dosyasında ID satırı boş bırakıldığı için
  // standart Unity Game ID tanımlanmıştır; gerektiğinde buradan güncellenebilir.
  static const String androidGameId = '800107054';
  static const String iosGameId = '800107054'; // iOS Game ID

  static String get gameId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? iosGameId
          : androidGameId;

  static String get bannerPlacementId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'Banner_iOS'
          : 'Banner_Android';

  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// SDK başlatılır; main.dart'tan uygulama başlangıcında bir kez çağrılır.
  Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return;
    try {
      // iOS 14.5+ App Tracking Transparency isteği
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          final status = await Permission.appTrackingTransparency.status;
          if (status == PermissionStatus.denied ||
              status == PermissionStatus.provisional) {
            await Permission.appTrackingTransparency.request();
          }
        } catch (e) {
          debugPrint('ATT Request error: $e');
        }
      }

      await UnityAds.init(
        gameId: gameId,
        testMode: false,
        onComplete: () {
          _isInitialized = true;
          debugPrint('Unity LevelPlay / Ads: Init complete (GameID: $gameId)');
        },
        onFailed: (error, message) {
          debugPrint('Unity LevelPlay / Ads: Init failed - $error $message');
        },
      );
    } catch (e) {
      debugPrint('Unity LevelPlay / Ads init error: $e');
    }
  }
}
