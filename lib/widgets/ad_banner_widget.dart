import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_service.dart';

/// Unity Ads Banner widget'ı:
/// - Reklam gelmediği/boş kaldığı durumlarda `assets/banner.jpg` gösterir ve 41software.com adresine yönlendirir.
/// - Unity banner yüklendiğinde fallback kaybolur ve orijinal Unity banner görünür.
/// - 30 saniyede bir banner otomatik olarak tekrar denenir.
class AdBannerWidget extends StatefulWidget {
  final double height;

  const AdBannerWidget({
    super.key,
    this.height = 50.0,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with WidgetsBindingObserver {
  bool _isUnityLoaded = false;
  int _bannerAdKey = 0;
  Timer? _retryTimer;

  static const String _adFallbackUrl = 'https://www.41software.com';
  static const Duration _retryInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRetryTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isUnityLoaded) {
        _startRetryTimer();
      }
    } else if (state == AppLifecycleState.paused) {
      _retryTimer?.cancel();
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    if (kIsWeb) return;
    _retryTimer = Timer.periodic(_retryInterval, (timer) {
      if (!mounted) return;
      if (!_isUnityLoaded) {
        setState(() {
          _bannerAdKey++;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _launchFallbackUrl() async {
    final uri = Uri.parse(_adFallbackUrl);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Could not launch $_adFallbackUrl: $e');
    }
  }

  Widget _buildFallbackBanner() {
    return GestureDetector(
      onTap: _launchFallbackUrl,
      child: Container(
        width: double.infinity,
        height: widget.height,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/banner.jpg',
            height: widget.height,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/banner.png',
                height: widget.height,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildFallbackBanner();
    }

    return Container(
      width: double.infinity,
      height: widget.height,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Unity banner yüklenmediğinde fallback banner görünür ve 41software.com'a yönlendirir
          if (!_isUnityLoaded) _buildFallbackBanner(),

          // Unity Ads Banner: yüklendiğinde görünür ve tıklanabilir olur
          Opacity(
            opacity: _isUnityLoaded ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_isUnityLoaded,
              child: UnityBannerAd(
                key: ValueKey(_bannerAdKey),
                placementId: AdService.bannerPlacementId,
                size: BannerSize.standard,
                onLoad: (placementId) {
                  debugPrint('Unity Banner loaded: $placementId');
                  if (mounted && !_isUnityLoaded) {
                    setState(() {
                      _isUnityLoaded = true;
                    });
                  }
                },
                onClick: (placementId) =>
                    debugPrint('Unity Banner clicked: $placementId'),
                onFailed: (placementId, error, message) {
                  debugPrint('Unity Banner failed: $error $message');
                  if (mounted && _isUnityLoaded) {
                    setState(() {
                      _isUnityLoaded = false;
                    });
                    _startRetryTimer();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Geriye dönük uyumluluk
typedef AdBanner = AdBannerWidget;
