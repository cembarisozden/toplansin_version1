import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

enum UpdateKind { none, soft, mandatory }

class UpdateDecision {
  final UpdateKind kind;
  final String storeUrl;
  final String? message;
  final int snoozeHours; // ⬅️ eklendi

  const UpdateDecision(
      this.kind,
      this.storeUrl, {
        this.message,
        this.snoozeHours = 24,
      });
}

class UpdateService {
  static const _kSnoozeKey = 'update_snooze_until_ms';

  /// RC’yi hazırlar ve karar döner.
  static Future<UpdateDecision> evaluate() async {
    final pkg = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;

    final rc = FirebaseRemoteConfig.instance;

// 🔹 TEST sırasında RC'nin cache'ini kapat (her denemede taze veri)
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ),
    );

    await rc.setDefaults({
      'min_build_android': 0,
      'latest_build_android': currentBuild,
      'store_url_android': '',
      'min_build_ios': 0,
      'latest_build_ios': currentBuild,
      'store_url_ios': '',
      'soft_snooze_hours': 24,
      'update_message_tr': '',
      'force_title_tr': 'Güncelleme Gerekli',
      'soft_title_tr': 'Yeni Sürüm Mevcut',
      'cta_update_tr': 'Güncelle',
      'cta_later_tr': 'Daha Sonra',
    });

    try {
      await rc.fetchAndActivate();
    } catch (_) { /* offline ise defaults */ }

    final message = rc.getString('update_message_tr');
    final snoozeHours = rc.getInt('soft_snooze_hours'); // ⬅️ kullanılacak

    // Mağaza URL'si boşsa paket adına göre otomatik kur
    String storeUrl;
    if (Platform.isAndroid) {
      storeUrl = rc.getString('store_url_android');
      storeUrl = storeUrl.isEmpty
          ? 'https://play.google.com/store/apps/details?id=${pkg.packageName}'
          : storeUrl;
    } else {
      storeUrl = rc.getString('store_url_ios');
      // İstersen burada iOS için otomatik App Store linki kurabilirsin
    }

    final minBuild = Platform.isAndroid
        ? rc.getInt('min_build_android')
        : rc.getInt('min_build_ios');
    final latestBuild = Platform.isAndroid
        ? rc.getInt('latest_build_android')
        : rc.getInt('latest_build_ios');

    if (currentBuild < minBuild) {
      return UpdateDecision(
        UpdateKind.mandatory,
        storeUrl,
        message: message,
        snoozeHours: snoozeHours,
      );
    }

    if (currentBuild < latestBuild) {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final snoozeUntil = prefs.getInt(_kSnoozeKey) ?? 0;
      if (now < snoozeUntil) {
        return UpdateDecision(UpdateKind.none, storeUrl, snoozeHours: snoozeHours);
      }
      return UpdateDecision(
        UpdateKind.soft,
        storeUrl,
        message: message,
        snoozeHours: snoozeHours,
      );
    }

    return UpdateDecision(UpdateKind.none, storeUrl, snoozeHours: snoozeHours);
  }

  static Future<void> snoozeSoft(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now()
        .add(Duration(hours: hours))
        .millisecondsSinceEpoch;
    await prefs.setInt(_kSnoozeKey, until);
  }

  static Future<void> openStore(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
