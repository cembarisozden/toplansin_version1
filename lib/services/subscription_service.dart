import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:toplansin/services/time_service.dart';

// ---------------------------------------------------------------------------
// Güvenli Snackbar gösterimi (ScaffoldMessenger.maybeOf + fallback)
// ---------------------------------------------------------------------------
void _safeShowSnackBar(BuildContext ctx, String msg, Color bg) {
  final messenger = ScaffoldMessenger.maybeOf(ctx);
  if (messenger != null) {
    messenger.showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  } else {
    // Dialog veya dispose edilmiş context – bir sonraki frame’de kök overlay’e gönder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rootCtx = Navigator.of(ctx, rootNavigator: true).overlay?.context;
      if (rootCtx != null) {
        ScaffoldMessenger.of(rootCtx)
            .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
      }
    });
  }
}

void _showSuccess(BuildContext ctx, String msg) =>
    _safeShowSnackBar(ctx, msg, Colors.green.shade600);

void _showError(BuildContext ctx, dynamic error, {String ctxLabel = ''}) {
  final msg = AppErrorHandler.getMessage(error, context: ctxLabel);
  _safeShowSnackBar(ctx, msg, Colors.red.shade600);
}

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
    _showSuccess(context, 'Abonelik isteği gönderildi');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
    rethrow;
  }
}

Future<void> userAboneIstegiIptalEt(
    BuildContext context, String subscriptionDocId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionDocId)
        .update({'status': 'İptal Edildi'});
    _showSuccess(context, 'Abonelik isteği iptal edildi');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
  }
}

Future<void> approveSubscription(
    BuildContext context, String subscriptionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({'status': 'Aktif', 'lastUpdatedBy': 'owner'});
    _showSuccess(context, 'Abonelik onaylandı');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
    rethrow;
  }
}

Future<void> cancelSubscription(
    BuildContext context, String subscriptionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({'status': 'İptal Edildi', 'lastUpdatedBy': 'owner'});
    _showSuccess(context, 'Abonelik iptal edildi');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
  }
}

Future<void> userCancelSubscription(
    BuildContext context, String subscriptionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({'status': 'Sona Erdi', 'lastUpdatedBy': 'user'});
    _showSuccess(context, 'Abonelik sona erdi');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
  }
}

Future<void> ownerCancelSubscription(
    BuildContext context, String subscriptionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({'status': 'Sona Erdi', 'lastUpdatedBy': 'owner'});
    _showSuccess(context, 'Abonelik sona erdi');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
  }
}

Future<void> ownerRejectSubscription(
    BuildContext context, String subscriptionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({'status': 'İptal Edildi', 'lastUpdatedBy': 'owner'});
    _showSuccess(context, 'Abonelik reddedildi');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
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
  try {
    final col = FirebaseFirestore.instance.collection('subscriptions');
    final createdAt = TimeService.now();
    final startDate = calculateFirstSession(createdAt, dayOfWeek, time);

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
      visibleSession: startDate,
      nextSession: startDate,
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

    _showSuccess(context, 'Abonelik oluşturuldu');
  } catch (e) {
    _showError(context, e, ctxLabel: 'subscription');
  }
}

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

String calculateFirstSession(DateTime createdAt, int dayOfWeek, String time) {
  final daysUntilTarget = (dayOfWeek - createdAt.weekday + 7) % 7;
  final targetDay = createdAt.add(Duration(days: daysUntilTarget + 7));

  final hour = int.parse(time.split('-').first.split(':')[0]);
  final minute = int.parse(time.split('-').first.split(':')[1]);

  final sessionDateTime =
      DateTime(targetDay.year, targetDay.month, targetDay.day, hour, minute);
  final formattedDate = DateFormat('yyyy-MM-dd').format(sessionDateTime);
  return '$formattedDate $time';
}

String calculateNextSession(String currentSession) {
  final parts = currentSession.split(' ');
  if (parts.length != 2) return currentSession;
  final date =
      DateFormat('yyyy-MM-dd').parse(parts[0]).add(const Duration(days: 7));
  return '${DateFormat('yyyy-MM-dd').format(date)} ${parts[1]}';
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
