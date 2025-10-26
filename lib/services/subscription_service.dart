import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:toplansin/services/firebase_functions_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';

// ---------------------------------------------------------------------------
// Güvenli Snackbar gösterimi (ScaffoldMessenger.maybeOf + fallback)
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// CRUD ► Abonelik işlemleri (tamamı merkezi Snackbar + AppErrorHandler)
// ---------------------------------------------------------------------------

Future<void> aboneOl(BuildContext context, Subscription sub) async {
  try {
    final col = FirebaseFirestore.instance.collection('subscriptions');

    // Aynı saha-gün-saat için daha önce iptal / sona ermiş kayıt var mı?
    final existing = await col
        .where('haliSahaId', isEqualTo: sub.haliSahaId)
        .where('dayOfWeek', isEqualTo: sub.dayOfWeek)
        .where('time', isEqualTo: sub.time)
        .where('status', whereIn: ['İptal Edildi', 'Sona Erdi'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Varsa o dokümanı güncelle
      await col
          .doc(existing.docs.first.id)
          .set(sub.toMap(), SetOptions(merge: true));
    } else {
      // Yoksa yeni doküman oluştur
      await col.add(sub.toMap());
    }

    // Kullanıcıya her iki durumda da aynı mesaj
   AppSnackBar.success(context, "Abonelik isteği gönderildi!");
  } catch (e) {
    final msg=AppErrorHandler.getMessage(e);
    AppSnackBar.error(context, msg);;
    rethrow;
  }
}

Future<void> userAboneIstegiIptalEt(
    BuildContext context, String subscriptionDocId) async {
  showLoader(context);
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionDocId)
        .update({'status': 'İptal Edildi'});
    AppSnackBar.show(context, "Abonelik isteği iptal edildi.");
  } catch (e) {
    final msg=AppErrorHandler.getMessage(e);
    AppSnackBar.error(context, msg);
  }finally {
    hideLoader();
  }
}

Future<void> approveSubscription(BuildContext context, String subscriptionId) async {
  showLoader(context);
  try {
    final docRef = FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw Exception('Abonelik bulunamadı.');
      }

      final data = snap.data() as Map<String, dynamic>;

      // Zaten onaylanmış / iptal ise dokunma (idempotent davranış)
      if (data['status'] != 'Beklemede') {
        return;
      }

      // dayOfWeek: 1=Mon..7=Sun, time: "HH:mm-HH:mm"
      final int dayOfWeek = (data['dayOfWeek'] as num).toInt();
      final String time = (data['time'] as String);

      // 🔁 Onay anında ilk seansı BUGÜNE göre yeniden hesapla
      final String firstSession = calculateFirstSession(dayOfWeek, time);

      // Tek seferde tüm alanları senkronla
      tx.update(docRef, {
        'status': 'Aktif',
        'lastUpdatedBy': 'owner',
        'firstSession': firstSession,
        'nextSession': firstSession,    // pointer başlangıçta firstSession ile aynı
        'visibleSession': firstSession, // UI da aynı tarihi göstersin
      });
    });

    AppSnackBar.show(context, "Abonelik onaylandı!");
  } catch (e) {
    final msg = AppErrorHandler.getMessage(e);
    AppSnackBar.error(context, msg);
    rethrow;
  } finally {
    hideLoader();
  }
}




