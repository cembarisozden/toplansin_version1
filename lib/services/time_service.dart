import 'package:cloud_firestore/cloud_firestore.dart';

class TimeService {
  static DateTime? _serverTime;
  static DateTime? _fetchedAt;

  static Future<void> init() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('server_time')
          .doc('now')
          .get();

      final ts = snap.data()?['ts'];
      if (ts != null && ts is Timestamp) {
        // UTC'den cihazın yerel saat dilimine çevir
        final localServerTime = ts.toDate().toLocal();

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

  static Future<void> sync() async {
    await init();
  }

  static String formatTimeDifference(DateTime dt1, DateTime dt2) {
    final diff = dt1.difference(dt2);
    return "${diff.inHours} saat, ${diff.inMinutes % 60} dakika, ${diff.inSeconds % 60} saniye";
  }
}
