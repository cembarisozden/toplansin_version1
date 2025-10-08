import 'dart:async';
import 'dart:ui';

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

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _allBookedSlotsSubscription;


  @override
  void initState() {
    super.initState();
    _initSelectedDate();
    _listenBookedSlots();
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
    return timeSlots.any((slot) => !isSlotBooked(day, slot));
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
    final h = int.parse(slot.split('-')[0].split(':')[0]);
    return DateTime(day.year, day.month, day.day, h);
  }

  void _listenBookedSlots() {
    _allBookedSlotsSubscription = FirebaseFirestore.instance
        .collection('hali_sahalar')
        .doc(widget.haliSaha.id)
        .snapshots()
        .listen((snap) {
      final raw = snap.data()?['bookedSlots'] as List<dynamic>? ?? [];

      setState(() {
        bookedSlots = raw.map((e) => e.toString()).toList(); // her eleman String
      });
    });
  }


  List<String> get timeSlots {
    final start = widget.haliSaha.startHour.split(':');
    final end = widget.haliSaha.endHour.split(':');
    int sH = int.parse(start[0]);
    int sM = int.parse(start[1]);
    int eH = int.parse(end[0]);
    int eM = int.parse(end[1]);
    if (eH < sH || (eH == sH && eM < sM)) eH += 24;
    return [for (int h = sH; h < eH; h++)
      '${(h % 24).toString().padLeft(2,'0')}:00-${((h+1)%24).toString().padLeft(2,'0')}:00'
    ];
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
    if (!isSlotBooked(selectedDate, time))
      setState(() => selectedTime = time);
  }

  void handlePrevMonth() {
    // Önceki aya git
    setState(() {
      selectedDate = DateTime(selectedDate.year, selectedDate.month - 1, 1);

      // Geçmiş tarihlerin seçilmesini önle
      _updateToFirstValidDate();
    });
  }

  void handleNextMonth() {
    // 1 haftalık rezervasyon penceresi
    DateTime today = TimeService.now();
    DateTime bookingWindowEnd = today.add(Duration(days: 7));

    // Şu anki ayın son günü
    DateTime currentMonthEnd =
        DateTime(selectedDate.year, selectedDate.month + 1, 0);

    // Rezervasyon penceresi sonraki aya uzanıyor mu?
    bool bookingWindowExtendToNextMonth =
        bookingWindowEnd.isAfter(currentMonthEnd);

    if (bookingWindowExtendToNextMonth) {
      // Rezervasyon penceresi sonraki aya uzanıyorsa, sonraki aya geçiş yap
      setState(() {
        selectedDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
        _updateToFirstValidDate();
      });
    } else {
      // Rezervasyon penceresi uzanmıyorsa, bilgi ver ve mevcut ayda kal
      AppSnackBar.warning(context,
          "Şu an için sadece ${DateFormat.yMMMd('tr_TR').format(today)} - ${DateFormat.yMMMd('tr_TR').format(bookingWindowEnd)} arası rezervasyon yapılabilir.",
          d: Duration(seconds: 3));
      // Ay değişikliği yapma - mevcut ayda kalır
    }
  }

