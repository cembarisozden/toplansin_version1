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


List<String> generateTimeSlots(String startHour, String endHour) {
  final startParts = startHour.split(':');
  final endParts = endHour.split(':');

  int startHourInt = int.parse(startParts[0]);
  int startMinute = int.parse(startParts[1]);
  int endHourInt = int.parse(endParts[0]);
  int endMinute = int.parse(endParts[1]);

  if (endHourInt < startHourInt ||
      (endHourInt == startHourInt && endMinute < startMinute)) {
    endHourInt += 24;
  }

  final slots = <String>[];
  for (int hour = startHourInt; hour < endHourInt; hour++) {
    final startActual = hour % 24;
    final endActual = (hour + 1) % 24;
    slots.add(
        '${startActual.toString().padLeft(2, '0')}:00-${endActual.toString().padLeft(2, '0')}:00');
  }

  slots.sort((a, b) =>
      int.parse(a.split(':')[0]).compareTo(int.parse(b.split(':')[0])));
  return slots;
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