Future<void> userCancelSubscription(
    BuildContext context, String subscriptionId) async {
  showLoader(context);
  try {
    final batch = FirebaseFirestore.instance.batch();

    // 1) Aboneliği sona erdir
    final subRef = FirebaseFirestore.instance.collection('subscriptions').doc(subscriptionId);
    batch.update(subRef, {
      'status': 'Sona Erdi',
      'lastUpdatedBy': 'user',
    });

    // 2) İlgili rezervasyonları bul ve iptal et
    final reservationsSnap = await FirebaseFirestore.instance
        .collection('reservations')
        .where('subscriptionId', isEqualTo: subscriptionId)
        .where('status', isEqualTo: 'Onaylandı')
        .get();

    for (final doc in reservationsSnap.docs) {
      batch.update(doc.reference, {
        'status': 'İptal Edildi',
        'lastUpdatedBy': 'user',
      });
    }

    await batch.commit();

    AppSnackBar.success(context,"Abonelik başarıyla sona erdirildi");
  } catch (e) {
    final msg = AppErrorHandler.getMessage(e);
    AppSnackBar.error(context, msg);
  } finally {
    hideLoader();
  }
}


Future<void> ownerCancelSubscription(
    BuildContext context, String subscriptionId) async {
  showLoader(context);
  try {
    final batch = FirebaseFirestore.instance.batch();

    // 1) Aboneliği sona erdir
    final subRef = FirebaseFirestore.instance.collection('subscriptions').doc(subscriptionId);
    batch.update(subRef, {
      'status': 'Sona Erdi',
      'lastUpdatedBy': 'owner',
    });

    // 2) İlgili rezervasyonları bul ve iptal et
    final reservationsSnap = await FirebaseFirestore.instance
        .collection('reservations')
        .where('subscriptionId', isEqualTo: subscriptionId)
        .where('status', isEqualTo: 'Onaylandı')
        .get();

    for (final doc in reservationsSnap.docs) {
      batch.update(doc.reference, {
        'status': 'İptal Edildi',
        'lastUpdatedBy': 'owner',
      });
    }

    await batch.commit();

    AppSnackBar.success(context,"Abonelik ve ilgili rezervasyonlar başarıyla sona erdirildi");
  } catch (e) {
    AppSnackBar.error(context,"Abonelik iptal edilemedi!");
  } finally {
    hideLoader();
  }
}

Future<void> ownerRejectSubscription(
    BuildContext context, String subscriptionId) async {
  showLoader(context);
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({'status': 'İptal Edildi', 'lastUpdatedBy': 'owner'});
    AppSnackBar.show(context, 'Abonelik isteği başarıyla reddedildi');
  } catch (e) {
    final msg=AppErrorHandler.getMessage(e);
    AppSnackBar.error(context, msg);
  }finally{
    hideLoader();
  }
}