// Yardımcı fonksiyon: İlk geçerli tarihe güncelle
  void _updateToFirstValidDate() {
    DateTime now = TimeService.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    // Seçili ay bugünün ayı ise ve seçili gün geçmişte kaldıysa, bugüne veya sonraki ilk uygun güne güncelle
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day < now.day) {
      // Bugün için müsait slot var mı kontrol et
      if (hasFreeSlotOnDay(today)) {
        selectedDate = today;
      } else {
        // Bugün için slot yoksa, sonraki ilk uygun günü bul
        DateTime? nextAvailable = findNextAvailableDay(today);
        if (nextAvailable != null) {
          selectedDate = nextAvailable;
        } else {
          // Hiç uygun gün bulunamazsa bugüne ayarla (UI'da "müsait saat yok" gösterilecek)
          selectedDate = today;
        }
      }
    } else if (selectedDate.isBefore(today)) {
      // Seçili tarih tamamen geçmişte kaldıysa (farklı ay/yıl), bugüne ayarla
      selectedDate = today;
    }

    // Burada diğer ayların geçerlilik kontrolü de yapılabilir, ancak şimdilik geçmiş günler problemi çözüldü
  }

  bool _isToday(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;


  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month, 1).weekday;
    final selectedMonthYear = DateFormat.yMMMM('tr_TR').format(selectedDate);
    DateTime now = TimeService.now();

    final allSlots =
    timeSlots.where((slot) => !isSlotBooked(selectedDate, slot)).toList();

    // Eğer seçili gün bugüne eşitse, geçmiş saatleri listeden çıkar
    if (_isToday(selectedDate, now)) {
      allSlots.removeWhere((slot) {
        final slotHour = int.parse(slot.split('-').first.split(':')[0]);
        // slot 08:00 ise slotHour=8, şimdi TR saati 10:xx ise 8 < 10 ⇒ geçmiş
        return slotHour <= now.hour;
      });
    }

    // Saatleri sıralıyoruz.
    allSlots.sort((a, b) {
      final startA = int.parse(a.split('-')[0].split(':')[0]);
      final startB = int.parse(b.split('-')[0].split(':')[0]);
      return startA.compareTo(startB);
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
                      if (selectedDate.month == TimeService
                          .now()
                          .month)
                        IconButton(
                            icon: Icon(Icons.chevron_left),
                            onPressed: null,
                            color: Colors.grey[300]),
                      if (selectedDate.month != TimeService
                          .now()
                          .month)
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
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.access_time,
                              color: Colors.green.shade800, size: 20),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Müsait Saatler",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
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
            ElevatedButton(
              onPressed: selectedTime != null
                  ? () {
                _showConfirmationDialog(context);
              }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedTime != null
                    ? Colors.green.shade700
                    : Colors.grey.shade300,
                padding: EdgeInsets.symmetric(vertical: 16,horizontal: 24),
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
          ],
        ),
      ),
    );
  }



  Future<bool> _hasReachedDailyCancelLimit() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(TimeService.now());
    final start = Timestamp.fromDate(DateTime.parse('$todayStr 00:00:00Z'));
    final end   = Timestamp.fromDate(DateTime.parse('$todayStr 23:59:59Z'));
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
        .where('userId',  isEqualTo: _auth.currentUser!.uid)
        .where('status',  isEqualTo: 'Beklemede')
        .get();

    final now = TimeService.now();

    /* Sadece geleceğe ait olanları say */
    int futureCount = 0;
    for (final doc in snap.docs) {
      final raw = doc['reservationDateTime'] as String?;
      if (raw == null) continue;
      try {
        final datePart  = raw.split(' ').first;          // "2024‑12‑18"
        final timeStart = raw.split(' ').last.split('-').first; // "17:00"
        final dt = DateTime.parse('$datePart $timeStart');
        if (dt.isAfter(now)) futureCount++;
      } catch (_) {/* format hatası varsa yoksay */}
    }
    return futureCount >= 2;
  }

  Future<void> _makeReservation(String slot) async {
    /* 1) Rezervasyonun başlangıç DateTime’i   */
    final start   = slotToDateTime(selectedDate, slot);

    /* 2) Sınır kontrolleri ------------------------------------------------- */
    if (await _hasReachedDailyCancelLimit()) {
      AppSnackBar.warning(context,
          'Günlük iptal sınırına ulaştınız, bugün yeni rezervasyon isteği gönderemezsiniz.');
      return;
    }
    if (await _hasReachedInstantReservationLimit()) {
      AppSnackBar.warning(context,
          'Aynı anda en fazla 2 bekleyen rezervasyonunuz olabilir.');
      return;
    }

// 1) bookingString
    final dayStr        = DateFormat('yyyy-MM-dd').format(selectedDate);
    final bookingString = '$dayStr $slot'; // "2025-07-29 20:00-21:00"

    DateTime parseStartTimeUtc(String bookingString) {
      final parts    = bookingString.split(' ');
      final datePart = parts[0];                   // "2025-07-29"
      final startStr = parts[1].split('-').first;  // "22:00"
      final ymd      = datePart.split('-').map(int.parse).toList();
      final hm       = startStr.split(':').map(int.parse).toList();

      // önce normal UTC DateTime
      final dtUtc = DateTime.utc(
        ymd[0],  // year
        ymd[1],  // month
        ymd[2],  // day
        hm[0],   // hour
        hm[1],   // minute
      );

      // sonra sadece saatten 3 çıkar:
      return dtUtc.subtract(const Duration(hours: 3));
    }

    final startTime     = parseStartTimeUtc(bookingString);
    print(bookingString);
    print(startTime.toString());



    final success = await ReservationRemoteService().reserveSlot(
        haliSahaId: widget.haliSaha.id,
        bookingString: bookingString,
      );
      if (!success) {
        AppSnackBar.error(context,
            'Slot rezerve edilemedi, lütfen başka bir saat deneyin.');
        return;
      }


      /* 4) Firestore’a rezervasyon belgesi yaz ----------------------------- */
      final docRef = FirebaseFirestore.instance.collection('reservations').doc();

      final reservation = Reservation(
        id:                  docRef.id,
        userId:              _auth.currentUser!.uid,
        haliSahaId:          widget.haliSaha.id,
        haliSahaName:        widget.haliSaha.name,
        haliSahaLocation:    widget.haliSaha.location,
        haliSahaPrice:       widget.haliSaha.price,
        reservationDateTime: bookingString,          // ← TEK ALAN KALDI
        startTime: startTime,
        status:              'Beklemede',
        type: "manual",
        createdAt:           TimeService.nowUtc(),
        userName:            widget.currentUser.name,
        userEmail:           widget.currentUser.email,
        userPhone:           widget.currentUser.phone ?? '',
        lastUpdatedBy:       widget.currentUser.role,
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
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
