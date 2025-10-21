// time_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class TimeService {
  static DateTime? _serverUtc;
  static DateTime? _fetchedAtUtc;
  static late tz.Location _istanbul;
  static bool _tzReady = false;

  /// Uygulama açılırken main()'de çağır:
  /// WidgetsFlutterBinding.ensureInitialized();
  /// tz.initializeTimeZones();
  /// await TimeService.init();
  static Future<void> init() async {
    try {
      if (!_tzReady) {
        tz.initializeTimeZones();
        _istanbul = tz.getLocation('Europe/Istanbul');
        _tzReady = true;
      }

      final snap = await FirebaseFirestore.instance
          .collection('server_time')
          .doc('now')
          .get();

      final ts = snap.data()?['ts'];
      if (ts is Timestamp) {
        _serverUtc = ts.toDate().toUtc();
        _fetchedAtUtc = DateTime.now().toUtc();
        _log('✅ TimeService initialized | UTC=${nowUtc()} | TR=${now()}');
      } else {
        _log('⚠️ server_time/now.ts bulunamadı, cihaz saatine fallback.');
        _serverUtc = DateTime.now().toUtc();
        _fetchedAtUtc = _serverUtc;
      }
    } catch (e) {
      _log('⛔ TimeService.init() hatası: $e');
      _serverUtc = DateTime.now().toUtc();
      _fetchedAtUtc = _serverUtc;
    }
  }

  /// 🔹 Sunucu tabanlı UTC zamanı (drift telafili)
  static DateTime nowUtc() {
    if (_serverUtc == null || _fetchedAtUtc == null) {
      _log("⚠️ Server zamanı alınmadı, fallback UTC kullanılıyor.");
      return DateTime.now().toUtc();
    }
    final elapsed = DateTime.now().toUtc().difference(_fetchedAtUtc!);
    return _serverUtc!.add(elapsed);
  }

  /// 🔹 Türkiye saati (Europe/Istanbul) — UI veya rezervasyon için
  static DateTime now() {
    final utc = nowUtc();
    final ist = _istanbulIfReady();
    return tz.TZDateTime.from(utc, ist);
  }

  /// 🔹 Firestore Timestamp → İstanbul saati
  static DateTime? fromTimestamp(dynamic ts) {
    if (ts is! Timestamp) return null;
    final utc = ts.toDate().toUtc();
    return tz.TZDateTime.from(utc, _istanbulIfReady());
  }

  /// 🔹 DateTime (UTC veya local) → İstanbul saati
  static DateTime toIstanbul(DateTime dt) {
    return tz.TZDateTime.from(dt.toUtc(), _istanbulIfReady());
  }

  /// 🔹 Format helper (örn. UI'de gösterim)
  static String formatTr(DateTime? dt,
      {String pattern = 'dd MMM yyyy, HH:mm', String locale = 'tr_TR'}) {
    if (dt == null) return '-';
    final ist = toIstanbul(dt);
    return DateFormat(pattern, locale).format(ist);
  }

  /// 🔹 Senkronizasyonu elle tetiklemek için
  static Future<void> sync() => init();

  /// 🔹 Farkı okunabilir formatta döndürür
  static String formatDifference(DateTime dt1, DateTime dt2) {
    final diff = dt1.difference(dt2);
    return "${diff.inHours} saat, ${diff.inMinutes % 60} dk, ${diff.inSeconds % 60} sn";
  }

  static tz.Location _istanbulIfReady() {
    if (!_tzReady) {
      tz.initializeTimeZones();
      _istanbul = tz.getLocation('Europe/Istanbul');
      _tzReady = true;
    }
    return _istanbul;
  }

  static void _log(Object msg) {
    // ignore: avoid_print
    print(msg);
  }
}