Future<void> addOwnerSubscription({
  required BuildContext context,
  required String haliSahaId,
  required String haliSahaName,
  required String location,
  required int dayOfWeek,
  required String time,
  required num price,
  required String ownerUserId,
  required String ownerName,
  required String ownerPhone,
  required String ownerEmail,
}) async {
  showLoader(context);
  try {
    final col = FirebaseFirestore.instance.collection('subscriptions');
    final startDate = calculateFirstSession(dayOfWeek, time);

    final subscription = Subscription(
      docId: '',
      haliSahaId: haliSahaId,
      userId: ownerUserId,
      haliSahaName: haliSahaName,
      location: location,
      dayOfWeek: dayOfWeek,
      time: time,
      price: price,
      startDate: startDate,
      endDate: '',
      nextSession: startDate,
      visibleSession: startDate,
      lastUpdatedBy: 'owner',
      status: 'Aktif',
      userName: ownerName,
      userPhone: ownerPhone,
      userEmail: ownerEmail,
    );

    // Aynı saha-gün-saat için iptal / sona ermiş eski kayıt var mı?
    final existing = await col
        .where('haliSahaId', isEqualTo: haliSahaId)
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .where('time', isEqualTo: time)
        .where('status', whereIn: ['İptal Edildi', 'Sona Erdi'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Eski belgeyi güncelle
      await col.doc(existing.docs.first.id).set(subscription.toMap());
    } else {
      // Yeni belge oluştur
      await col.add(subscription.toMap());
    }

    AppSnackBar.show(context, "Abonelik oluşuturldu.");
  } catch (e) {
    final msg=AppErrorHandler.getMessage(e);
    AppSnackBar.error(context, msg);
  }finally{
    hideLoader();
  }
}

Future<void> cancelThisWeekSlot(String subscriptionId, BuildContext context) async {
  showLoader(context);
  try {
    final callable = functions.httpsCallable('cancelThisWeekSlot');

    final response = await callable.call({
      "subscriptionId": subscriptionId,
    });

    AppSnackBar.success(context, "Bu haftaki seans başarıyla iptal edildi.");
  } catch (error) {
    final msg=AppErrorHandler.getMessage(error);
    AppSnackBar.error(context, msg);
  }finally{
    hideLoader();
  }
}

/// 0..6 gün indeksine (start,end) döner ve koleksiyon boş mu dolu mu bilgisini verir.
Future<({
bool useOverrides,
Map<int, ({String start, String end})> map,
})> loadStartEndOverrides(String haliSahaId) async {
  final col = FirebaseFirestore.instance
      .collection('hali_sahalar')
      .doc(haliSahaId)
      .collection('start_end_hours');

  final snap = await col.get();
  final map = <int, ({String start, String end})>{};

  for (final doc in snap.docs) {
    final data = doc.data();
    final day = int.tryParse(doc.id) ?? (data['day'] as int? ?? -1);
    if (day < 0 || day > 6) continue;

    final s = (data['startHour'] as String? ?? '').trim();
    final e = (data['endHour']   as String? ?? '').trim();
    map[day] = (start: s, end: e);
  }

  return (useOverrides: snap.docs.isNotEmpty, map: map);
}


// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------


/// time = "HH:mm-HH:mm"  (örn: "19:00-20:00")
/// dayOfWeek: 1=Mon ... 7=Sun (DateTime.weekday ile uyumlu)
String calculateFirstSession(int dayOfWeek, String time) {
  final now = TimeService.now(); // TR'ye göre çalıştığını varsayıyoruz

  final start = time.split('-').first; // "HH:mm"
  final hhmm = start.split(':');
  final hour = int.parse(hhmm[0]);
  final minute = int.parse(hhmm[1]);

  final rawDelta = (dayOfWeek - now.weekday + 7) % 7;

  // KURAL: bugün (rawDelta==0) ise → +14 gün, değilse → rawDelta gün
  final daysToAdd = (rawDelta == 0) ? 14 : rawDelta +7;

  final targetDay = DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
  final sessionStart = DateTime(targetDay.year, targetDay.month, targetDay.day, hour, minute);

  final ymd = DateFormat('yyyy-MM-dd').format(sessionStart);
  return '$ymd $time'; // "YYYY-MM-DD HH:mm-HH:mm"
}

int _toMinutes(String hhmm) {
  final p = hhmm.split(':');
  final h = int.parse(p[0]);
  final m = int.parse(p[1]);
  return h * 60 + m;
}

String _fmt(int totalMinutes) {
  final m = totalMinutes % (24 * 60);
  final h = (m ~/ 60) % 24;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

/// 24:00’ı aşan bitişleri düzgün göstermek için (örn. 24:30 -> 00:30)
String _fmtWrap(int mins) {
  const int DAY = 24 * 60;
  final m = ((mins % DAY) + DAY) % DAY;
  return _fmt(m);
}

({String start, String end}) _hoursForDay({
  required int dayIdx, // 0=Pt..6=Pz
  required bool useOverrides,
  required Map<int, ({String start, String end})> overrides,
  required String defaultStart,
  required String defaultEnd,
}) {
  if (useOverrides) {
    final h = overrides[dayIdx];
    if (h == null || h.start.isEmpty || h.end.isEmpty) {
      // veri tutarsızlığına karşı güvenlik
      return (start: '', end: '');
    }
    return (start: h.start, end: h.end);
  }
  return (start: defaultStart.trim(), end: defaultEnd.trim());
}




/// Seçilen tarih için slotları üretir.
/// - Önceki günden taşan 00:00..prevEnd hizalı şekilde eklenir
/// - Bugün cross-midnight ise sadece start..24:00 eklenir
List<String> generateTimeSlotsForDate({
  required DateTime date,
  required bool useOverrides,
  required Map<int, ({String start, String end})> overrides,
  required String defaultStart,
  required String defaultEnd,
  int durationMinutes = 60,
}) {
  final dIdx    = date.weekday - 1;              // 0..6
  final prevIdx = (dIdx - 1) < 0 ? 6 : dIdx - 1; // önceki gün
  const int DAY = 24 * 60;

  final prev = _hoursForDay(
    dayIdx: prevIdx,
    useOverrides: useOverrides,
    overrides: overrides,
    defaultStart: defaultStart,
    defaultEnd: defaultEnd,
  );
  final today = _hoursForDay(
    dayIdx: dIdx,
    useOverrides: useOverrides,
    overrides: overrides,
    defaultStart: defaultStart,
    defaultEnd: defaultEnd,
  );

  // Kapalı günse tamamen boş dön (dünden sarkan parçayı da göstermiyoruz)
  if (today.start.isEmpty || today.end.isEmpty) return const [];

  final prevStart  = _toMinutes(prev.start.isEmpty ? defaultStart : prev.start);
  final prevEndRaw = _toMinutes(prev.end.isEmpty   ? defaultEnd   : prev.end);

  final todayStart  = _toMinutes(today.start);
  final todayEndRaw = _toMinutes(today.end);

  final slots = <String>[];

  // ---- A) D-1 -> D'ye taşan kısım: 00:00..prevEnd (cross-midnight ise, hizalı)
  if (prevEndRaw <= prevStart) {
    final mod   = prevStart % durationMinutes;
    final first = (mod == 0) ? 0 : (durationMinutes - mod);
    for (int t = first; t + durationMinutes <= prevEndRaw; t += durationMinutes) {
      final a = _fmt(t);                    // örn 00:30
      final b = _fmt(t + durationMinutes);  // örn 01:30
      slots.add('$a-$b');                   // bugüne ait
    }
  }

  // ---- B) Bugünün kendi kısmı
  if (todayEndRaw <= todayStart) {
    // BUGÜN cross-midnight: bugünde başlayan tüm slotlar (start..24:00)
    // ÖNEMLİ: t < DAY; bitiş 24:00’ı aşabilir → _fmtWrap ile düzgün yazdır
    for (int t = todayStart; t < DAY; t += durationMinutes) {
      final start = _fmt(t);
      final end   = _fmtWrap(t + durationMinutes); // 24:30 -> 00:30
      slots.add('$start-$end');                    // 23:30-00:30 görünür
    }
    // 00:00..todayEnd yarına ait; yarın üretilecek
  } else {
    // Normal gün: start..end (bitiş gün içinde kaldığı için <= kontrolü doğru)
    for (int t = todayStart; t + durationMinutes <= todayEndRaw; t += durationMinutes) {
      final a = _fmt(t);
      final b = _fmt(t + durationMinutes);
      slots.add('$a-$b');
    }
  }

  // Çiftleri temizle
  final seen = <String>{};
  return slots.where(seen.add).toList();
}



String getDayName(String id) {
  const dayMap = {
    'Pzt': 'Pazartesi',
    'Sal': 'Salı',
    'Çar': 'Çarşamba',
    'Per': 'Perşembe',
    'Cum': 'Cuma',
    'Cmt': 'Cumartesi',
    'Paz': 'Pazar',
  };
  return dayMap[id] ?? id;
}

int getDayOfWeekNumber(String day) {
  const map = {
    'Pzt': 1,
    'Sal': 2,
    'Çar': 3,
    'Per': 4,
    'Cum': 5,
    'Cmt': 6,
    'Paz': 7,
  };
  return map[day]!;
}
