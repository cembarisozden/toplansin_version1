import 'package:cloud_firestore/cloud_firestore.dart';

class TimeService {
  static DateTime? _serverTime;
  static DateTime? _fetchedAt;
  static const Duration _utcOffset = Duration(hours: 3); // UTC+3 için Türkiye zaman dilimi

  static Future<void> init() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('server_time')
          .doc('now')
          .get();

      final ts = snap.data()?['ts'];
      if (ts != null && ts is Timestamp) {
        // Timestamp'i UTC'den UTC+3'e çevir
        final rawServerTime = ts.toDate();
        final localServerTime = rawServerTime.add(_utcOffset);

        _serverTime = localServerTime;
        _fetchedAt = DateTime.now();

        print("📌 TimeService initialized: ${TimeService.now()}");
      } else {
        print('⚠️ server_time/now.ts alanı bulunamadı.');
      }
    } catch (e) {
      print('⛔ Server saat alınırken hata oluştu: $e');
    }
  }

  static DateTime now() {
    if (_serverTime == null || _fetchedAt == null) {
      print("⚠️ Server saati henüz alınmadı, cihaz saati kullanılıyor.");
      return DateTime.now(); // fallback
    }

    // Cihaz saatinden bağımsız olarak, geçen süreyi hesapla
    final elapsed = DateTime.now().difference(_fetchedAt!);

    // Server saatini güncelle
    final currentServerTime = _serverTime!.add(elapsed);

    return currentServerTime;
  }

  // Yeniden senkronizasyon ihtiyacı olduğunda çağrılabilir
  static Future<void> sync() async {
    await init();
  }

  // İki tarih arasındaki farkı gösteren yardımcı fonksiyon
  static String formatTimeDifference(DateTime dt1, DateTime dt2) {
    final diff = dt1.difference(dt2);
    return "${diff.inHours} saat, ${diff.inMinutes % 60} dakika, ${diff.inSeconds % 60} saniye";
  }
}