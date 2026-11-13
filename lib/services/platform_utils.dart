import 'dart:io';
import 'package:flutter/material.dart';
// ignore: deprecated_member_use
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformUtils {
  // App Store & Play Store ID tanımları
  static const String androidPackageName = 'com.software41.ebookreader';
  static const String iosAppId = '6470000000'; // Kullanıcı App Store Connect ID'siyle güncelleyebilir

  static String get storeUrl {
    if (Platform.isIOS) {
      return 'https://apps.apple.com/app/id$iosAppId';
    } else {
      return 'https://play.google.com/store/apps/details?id=$androidPackageName';
    }
  }

  static Future<void> openStoreRating() async {
    if (Platform.isIOS) {
      final Uri appStoreUri = Uri.parse(
        'itms-apps://itunes.apple.com/app/id$iosAppId?action=write-review',
      );
      final Uri webUri = Uri.parse('https://apps.apple.com/app/id$iosAppId');
      if (!await launchUrl(appStoreUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } else {
      final Uri marketUri = Uri.parse('market://details?id=$androidPackageName');
      final Uri webUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPackageName',
      );
      if (!await launchUrl(marketUri, mode: LaunchMode.externalApplication)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// iPadOS için güvenli Share fonksiyonu (sharePositionOrigin ile crash'i önler)
  static Future<void> shareText(
    String text, {
    BuildContext? context,
    String? subject,
  }) async {
    Rect? sharePositionOrigin;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    // ignore: deprecated_member_use
    await Share.share(
      text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// iPadOS için güvenli ShareXFiles fonksiyonu
  static Future<void> shareFiles(
    List<XFile> files, {
    BuildContext? context,
    String? text,
    String? subject,
  }) async {
    Rect? sharePositionOrigin;
    if (context != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      files,
      text: text,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
