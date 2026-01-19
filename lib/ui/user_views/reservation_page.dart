import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/reservation_remote_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';

class ReservationPage extends StatefulWidget {
  final HaliSaha haliSaha;
  final Person currentUser;

  ReservationPage({required this.haliSaha, required this.currentUser});

  @override
  _ReservationPageState createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = TimeService.now();
  String? selectedTime;
  List<String> bookedSlots = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _allBookedSlotsSubscription;
  // 0..6 -> {'startHour': '09:00', 'endHour': '23:00'}
  Map<int, ({String start, String end})> _overrides = {}; // 0..6
  bool _useOverrides = false; // koleksiyon boş mu dolu mu

  @override
  void initState() {
    super.initState();
    _initSelectedDate();
    _listenBookedSlots();
    _loadDayHours();
  }

  @override
  void dispose() {
    _allBookedSlotsSubscription?.cancel();
    super.dispose();
  }

  void _initSelectedDate() {
    DateTime now = TimeService.now();
    if (!hasFreeSlotOnDay(now)) {
      DateTime? next = findNextAvailableDay(now);
      if (next != null) setState(() => selectedDate = next);
    }
  }

  bool hasFreeSlotOnDay(DateTime day) {
    return timeSlotsFor(day).any((slot) => !isSlotBooked(day, slot));
  }

  DateTime? findNextAvailableDay(DateTime startDay) {
    int daysInMonth = DateTime(startDay.year, startDay.month + 1, 0).day;
    for (int d = startDay.day + 1; d <= daysInMonth; d++) {
      DateTime day = DateTime(startDay.year, startDay.month, d);
      if (hasFreeSlotOnDay(day)) return day;
    }
    return null;
  }

  DateTime slotToDateTime(DateTime day, String slot) {
    final start = slot.split('-').first; // "HH:mm"
    final parts = start.split(':').map(int.parse).toList();
    final h = parts[0];
    final m = parts[1];
    return DateTime(day.year, day.month, day.day, h, m);
  }

  void _listenBookedSlots() {
    _allBookedSlotsSubscription = FirebaseFirestore.instance
        .collection('hali_sahalar')
        .doc(widget.haliSaha.id)
        .snapshots()
        .listen((snap) {
      final raw = snap.data()?['bookedSlots'] as List<dynamic>? ?? [];

      setState(() {
        bookedSlots =
            raw.map((e) => e.toString()).toList(); // her eleman String
      });
    });
  }

  Future<void> _loadDayHours() async {
    final col = FirebaseFirestore.instance
        .collection('hali_sahalar')
        .doc(widget.haliSaha.id)
        .collection('start_end_hours');

    final snap = await col.get();

    final map = <int, ({String start, String end})>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final day = int.tryParse(doc.id) ?? (data['day'] as int? ?? -1);
      if (day < 0 || day > 6) continue;

      final s = (data['startHour'] as String? ?? '').trim();
      final e = (data['endHour'] as String? ?? '').trim();
      // burada boş bırakılmaması gerektiğini varsayıyoruz
      map[day] = (start: s, end: e);
    }

    setState(() {
      _overrides = map;
      _useOverrides =
          snap.docs.isNotEmpty; // ✅ bir belge bile varsa tamamen overrides
    });

    // Savunmacı: override modu açıksa 0..6 tüm günlerin geldiğini varsayarız.
    assert(!_useOverrides || _overrides.length == 7,
        'Override modu açık ama günlerden biri eksik gibi görünüyor.');
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

  ({String start, String end}) _hoursForDay(int dayIdx) {
    final defStart = widget.haliSaha.startHour.trim();
    final defEnd = widget.haliSaha.endHour.trim();

    if (_useOverrides) {
      final h = _overrides[dayIdx];
      if (h == null || h.start.isEmpty || h.end.isEmpty) {
        return (start: defStart, end: defEnd);
      }
      return (start: h.start, end: h.end);
    }
    return (start: defStart, end: defEnd);
  }

