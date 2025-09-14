// time_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeService {
  static DateTime? _serverUtc;
  static DateTime? _fetchedAtUtc;

  /// Uygulama açılır açılmaz main() içinde çağır:
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await TimeService.init();
  static Future<void> init() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('server_time')
          .doc('now')
          .get();
      final ts = snap.data()?['ts'];
      if (ts is Timestamp) {
        // 1) Firestore Timestamp → UTC DateTime
        _serverUtc = ts.toDate().toUtc();
        // 2) O an cihaz zamanı → UTC
        _fetchedAtUtc = DateTime.now().toUtc();
        print("FETCHED AT UTC: ${_fetchedAtUtc}");
        print("📌 TimeService initialized (UTC): ${nowUtc()}");
        print("📌 TimeService initialized (TR): ${now()}");
      } else {
        print('⚠️ server_time/now.ts bulunamadı.');
      }
    } catch (e) {
      print('⛔ TimeService.init() hatası: $e');
    }
  }

  /// ------------- FONKSİYONLAR -------------

  /// 1) Sunucu zamanı (UTC) → createdAt vs için kullan
  static DateTime nowUtc() {
    if (_serverUtc == null || _fetchedAtUtc == null) {
      print("⚠️ Server zamanı alınmadı, fallback UTC kullanılıyor.");
      return DateTime.now().toUtc();
    }
    final elapsed = DateTime.now().toUtc().difference(_fetchedAtUtc!);
    return _serverUtc!.add(elapsed);
  }

  /// 2) Türkiye saati (UTC+3) → rezervasyon kontrolleri / UI için kullan
  static DateTime now() {
    return nowUtc().add(const Duration(hours: 3));
  }

  /// İstersen tekrar senkronize etmek için
  static Future<void> sync() => init();

  /// İki zaman arasındaki farkı insan okunur formata çevirir
  static String formatTimeDifference(DateTime dt1, DateTime dt2) {
    final diff = dt1.difference(dt2);
    return "${diff.inHours} saat, ${diff.inMinutes % 60} dakika, ${diff.inSeconds % 60} saniye";
  }
}
