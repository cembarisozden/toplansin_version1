import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/reservation_remote_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/views/no_internet_screen.dart';

class ReservationPage extends StatefulWidget {
  final HaliSaha haliSaha;
  final Person currentUser;

  ReservationPage({required this.haliSaha, required this.currentUser});

  @override
  _ReservationPageState createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime selectedDate = TimeService.now();
  String? selectedTime;
  List<String> bookedSlots = [];

  bool isConnectedToInternet = false;
  StreamSubscription? _internetConnectionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _allBookedSlotsSubscription;

  @override
  void initState() {
    super.initState();
    _initSelectedDate();
    listenBookedSlots(widget.haliSaha);
    _internetConnectionStreamSubscription =
        InternetConnection().onStatusChange.listen((event) {
      print(event);
      switch (event) {
        case InternetStatus.connected:
          setState(() {
            isConnectedToInternet = true;
          });
          break;
        case InternetStatus.disconnected:
          setState(() {
            isConnectedToInternet = false;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => NoInternetScreen()),
              (route) =>
                  false, // Bu, önceki tüm rotaların kaldırılmasını sağlar.
            );
          });
          break;
        default:
          setState(() {
            isConnectedToInternet = false;
          });
          break;
      }
    });
  }

  @override
  void dispose() {
    _internetConnectionStreamSubscription?.cancel();
    _allBookedSlotsSubscription?.cancel();
    super.dispose();
  }

  void _initSelectedDate() {
    DateTime now = TimeService.now();
    if (!hasFreeSlotOnDay(now)) {
      DateTime? nextAvailableDay = findNextAvailableDay(now);
      if (nextAvailableDay != null) {
        setState(() {
          selectedDate = nextAvailableDay;
        });
      }
    }
  }

  bool hasFreeSlotOnDay(DateTime day) {
    List<String> slots = timeSlots;
    for (String slot in slots) {
      if (!isSlotBooked(day, slot)) {
        return true;
      }
    }
    return false;
  }

  DateTime? findNextAvailableDay(DateTime startDay) {
    int daysInMonth = DateTime(startDay.year, startDay.month + 1, 0).day;
    for (int d = startDay.day + 1; d <= daysInMonth; d++) {
      DateTime currentDay = DateTime(startDay.year, startDay.month, d);
      if (hasFreeSlotOnDay(currentDay)) {
        return currentDay;
      }
    }
    return null;
  }

  Future<void> listenBookedSlots(HaliSaha haliSaha) async {
    var allBookedSlotsStream = FirebaseFirestore.instance
        .collection("hali_sahalar")
        .where("id", isEqualTo: haliSaha.id)
        .snapshots();

    _allBookedSlotsSubscription = allBookedSlotsStream.listen((snapshot) {
      List<String> newbookedSlots = [];

      for (var document in snapshot.docs) {
        Map<String, dynamic> data = document.data();

        if (data['bookedSlots'] != null) {
          List<dynamic> rawSlots = data['bookedSlots'];
          newbookedSlots.addAll(rawSlots.map((e) => e.toString()).toList());
        }
      }

      setState(() {
        bookedSlots = newbookedSlots;
      });

      debugPrint("Dinlenen BookedSlots: $bookedSlots");
    });
  }

  List<String> get timeSlots {
    // Burada artık startHour ve endHour string tipinde olduğu için:
    // Örneğin startHour = "08:00", endHour = "20:00" gibi varsayıyoruz.
    // Bunları saat ve dakikalarına ayırıyoruz.
    final startParts = widget.haliSaha.startHour.split(':');
    final endParts = widget.haliSaha.endHour.split(':');

    int startHour = int.parse(startParts[0]);
    int startMinute = int.parse(startParts[1]);
    int endHour = int.parse(endParts[0]);
    int endMinute = int.parse(endParts[1]);

    // Eğer endHour startHour'dan küçükse, bu gece yarısını geçtiğini gösterir.
    if (endHour < startHour ||
        (endHour == startHour && endMinute < startMinute)) {
      endHour += 24;
    }

    List<String> slots = [];
    for (int hour = startHour; hour < endHour; hour++) {
      int actualStartHour = hour % 24;
      int actualEndHour = (hour + 1) % 24;
      // 00:00 formatında yazmak için padLeft kullanıyoruz
      slots.add(
          '${actualStartHour.toString().padLeft(2, '0')}:00-${actualEndHour.toString().padLeft(2, '0')}:00');
    }

    return slots;
  }

  bool isSlotBooked(DateTime date, String slot) {
    // slot: "HH:00-HH:00" gibi bir formattadır.
    // İlk kısmı alıp saat ve dakikayı çözüyoruz.
    final startPart = slot.split('-')[0];
    final slotHour = int.parse(startPart.split(':')[0]);
    final slotMinute = int.parse(startPart.split(':')[1]);

    DateTime slotDateTime =
        DateTime(date.year, date.month, date.day, slotHour, slotMinute);
    String bookingString =
        "${DateFormat('yyyy-MM-dd').format(slotDateTime)} $slot";
    return bookedSlots.contains(bookingString);
  }

  void handleDateClick(int day) {
    setState(() {
      selectedDate = DateTime(selectedDate.year, selectedDate.month, day);
      selectedTime = null;
    });
  }

  void handleTimeClick(String time) {
    if (!isSlotBooked(selectedDate, time)) {
      setState(() {
        selectedTime = time;
      });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Şu an için sadece ${DateFormat.yMMMd('tr_TR').format(today)} - ${DateFormat.yMMMd('tr_TR').format(bookingWindowEnd)} arası rezervasyon yapılabilir.",
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
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

  bool isToday(DateTime day, DateTime now) {
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

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
    if (isToday(selectedDate, now)) {
      allSlots.removeWhere((slot) {
        final startPart = slot.split('-')[0];
        final slotHour = int.parse(startPart.split(':')[0]);
        final slotDateTime = DateTime(
            selectedDate.year, selectedDate.month, selectedDate.day, slotHour);
        return slotDateTime.isBefore(now);
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
        backgroundColor: Colors.green,
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
                      crossAxisCount: 7,
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
                                fontSize: isSelected ? 16 : 14,
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
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: selectedTime != null ? 3 : 0,
              ),
              child: Text(
                selectedTime != null
                    ? "${DateFormat.yMMMd('tr_TR').format(selectedDate)} ${selectedTime!} için Rezervasyon Yap"
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

  Future<void> _makeReservation(String time) async {
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    String bookingString = "$formattedDate $time";

    final cancelledReservation = await FirebaseFirestore.instance
        .collection('reservations')
        .where('haliSahaId', isEqualTo: widget.haliSaha.id)
        .where('reservationDateTime', isEqualTo: bookingString)
        .where('status', isEqualTo: 'İptal Edildi')
        .get();

    try {
      final success = await ReservationRemoteService().reserveSlot(
        haliSahaId: widget.haliSaha.id,
        bookingString: bookingString,
      );

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Slot rezerve edilemedi, lütfen başka bir saat deneyin."),
            backgroundColor: Colors.red,
          ),
        );
        return; // işlemi durdur
      }

      // Güncellenmiş bookedSlots listesini al
      setState(() {
        widget.haliSaha.bookedSlots.add(bookingString);
      });

      String userId = _auth.currentUser!.uid;
      String userName = widget.currentUser.name ?? "Name";
      String userEmail = widget.currentUser.email ?? 'email@example.com';
      String userPhone = widget.currentUser.phone;

      DocumentReference docRef;

      if (cancelledReservation.docs.isNotEmpty) {
        // Daha önce iptal edilen rezervasyonu tekrar kullan
        docRef = FirebaseFirestore.instance
            .collection('reservations')
            .doc(cancelledReservation.docs.first.id);
      } else {
        // Daha önce iptal edilmiş rezervasyon da yoksa yeni bir doc ID oluştur
        docRef = FirebaseFirestore.instance.collection("reservations").doc();
      }

      Reservation newReservation = Reservation(
        id: docRef.id,
        // Firestore'un oluşturduğu ID'yi kullanıyoruz
        userId: userId,
        haliSahaId: widget.haliSaha.id,
        haliSahaName: widget.haliSaha.name,
        haliSahaLocation: widget.haliSaha.location,
        haliSahaPrice: widget.haliSaha.price,
        reservationDateTime: bookingString,
        status: 'Beklemede',
        // Başlangıç durumu
        createdAt: TimeService.now(),
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        lastUpdatedBy: widget.currentUser.role,
      );
      print("Firestore'a yazılacak veri: ${newReservation.toMap()}");

// Reservation'ı Firestore'a ekleme
      await docRef.set(newReservation.toMap(), SetOptions(merge: false));

      // Başarılı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rezervasyon isteği başarıyla gönderildi!")),
      );

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
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
                      "Rezervasyon İsteği Gönderildi!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Rezervasyon durumunuzu 'Rezervasyonlarım' sekmesinden takip edebilirsiniz.",
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          "Tamam",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      final errorMsg = getReservationErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rezervasyon başarısız: $errorMsg"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String getReservationErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-disabled':
          return 'Hesabınız devre dışı bırakılmış.';
        case 'user-not-found':
          return 'Kullanıcı bulunamadı.';
        case 'requires-recent-login':
          return 'Lütfen tekrar giriş yapın.';
        default:
          return 'Giriş yapmanız gerekiyor.';
      }
    }

    if (error.toString().contains('already reserved')) {
      return 'Bu saat zaten rezerve edilmiş.';
    }

    if (error.toString().contains('permission-denied')) {
      return 'Bu işlem için yetkiniz yok.';
    }

    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
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
                  Container(
                    padding: EdgeInsets.all(12),
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
                  SizedBox(height: 24),
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          _makeReservation(selectedTime!);
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
}