  List<String> timeSlotsFor(DateTime date, {int durationMinutes = 60}) {
    final dIdx = date.weekday - 1; // 0=Pt..6=Pz
    final prevIdx = (dIdx - 1) < 0 ? 6 : dIdx - 1; // önceki gün
    const int DAY = 24 * 60;

    final prev = _hoursForDay(prevIdx);
    final today = _hoursForDay(dIdx);

    final prevStart = _toMinutes(prev.start);
    final prevEndRaw = _toMinutes(prev.end);

    final todayStart = _toMinutes(today.start);
    final todayEndRaw = _toMinutes(today.end);

    String _fmtWrap(int mins) {
      // 24:00’ı aşan bitişleri 00:xx gibi düzgün göstermek için
      final m = ((mins % DAY) + DAY) % DAY;
      return _fmt(m);
    }

    final slots = <String>[];

    // ---- A) D-1 -> D'ye taşan kısım: 00:00..prevEnd (cross-midnight ise)
    if (prevEndRaw <= prevStart) {
      // Önceki günün slot hizasına göre bugünde başlayacak ilk slotu hizala
      final int mod = prevStart % durationMinutes;
      final int first = (mod == 0) ? 0 : (durationMinutes - mod);

      for (int t = first;
          t + durationMinutes <= prevEndRaw;
          t += durationMinutes) {
        final a = _fmt(t); // örn 00:30
        final b = _fmt(t + durationMinutes); // örn 01:30
        slots.add('$a-$b'); // ✅ 00:30-01:30 (bugüne ait)
      }
    }

    // ---- B) Bugünün kendi kısmı
    if (todayEndRaw <= todayStart) {
      // BUGÜN cross-midnight: başlangıçları bugünde olan tüm slotları ekle
      // ÖNEMLİ: Koşul t < DAY; çünkü bitiş 24:00’ı geçebilir (örn 23:30->00:30)
      for (int t = todayStart; t < DAY; t += durationMinutes) {
        final start = _fmt(t);
        final end = _fmtWrap(t + durationMinutes); // 24:30 -> 00:30 olarak yaz
        slots.add('$start-$end'); // ✅ 23:30-00:30 artık görünür
      }
      // 00:00..todayEnd kısmı yarına ait; onu yarın oluşturacağız (başlangıcı yarın)
    } else {
      // Normal gün: start..end (bitiş gün içinde kaldığı için <= kontrolü doğru)
      for (int t = todayStart;
          t + durationMinutes <= todayEndRaw;
          t += durationMinutes) {
        final a = _fmt(t);
        final b = _fmt(t + durationMinutes);
        slots.add('$a-$b');
      }
    }

    // Çiftlemeyi önle
    final seen = <String>{};
    return slots.where(seen.add).toList();
  }

  bool isSlotBooked(DateTime day, String slot) {
    final slotString = '${DateFormat('yyyy-MM-dd').format(day)} $slot';
    return bookedSlots.contains(slotString);
  }

  void handleDateClick(int day) {
    setState(() {
      selectedDate = DateTime(selectedDate.year, selectedDate.month, day);
      selectedTime = null;
    });
  }

  void handleTimeClick(String time) {
    if (!isSlotBooked(selectedDate, time)) setState(() => selectedTime = time);
  }

  void handlePrevMonth() {
    final candidate = DateTime(selectedDate.year, selectedDate.month - 1, 1);
    final fixed = _updateToFirstValidDateSync(candidate);
    setState(() => selectedDate = fixed);
  }

  Future<void> handleNextMonth() async {
    // 1 haftalık rezervasyon penceresi
    final today = TimeService.now();
    final bookingWindowEnd = today.add(const Duration(days: 7));

    // Seçili ayın son günü
    final currentMonthEnd =
        DateTime(selectedDate.year, selectedDate.month + 1, 0);

    // Rezervasyon penceresi sonraki aya taşıyor mu?
    final extendsToNextMonth = bookingWindowEnd.isAfter(currentMonthEnd);

    if (extendsToNextMonth) {
      // Sonraki ayın 1'ine geç
      setState(() {
        selectedDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
      });

      // Seçilen tarihi geçerli ilk güne çek + slotları tazele
      _updateToFirstValidDateSync(selectedDate);
    } else {
      // Pencere uzanmıyorsa mevcut ayda kal ve uyar
      AppSnackBar.warning(
        context,
        "Şu an için sadece ${DateFormat.yMMMd('tr_TR').format(today)} - "
        "${DateFormat.yMMMd('tr_TR').format(bookingWindowEnd)} arası rezervasyon yapılabilir.",
        d: const Duration(seconds: 3),
      );
    }
  }

// Yardımcı fonksiyon: İlk geçerli tarihe güncelle
  DateTime _updateToFirstValidDateSync(DateTime selected) {
    final now = TimeService.now();
    final today = DateTime(now.year, now.month, now.day);
    var newSelected = selected;

    if (selected.year == now.year &&
        selected.month == now.month &&
        selected.day < now.day) {
      // bugün uygun mu?
      if (hasFreeSlotOnDay(today)) {
        newSelected = today;
      } else {
        final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
        DateTime? next;
        for (int d = today.day + 1; d <= daysInMonth; d++) {
          final day = DateTime(today.year, today.month, d);
          if (hasFreeSlotOnDay(day)) {
            next = day;
            break;
          }
        }
        newSelected = next ?? today;
      }
    } else if (selected.isBefore(today)) {
      newSelected = today;
    }

    return newSelected;
  }

