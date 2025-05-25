import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';

class UserNotificationProvider with ChangeNotifier {
  int _reservationCount  = 0;
  int _subscriptionCount = 0;

  final List<Map<String, dynamic>> _notifications = [];
  final List<Reservation>          _userReservations = [];

  int get reservationCount => _reservationCount;
  int get subscriptionCount => _subscriptionCount;
  int get totalCount        => _reservationCount + _subscriptionCount;

  List<Map<String, dynamic>> get notifications    => _notifications;
  List<Reservation>          get userReservations => _userReservations;

  StreamSubscription? _resListener;
  StreamSubscription? _subListener;

  /* --------------- Dinlemeyi başlat --------------- */
  void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _resListener?.cancel();
    _subListener?.cancel();

    final now        = TimeService.now();
    final todayStart = DateTime(now.year, now.month, now.day); // 00:00

    /* ============ 1) REZERVASYON LOGLARI ============ */
    _resListener = FirebaseFirestore.instance
        .collection('reservation_logs')
        .where('userId',    isEqualTo: uid)
        .where('newStatus', whereIn: ['Onaylandı', 'İptal Edildi'])
        .where('by',        isEqualTo: 'owner')
        .snapshots()
        .listen((snap) {
      _userReservations.clear();
      _notifications.removeWhere((n) => n['type'] == 'reservation');

      for (final doc in snap.docs) {
        final data       = doc.data();
        final createdAt  = data['createdAt'] as Timestamp?;
        final resDateStr = data['reservationDateTime'] as String?;
        if (createdAt == null || resDateStr == null) continue;

        final resDate = DateTime.tryParse(resDateStr.split(' ').first);
        if (resDate == null || resDate.isBefore(todayStart)) continue; // ↺ BUGÜN+GELECEK

        final reservation = Reservation.fromDocument(doc);
        _userReservations.add(reservation);

        _notifications.add({
          'type'       : 'reservation',
          'title'      : data['newStatus'] == 'Onaylandı'
              ? 'Rezervasyon Onaylandı'
              : 'Rezervasyon İptal Edildi',
          'subtitle'   : '$resDateStr tarihli rezervasyonunuz '
              '${data['newStatus'].toLowerCase()}.',
          'createdAtMs': createdAt.millisecondsSinceEpoch,
        });
      }

      _reservationCount = _userReservations.length;
      _sortByCreatedAt();
      notifyListeners();
    });

    /* ============ 2) ABONELİK LOGLARI ============== */
    _subListener = FirebaseFirestore.instance
        .collection('subscription_logs')
        .where('userId',    isEqualTo: uid)
        .where('newStatus', whereIn: ['Aktif', 'İptal Edildi', 'Sona Erdi'])
        .where('by',        isEqualTo: 'owner')
        .snapshots()
        .listen((snap) {
      _notifications.removeWhere((n) => n['type'] == 'subscription');

      for (final doc in snap.docs) {
        final data       = doc.data();
        final createdAt  = data['createdAt'] as Timestamp?;
        final int? dayNum = data ['dayOfWeek'] as int;
        final String time = data['time'] as String? ?? '';
        const days = [
          'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
          'Cuma', 'Cumartesi', 'Pazar'
        ];
        final dayText = (dayNum != null && dayNum >= 1 && dayNum <= 7)
            ? 'Her ${days[dayNum - 1]}'
            : '';
        final startDate   = data['startDate'] as String?;
        if (createdAt == null || startDate == null) continue;

        final nextDate = DateTime.tryParse(startDate.split(' ').first);
        if (nextDate == null || nextDate.isBefore(todayStart)) continue; // ↺ BUGÜN+GELECEK

        final status = data['newStatus'];
        final title  = status == 'Aktif'
            ? 'Abonelik Onaylandı'
            : (status == 'İptal Edildi'
            ? 'Abonelik İptal Edildi'
            : 'Abonelik Sona Erdi');

        _notifications.add({
          'type'       : 'subscription',
          'title'      : title,
          'subtitle'   : '$dayText saat $time aboneliğiniz '
              '${status.toLowerCase()}.',
          'createdAtMs': createdAt.millisecondsSinceEpoch,
        });
      }

      _subscriptionCount =
          _notifications.where((n) => n['type'] == 'subscription').length;

      _sortByCreatedAt();
      notifyListeners();
    });
  }

  /* --------- En yeni üste --------- */
  void _sortByCreatedAt() {
    _notifications.sort(
          (a, b) => (b['createdAtMs'] as int).compareTo(a['createdAtMs'] as int),
    );
  }

  /* ------------ Yardımcılar ------------ */
  void clearAll() {
    _reservationCount  = 0;
    _subscriptionCount = 0;
    _notifications.clear();
    _userReservations.clear();
    notifyListeners();
  }

  void disposeListeners() {
    _resListener?.cancel();
    _subListener?.cancel();
  }
}