  bool _isToday(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String? _openingHoursLabelFor(DateTime date) {
    if (!_useOverrides) return null; // sadece özel saatler varsa göster
    final idx = date.weekday - 1; // 0..6
    final h = _overrides[idx];
    if (h == null) return null;
    if (h.start.trim().isEmpty || h.end.trim().isEmpty)
      return null; // kapalı ise yazma
    return '${h.start} - ${h.end}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month, 1).weekday;
    final selectedMonthYear = DateFormat.yMMMM('tr_TR').format(selectedDate);
    DateTime now = TimeService.now();

    final allSlots = timeSlotsFor(selectedDate)
        .where((slot) => !isSlotBooked(selectedDate, slot))
        .toList();

    final hoursLabel = _openingHoursLabelFor(selectedDate);

    // Eğer seçili gün bugüne eşitse, geçmiş saatleri listeden çıkar
    if (_isToday(selectedDate, now)) {
      final now = TimeService.now();
      allSlots.removeWhere((slot) {
        final start = slot.split('-').first; // "HH:mm"
        final parts = start.split(':').map(int.parse).toList();
        final sh = parts[0], sm = parts[1];
        final startDt = DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day, sh, sm);
        return startDt.isBefore(
            DateTime(now.year, now.month, now.day, now.hour, now.minute));
      });
    }

    // Saatleri sıralıyoruz.
    allSlots.sort((a, b) {
      final ap = a.split('-').first.split(':').map(int.parse).toList();
      final bp = b.split('-').first.split(':').map(int.parse).toList();
      return (ap[0] * 60 + ap[1]).compareTo(bp[0] * 60 + bp[1]);
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Rezervasyon Yap", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Takvim bölümü
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 5)
                  ]),
              child: Column(
                children: [
                  // Ay bilgisi ve sonraki ay butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (selectedDate.month == TimeService.now().month)
                        IconButton(
                            icon: Icon(Icons.chevron_left),
                            onPressed: null,
                            color: Colors.grey[300]),
                      if (selectedDate.month != TimeService.now().month)
                        IconButton(
                            icon: Icon(Icons.chevron_left),
                            onPressed: handlePrevMonth),
                      Text(selectedMonthYear,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: handleNextMonth),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Takvim günleri
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: daysInMonth + firstDayOfMonth,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                    ),
                    itemBuilder: (context, index) {
                      if (index < firstDayOfMonth) {
                        return SizedBox.shrink();
                      }

                      final day = index - firstDayOfMonth + 1;
                      final isSelected = day == selectedDate.day;
                      final currentDay =
                          DateTime(selectedDate.year, selectedDate.month, day);
                      final isPastDay = currentDay
                          .isBefore(DateTime(now.year, now.month, now.day));

                      // Bugünden itibaren maksimum 7 gün ilerisi için rezervasyon yapılabilir
                      final DateTime maxDate =
                          TimeService.now().add(Duration(days: 7));

                      // Ve takvim gösteriminde bu kontrolü ekleriz
                      final bool isInBookingWindow =
                          !currentDay.isAfter(maxDate);

                      // Tasarımsal değişiklikler
                      BoxDecoration dayDecoration;

                      if (isSelected) {
                        // Seçili gün: Gradient + hafif gölge
                        dayDecoration = BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade700
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        );
                      } else if (isPastDay) {
                        // Geçmiş gün: Hafif gri ton, düz renk
                        dayDecoration = BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        );
                      } else if (!isInBookingWindow) {
                        // Rezervasyon penceresi dışındaki günler: Daha soluk bir stil
                        dayDecoration = BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        );
                      } else {
                        // Normal gün: İnce bir gri çerçeve
                        dayDecoration = BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        );
                      }

                      return GestureDetector(
                        onTap: (isPastDay || !isInBookingWindow)
                            ? null
                            : () => handleDateClick(day),
                        child: Container(
                          margin: EdgeInsets.all(4),
                          decoration: dayDecoration,
                          child: Center(
                            child: Text(
                              day.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isPastDay
                                        ? Colors.grey.shade700
                                        : Colors.black87),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: isSelected ? 15 : 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Müsait Saatler bölümü
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 2,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık satırı: İkon + "Müsait Saatler"
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6F4EA),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.access_time,
                              color: Colors.green.shade800, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Müsait Saatler",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (hoursLabel != null) // sadece özel saat varsa göster
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  hoursLabel, // örn: 09:00 - 23:00
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Eğer müsait saat yoksa, uyarıyı göster
                    if (allSlots.isEmpty)
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.shade300, width: 1),
                            ),
                            child: Text(
                              "Bu gün için müsait saat yok.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      // Müsait saatler varsa, saatleri göster
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double itemWidth = (constraints.maxWidth / 2) - 12;
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allSlots.map((time) {
                                  final isSelected = time == selectedTime;
                                  return GestureDetector(
                                    onTap: () => handleTimeClick(time),
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      width: itemWidth,
                                      padding:
                                          EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [
                                                  Colors.green.shade500,
                                                  Colors.green.shade700
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: isSelected
                                            ? null
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.green.shade200,
                                                  blurRadius: 6,
                                                  offset: Offset(0, 3),
                                                )
                                              ]
                                            : [],
                                        border: isSelected
                                            ? null
                                            : Border.all(
                                                color: Colors.green.shade100),
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 18,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.green.shade800,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              time,
                                              style: TextStyle(
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.green.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

// Onay Butonu
            SafeArea(
              child: ElevatedButton(
                onPressed: selectedTime != null
                    ? () {
                        _showConfirmationDialog(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedTime != null
                      ? Colors.green.shade700
                      : Colors.grey.shade300,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: selectedTime != null ? 3 : 0,
                ),
                child: Text(
                  selectedTime != null
                      ? "Rezervasyon Yap"
                      : "Lütfen bir tarih ve saat seçin",
                  style: TextStyle(
                    color: selectedTime != null ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _hasReachedDailyCancelLimit() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(TimeService.now());
    final start = Timestamp.fromDate(DateTime.parse('$todayStr 00:00:00Z'));
    final end = Timestamp.fromDate(DateTime.parse('$todayStr 23:59:59Z'));
    final snap = await FirebaseFirestore.instance
        .collection('reservation_logs')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .where('newStatus', isEqualTo: 'İptal Edildi')
        .where('by', isEqualTo: 'user')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();
    return snap.size >= 3;
  }

  Future<bool> _hasReachedInstantReservationLimit() async {
    /* Beklemede olan bütün rezervasyon belgelerini çek */
    final snap = await FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .where('status', isEqualTo: 'Beklemede')
        .get();

    final now = TimeService.now();

    /* Sadece geleceğe ait olanları say */
    int futureCount = 0;
    for (final doc in snap.docs) {
      final raw = doc['reservationDateTime'] as String?;
      if (raw == null) continue;
      try {
        final datePart = raw.split(' ').first; // "2024‑12‑18"
        final timeStart = raw.split(' ').last.split('-').first; // "17:00"
        final dt = DateTime.parse('$datePart $timeStart');
        if (dt.isAfter(now)) futureCount++;
      } catch (_) {/* format hatası varsa yoksay */}
    }
    return futureCount >= 2;
  }

  Future<void> _makeReservation(String slot) async {
    /* 1) Rezervasyonun başlangıç DateTime’i   */
    final start = slotToDateTime(selectedDate, slot);

    /* 2) Sınır kontrolleri ------------------------------------------------- */
    if (await _hasReachedDailyCancelLimit()) {
      AppSnackBar.warning(context,
          'Günlük iptal sınırına ulaştınız, bugün yeni rezervasyon isteği gönderemezsiniz.');
      return;
    }
    if (await _hasReachedInstantReservationLimit()) {
      AppSnackBar.warning(
          context, 'Aynı anda en fazla 2 bekleyen rezervasyonunuz olabilir.');
      return;
    }

// 1) bookingString
    final dayStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final bookingString = '$dayStr $slot'; // "2025-07-29 20:00-21:00"

    DateTime parseStartTimeUtc(String bookingString) {
      final parts = bookingString.split(' ');
      final datePart = parts[0]; // "2025-07-29"
      final startStr = parts[1].split('-').first; // "22:00"
      final ymd = datePart.split('-').map(int.parse).toList();
      final hm = startStr.split(':').map(int.parse).toList();

      // önce normal UTC DateTime
      final dtUtc = DateTime.utc(
        ymd[0], // year
        ymd[1], // month
        ymd[2], // day
        hm[0], // hour
        hm[1], // minute
      );

      // sonra sadece saatten 3 çıkar:
      return dtUtc.subtract(const Duration(hours: 3));
    }

    final startTime = parseStartTimeUtc(bookingString);
    print(bookingString);
    print(startTime.toString());

    final success = await ReservationRemoteService().reserveSlot(
      haliSahaId: widget.haliSaha.id,
      bookingString: bookingString,
    );
    if (!success) {
      AppSnackBar.error(
          context, 'Slot rezerve edilemedi, lütfen başka bir saat deneyin.');
      return;
    }

    /* 4) Firestore’a rezervasyon belgesi yaz ----------------------------- */
    final docRef = FirebaseFirestore.instance.collection('reservations').doc();

    final reservation = Reservation(
      id: docRef.id,
      userId: _auth.currentUser!.uid,
      haliSahaId: widget.haliSaha.id,
      haliSahaName: widget.haliSaha.name,
      haliSahaLocation: widget.haliSaha.location,
      haliSahaPrice: widget.haliSaha.price,
      reservationDateTime: bookingString, // ← TEK ALAN KALDI
      startTime: startTime,
      status: 'Beklemede',
      type: "manual",
      createdAt: TimeService.nowUtc(),
      userName: widget.currentUser.name,
      userEmail: widget.currentUser.email,
      userPhone: _auth.currentUser!.phoneNumber ?? '',
      lastUpdatedBy: widget.currentUser.role,
    );

    try {
      await docRef.set(reservation.toMap(), SetOptions(merge: false));
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, 'Rezervasyon kaydedilirken hata: $msg');
      return;
    }

    /* 5)  Ekranda anında göstermek için local listeyi güncelle */
    setState(() {
      setState(() {
        bookedSlots.add(bookingString);
      });
      selectedTime = null;
    });

    _showSuccessDialog();

    AppSnackBar.success(context, 'Rezervasyon isteğiniz gönderildi.');
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rezervasyon Onayı',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Rezervasyonunuzu aşağıdaki tarih ve saat için onaylamak istediğinize emin misiniz?',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: EdgeInsets.only(
                          top: 12, bottom: 12, left: 32, right: 32),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${DateFormat.yMMMd('tr_TR').format(selectedDate)} ${selectedTime!}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop(); // varsa dialog kapat
                          showLoader(context); // spinner başlat

                          try {
                            await _makeReservation(selectedTime!);
                          } catch (e) {
                            print('HATA: $e');
                          } finally {
                            hideLoader(); // spinner her durumda kapanır
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: Text(
                          'Onayla',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // kullanıcı ekrana dokununca kapanmasın
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✔️ Üstte büyük bir ikon
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  radius: 36,
                  child: Icon(Icons.check, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),

                // Başlık
                Text(
                  'Rezervasyon İsteği Gönderildi!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Açıklama
                Text(
                  '\' Rezervasyonlarım \' sekmesinden rezervasyonunuzun durumunu takip edebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Tamam butonu
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // İstersen burada Rezervasyonlarım sayfasına da yönlendirebilirsin:
                    // Navigator.pushNamed(context, '/my_reservations');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: Text(
                    'Tamam',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
