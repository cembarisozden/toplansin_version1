import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/reservation_remote_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/owner_views/owner_completed_reservation_page.dart';
import 'package:toplansin/ui/owner_views/owner_notification_panel.dart';
import 'package:toplansin/ui/owner_views/owner_photo_management_page.dart';
import 'package:toplansin/ui/owner_views/owner_reviews_page.dart';
import 'package:toplansin/ui/views/notification_provider.dart';

class OwnerHalisahaPage extends StatefulWidget {
  HaliSaha haliSaha;
  final Person currentOwner;
  var notificationCount;

  OwnerHalisahaPage({
    required this.haliSaha,
    required this.currentOwner,
  });

  @override
  _OwnerHalisahaPageState createState() => _OwnerHalisahaPageState();
}

class _OwnerHalisahaPageState extends State<OwnerHalisahaPage> {
  DateTime selectedDate = TimeService.now();
  String? selectedTime;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _allReservationsSubscription;
  StreamSubscription<QuerySnapshot>? _TodaysApprovedReservationsSubscription;
  StreamSubscription<QuerySnapshot>? _pendingReservationsSubscription;
  StreamSubscription<DocumentSnapshot>? haliSahaSubscription;

  List<Reservation> haliSahaReservations = [];
  List<Reservation> haliSahaReservationsApproved = [];
  List<Reservation> haliSahaReservationsRequests = [];
  List<DateTime> requestDays = [];
  Map<DateTime, int> requestCountMap = {}; // GÜN İSTEK SAYILARI İÇİN EKLENDİ

  num todaysRevenue = 0;
  int todaysReservation = 0;
  int occupancyRate = 0;
  int totalOpenHours = 0;

  void listenToReservations(String haliSahaId) {
    try {
      // 1. Tüm Rezervasyonları Dinleme ve Geçmiş Rezervasyonların Durumunu Güncelleme
      var allReservationsStream = FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .snapshots();

      _allReservationsSubscription =
          allReservationsStream.listen((snapshot) async {
        List<Reservation> reservations = [];
        for (var document in snapshot.docs) {
          var reservation = Reservation.fromDocument(document);

          // Tarih ve saat kontrolü
          DateTime? reservationDateTime;
          try {
            var rawDateTime =
                reservation.reservationDateTime; // Ör: "2024-12-18 17:00-18:00"
            var datePart = rawDateTime.split(' ')[0]; // Ör: "2024-12-18"
            var timePart =
                rawDateTime.split(' ')[1].split('-')[0]; // Ör: "17:00"
            var formattedDateTime =
                '$datePart $timePart'; // Ör: "2024-12-18 17:00"
            reservationDateTime = DateTime.parse(formattedDateTime);
          } catch (e) {
            debugPrint(
                "Tarih formatı hatası: ${reservation.reservationDateTime}");
          }

          // Geçmiş tarih kontrolü ve durum güncellemesi
          if (reservationDateTime != null) {
            if (reservationDateTime.isBefore(TimeService.now()) &&
                reservation.status != 'Tamamlandı' &&
                reservation.status != 'İptal Edildi') {
              try {
                // Firestore'da status güncellemesi
                await FirebaseFirestore.instance
                    .collection("reservations")
                    .doc(document.id)
                    .update({'status': 'Tamamlandı'});

                // Yerel olarak reservation nesnesinin status'unu güncelle
                reservation.status = 'Tamamlandı';
              } catch (e) {
                debugPrint("Durum güncellenirken hata oluştu: $e");
              }
            }
          }

          reservations.add(reservation);
        }

        // Güncellenmiş rezervasyonları state'e atama
        setState(() {
          haliSahaReservations = reservations;
        });

        debugPrint(
            "Rezervasyonlar başarıyla güncellendi: ${reservations.length} adet.");
      });

      // 2. Onaylanan ve Tamamlanan Rezervasyonları Dinleme (Bugün ve Saat Aralığı)
      // Bugünün tarihini al
      DateTime now = TimeService.now();
      String todayDate =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      DateTime tomorrow = now.add(Duration(days: 1));
      String tomorrowDate =
          "${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";

      // "todayDate 00:00-00:00" ile "tomorrowDate 00:00-00:00" arasındaki rezervasyonları çekiyoruz.
      String startDateTime =
          "$todayDate 00:00-00:00"; // "2024-12-19 00:00-00:00"
      String endDateTime =
          "$tomorrowDate 00:00-00:00"; // "2024-12-20 00:00-00:00"

      var TodaysApprovedReservationsStream = FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .where("status", whereIn: [
            'Onaylandı',
            'Tamamlandı'
          ]) // Doğru status değerlerini kullanın
          .where("reservationDateTime", isGreaterThanOrEqualTo: startDateTime)
          .where("reservationDateTime", isLessThan: endDateTime)
          .snapshots();

      _TodaysApprovedReservationsSubscription =
          TodaysApprovedReservationsStream.listen((snapshot) {
        List<Reservation> TodaysApprovedReservations = [];
        for (var document in snapshot.docs) {
          var reservation = Reservation.fromDocument(document);
          TodaysApprovedReservations.add(reservation);
        }

        // Debug: Onaylanan rezervasyonları kontrol et
        debugPrint(
            "Onaylanan ve Tamamlanan rezervasyon sayısı: ${TodaysApprovedReservations.length}");
        for (var reservation in TodaysApprovedReservations) {
          debugPrint(
              "Rezervasyon ID: ${reservation.id}, Fiyat: ${reservation.haliSahaPrice}, Tarih: ${reservation.reservationDateTime}");
        }

        // Geliri hesapla
        num revenue = calculateTodaysRevenue(TodaysApprovedReservations);

        totalOpenHours = calculateOpenHours(
            widget.haliSaha.startHour, widget.haliSaha.endHour);
        int testTodaysReservation = TodaysApprovedReservations.length;
        int testOccupancyRate = (testTodaysReservation * 100) ~/ totalOpenHours;
        print(testTodaysReservation);

        setState(() {
          haliSahaReservationsApproved = TodaysApprovedReservations;
          todaysRevenue = revenue; // Geliri güncelle
          todaysReservation = testTodaysReservation;
          occupancyRate = testOccupancyRate;
        });

        debugPrint(
            "Onaylanan rezervasyonlar güncellendi: ${TodaysApprovedReservations.length} adet. Toplam Gelir: \$${revenue.toStringAsFixed(2)}");
      });
      // 3. Beklemede Rezervasyonları Dinleme
      var pendingReservationsStream = FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .where("status",
              isEqualTo: 'Beklemede') // Sadece 'Beklemede' olanları dinle
          .snapshots();

      _pendingReservationsSubscription =
          pendingReservationsStream.listen((snapshot) {
        List<Reservation> reservations = [];
        List<DateTime> tempRequestDays = [];
        Map<DateTime, int> tempRequestCount = {}; // Geçici sayım tablosu

        for (var document in snapshot.docs) {
          var reservation = Reservation.fromDocument(document);
          reservations.add(reservation);

          String reservationDateTime = document['reservationDateTime'];
          // Tarih kısmını al
          DateTime dayOnly = DateTime.parse(reservationDateTime.split(' ')[0]);

          // Günü normalize ediyoruz (Saat, dakika, saniyeyi 0'lıyoruz)
          DateTime normalizedDay =
              DateTime(dayOnly.year, dayOnly.month, dayOnly.day);

          // Bu güne ait istek sayısını 1 arttır
          if (tempRequestCount.containsKey(normalizedDay)) {
            tempRequestCount[normalizedDay] =
                tempRequestCount[normalizedDay]! + 1;
          } else {
            tempRequestCount[normalizedDay] = 1;
          }

          tempRequestDays.add(dayOnly);
        }

        setState(() {
          haliSahaReservationsRequests = reservations;
          requestDays = tempRequestDays;
          requestCountMap =
              tempRequestCount; // Gün bazlı istek sayıları state'e atandı
        });

        // Provider ile bildirim sayısını güncelle
        Provider.of<NotificationProvider>(context, listen: false)
            .setNotificationCount(haliSahaId, reservations.length);

        debugPrint(
            "Beklemede rezervasyonlar güncellendi: ${reservations.length} adet.");
      });
    } catch (e) {
      debugPrint("Rezervasyonları dinlerken hata oluştu: $e");
    }
  }

  num calculateTodaysRevenue(List<Reservation> reservations) {
    num total = 0;
    for (var reservation in reservations) {
      total += reservation.haliSahaPrice;
    }
    return total;
  }

  int calculateOpenHours(String startTime, String endTime) {
    List<String> startParts = startTime.split(':');
    List<String> endParts = endTime.split(':');

    if (startParts.length != 2 || endParts.length != 2) {
      throw FormatException("Geçersiz zaman formatı. Beklenen format: HH:mm");
    }

    int startHour = int.parse(startParts[0]);
    int startMinute = int.parse(startParts[1]);

    int endHour = int.parse(endParts[0]);
    int endMinute = int.parse(endParts[1]);

    int startTotalMinutes = startHour * 60 + startMinute;
    int endTotalMinutes = endHour * 60 + endMinute;

    int differenceMinutes = endTotalMinutes - startTotalMinutes;

    if (differenceMinutes < 0) {
      differenceMinutes += 24 * 60;
    }
    return differenceMinutes ~/ 60; // Tam sayı bölmesi
  }

  void listenHaliSaha(String haliSahaId) {
    haliSahaSubscription = FirebaseFirestore.instance
        .collection('hali_sahalar')
        .doc(widget.haliSaha.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          currentHaliSaha =
              HaliSaha.fromJson(snapshot.data()!, widget.haliSaha.id);
          var h = currentHaliSaha;
          nameController.text = h.name;
          locationController.text = h.location;
          priceController.text = h.price.toString();
          sizeController.text = h.size;
          surfaceController.text = h.surface;
          maxPlayersController.text = h.maxPlayers.toString();
          startHourController.text = h.startHour;
          endHourController.text = h.endHour;
          descriptionController.text = h.description;

          // Özellik durumlarını güncelle
          hasParking = h.hasParking;
          hasShowers = h.hasShowers;
          hasShoeRental = h.hasShoeRental;
          hasCafeteria = h.hasCafeteria;
          hasNightLighting = h.hasNightLighting;
        });
      }
    });
  }

  // Bildirim ayarları gibi diğer değişkenler
  String selectedCurrency = "TRY";
  String selectedLanguage = "tr";
  bool emailNotifications = true;
  bool smsNotifications = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController surfaceController = TextEditingController();
  final TextEditingController maxPlayersController = TextEditingController();
  final TextEditingController startHourController = TextEditingController();
  final TextEditingController endHourController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool hasParking = false;
  bool hasShowers = false;
  bool hasShoeRental = false;
  bool hasCafeteria = false;
  bool hasNightLighting = false;

  // Yerel Halı Saha Durumu
  late HaliSaha currentHaliSaha = widget.haliSaha;

  // Yükleniyor durumu
  bool _isLoading = false;

  @override
  void initState() {
    listenToReservations(widget.haliSaha.id);
    super.initState();
    listenHaliSaha(widget.haliSaha.id);
  }

  @override
  void dispose() {
    _allReservationsSubscription?.cancel();
    _TodaysApprovedReservationsSubscription?.cancel();
    _pendingReservationsSubscription?.cancel();
    haliSahaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            "Halı Saha Yönetimi",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 4,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.history_sharp, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OwnerCompletedReservationsPage(
                          haliSahaId: widget.haliSaha.id)),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                _showNotificationPanel(context, widget.haliSaha);
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: TabBar(
                isScrollable: false,
                labelColor: Colors.green.shade800,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorSize: TabBarIndicatorSize.tab,
                // Sekme genişliği kadar olacak
                indicator: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: "Genel Bakış"),
                  Tab(text: "Saha Bilgileri"),
                  Tab(
                    child: Consumer<NotificationProvider>(
                      builder: (context, provider, child) {
                        int notificationCount =
                            provider.getNotificationCount(widget.haliSaha.id);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 3.0),
                              child: Text("Rezervasyonlar",
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (notificationCount > 0)
                              Positioned(
                                right: -15,
                                top: -5,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    '$notificationCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                _buildGenelBakisTab(context),
                _buildSahaBilgileriTab(),
                _buildRezervasyonlarTab(),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenelBakisTab(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Güncel Durum",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildInfoCard("Günlük Gelir", "₺${todaysRevenue}",
                  subtitle: "+15.8% geçen günden", icon: Icons.monetization_on),
              _buildInfoCard("Bugünkü Rezervasyonlar", "${todaysReservation}",
                  subtitle: "+2 geçen haftadan", icon: Icons.calendar_today),
              _buildInfoCard("Doluluk Oranı", "${occupancyRate}%",
                  isProgress: true, icon: Icons.show_chart),
              _buildInfoCard("Müşteri Memnuniyeti",
                  "${currentHaliSaha.rating.toStringAsFixed(1)}/5",
                  icon: Icons.thumb_up),
            ],
          ),
          SizedBox(height: 24),
          Text(
            "Operasyonel İşlemler",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 20),
          // Fotoğraf Yönetimi Butonu
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OwnerPhotoManagementPage(
                    images: currentHaliSaha.imagesUrl,
                    haliSahaId: currentHaliSaha.id,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 3,
              minimumSize: Size(double.infinity, 50), // Tam genişlikte buton
            ),
            icon: Icon(Icons.photo_library, color: Colors.white, size: 20),
            label: Text(
              "Fotoğraf Yönetimi",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          SizedBox(height: 32),
          // Yorumları Görüntüle Butonu
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OwnerReviewsPage(
                    haliSahaId: currentHaliSaha.id,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 3,
              minimumSize: Size(double.infinity, 50), // Tam genişlikte buton
            ),
            icon: Icon(Icons.comment, color: Colors.white, size: 20),
            label: Text(
              "Değerlendirmeleri Görüntüle",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value,
      {String? subtitle, bool isProgress = false, IconData? icon}) {
    return Container(
      width: 180,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.green.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (icon != null) ...[
                Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.green.shade700),
                    SizedBox(width: 6),
                    Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900))),
                  ],
                ),
              ] else
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900)),
              SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              if (subtitle != null) ...[
                SizedBox(height: 4),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
              if (isProgress) ...[
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: occupancyRate / 100,
                    color: Colors.green.shade600,
                    backgroundColor: Colors.green.shade100,
                  ),
                ),
              ]
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSahaBilgileriTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Halı Saha Bilgileri",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800)),
                  SizedBox(height: 16),
                  _buildTextField("Halı Saha Adı", nameController,
                      maxLength: 100),
                  _buildTextField("Konum", locationController, maxLength: 100),
                  _buildTextField("Saatlik Ücret (TL)", priceController,
                      isNumber: true, maxLength: 20),
                  _buildTextField("Saha Boyutu", sizeController, maxLength: 20),
                  _buildTextField("Zemin Tipi", surfaceController,
                      maxLength: 40),
                  _buildTextField("Maksimum Oyuncu", maxPlayersController,
                      isNumber: true, maxLength: 20),
                  _buildTextField("Açılış Saati", startHourController,
                      maxLength: 5),
                  _buildTextField("Kapanış Saati", endHourController,
                      maxLength: 5),
                  _buildTextField("Açıklama", descriptionController,
                      isMultiline: true, maxLength: 300),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateHaliSaha,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      minimumSize: Size(
                          double.infinity, 48), // Butonu geniş ve yüksek yap
                    ),
                    child: Text("Bilgileri Güncelle",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildStyledExpansionTile(
            "Özellikler",
            [
              _buildFeatureSwitch("Park Yeri Var", hasParking, (value) {
                setState(() {
                  hasParking = value;
                });
              }),
              _buildFeatureSwitch("Duş Var", hasShowers, (value) {
                setState(() {
                  hasShowers = value;
                });
              }),
              _buildFeatureSwitch("Ayakkabı Kiralama", hasShoeRental, (value) {
                setState(() {
                  hasShoeRental = value;
                });
              }),
              _buildFeatureSwitch("Kafeterya Var", hasCafeteria, (value) {
                setState(() {
                  hasCafeteria = value;
                });
              }),
              _buildFeatureSwitch("Gece Aydınlatması Var", hasNightLighting,
                  (value) {
                setState(() {
                  hasNightLighting = value;
                });
              }),
            ],
          ),
          SizedBox(height: 16),
          _buildStyledExpansionTile(
            "Saha Görünümü",
            [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: currentHaliSaha.imagesUrl.isNotEmpty
                      ? Image.asset(
                          "assets/halisaha_images/${currentHaliSaha.imagesUrl.first}",
                          fit: BoxFit.cover)
                      : Center(child: Text("Fotoğraf yok")),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStyledExpansionTile(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        iconColor: Colors.green.shade800,
        collapsedIconColor: Colors.green.shade600,
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.green.shade800)),
        children: children,
      ),
    );
  }

  Widget _buildFeatureSwitch(
      String title, bool currentValue, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: Colors.black87)),
      value: currentValue,
      onChanged: onChanged,
      activeColor: Colors.green.shade600,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isMultiline = false,
    int maxLength = 300, // ⚠️ karakter sınırı opsiyonel parametre olarak geldi
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? TextInputType.number
            : (isMultiline ? TextInputType.multiline : TextInputType.text),
        maxLines: isMultiline ? 4 : 1,
        maxLength: maxLength,
        // ✅ karakter sınırı burada uygulanır
        buildCounter: (
          BuildContext context, {
          required int currentLength,
          required bool isFocused,
          required int? maxLength,
        }) {
          return maxLength != null
              ? Text(
                  "$currentLength / $maxLength",
                  style: TextStyle(
                    fontSize: 11,
                    color: currentLength > maxLength
                        ? Colors.red
                        : Colors.grey.shade600,
                  ),
                )
              : null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // Güncelleme Fonksiyonu
  Future<void> _updateHaliSaha() async {
    print("Güncelleme işlemi başlatıldı.");

    // Giriş doğrulama
    String? validationError = _validateInputs();
    if (validationError != null) {
      print("Doğrulama hatası: $validationError");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print("Girişler doğrulandı.");

      // Sayısal alanları parse etme
      double price = double.parse(priceController.text.trim());
      int maxPlayers = int.parse(maxPlayersController.text.trim());
      print("Fiyat: $price, Maksimum Oyuncu: $maxPlayers");

      // Güncellenmiş Halı Saha nesnesi oluşturma
      HaliSaha updatedSaha = currentHaliSaha.copyWith(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        price: price,
        size: sizeController.text.trim(),
        surface: surfaceController.text.trim(),
        maxPlayers: maxPlayers,
        startHour: startHourController.text.trim(),
        endHour: endHourController.text.trim(),
        description: descriptionController.text.trim(),
        hasParking: hasParking,
        hasShowers: hasShowers,
        hasShoeRental: hasShoeRental,
        hasCafeteria: hasCafeteria,
        hasNightLighting: hasNightLighting,
      );
      print(
          "Güncellenmiş Halı Saha nesnesi oluşturuldu: ${updatedSaha.toJson()}");

      // Değiştirilen alanları belirleme
      Map<String, dynamic> updateData =
          _getChangedFields(currentHaliSaha, updatedSaha);
      if (updateData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Değişiklik yapmadınız.'),
            backgroundColor: Colors.blue,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print("Güncellenen veriler: $updateData");

      DateTime startTime = TimeService.now();
      DateTime endTime = TimeService.now();

      // Firestore'da sadece değiştirilen alanları güncelleme
      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(currentHaliSaha.id)
          .update(updateData);

      print(
          "Firestore güncellemesi tamamlandı. Süre: ${endTime.difference(startTime).inMilliseconds} ms");

      // Yerel durumu güncelleme
      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(currentHaliSaha.id)
          .get()
          .then((doc) {
        if (doc.exists) {
          setState(() {
            currentHaliSaha =
                HaliSaha.fromJson(doc.data()!, currentHaliSaha.id);
          });
        }
      });

      print("Yerel durum güncellendi.");

      // Başarı mesajı gösterme
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Halı Saha başarıyla güncellendi.'),
          backgroundColor: Colors.green,
        ),
      );
      print("Başarı mesajı gösterildi.");
    } catch (e, stack) {
      // Hata durumunda kullanıcıya bildirim
      print("Güncelleme sırasında bir hata oluştu: $e");
      print(stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Güncelleme sırasında bir hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Değiştirilen alanları belirleme fonksiyonu
  Map<String, dynamic> _getChangedFields(HaliSaha oldSaha, HaliSaha newSaha) {
    Map<String, dynamic> changedFields = {};

    if (oldSaha.name != newSaha.name) changedFields['name'] = newSaha.name;
    if (oldSaha.location != newSaha.location)
      changedFields['location'] = newSaha.location;
    if (oldSaha.price != newSaha.price) changedFields['price'] = newSaha.price;
    if (oldSaha.size != newSaha.size) changedFields['size'] = newSaha.size;
    if (oldSaha.surface != newSaha.surface)
      changedFields['surface'] = newSaha.surface;
    if (oldSaha.maxPlayers != newSaha.maxPlayers)
      changedFields['maxPlayers'] = newSaha.maxPlayers;
    if (oldSaha.startHour != newSaha.startHour)
      changedFields['startHour'] = newSaha.startHour;
    if (oldSaha.endHour != newSaha.endHour)
      changedFields['endHour'] = newSaha.endHour;
    if (oldSaha.description != newSaha.description)
      changedFields['description'] = newSaha.description;
    if (oldSaha.hasParking != newSaha.hasParking)
      changedFields['hasParking'] = newSaha.hasParking;
    if (oldSaha.hasShowers != newSaha.hasShowers)
      changedFields['hasShowers'] = newSaha.hasShowers;
    if (oldSaha.hasShoeRental != newSaha.hasShoeRental)
      changedFields['hasShoeRental'] = newSaha.hasShoeRental;
    if (oldSaha.hasCafeteria != newSaha.hasCafeteria)
      changedFields['hasCafeteria'] = newSaha.hasCafeteria;
    if (oldSaha.hasNightLighting != newSaha.hasNightLighting)
      changedFields['hasNightLighting'] = newSaha.hasNightLighting;

    return changedFields;
  }

  // Giriş Doğrulama Fonksiyonu
  String? _validateInputs() {
    if (nameController.text.trim().isEmpty) {
      return "Halı Saha Adı boş olamaz.";
    }
    if (locationController.text.trim().isEmpty) {
      return "Konum boş olamaz.";
    }
    if (priceController.text.trim().isEmpty) {
      return "Saatlik Ücret boş olamaz.";
    }
    if (sizeController.text.trim().isEmpty) {
      return "Saha Boyutu boş olamaz.";
    }
    if (surfaceController.text.trim().isEmpty) {
      return "Zemin Tipi boş olamaz.";
    }
    if (maxPlayersController.text.trim().isEmpty) {
      return "Maksimum Oyuncu boş olamaz.";
    }
    if (startHourController.text.trim().isEmpty) {
      return "Açılış Saati boş olamaz.";
    }
    if (endHourController.text.trim().isEmpty) {
      return "Kapanış Saati boş olamaz.";
    }
    if (descriptionController.text.trim().isEmpty) {
      return "Açıklama boş olamaz.";
    }
    return null;
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

  List<String> get timeSlots {
    // Start ve end saatlerini parçalama
    final startParts = widget.haliSaha.startHour.split(':');
    final endParts = widget.haliSaha.endHour.split(':');

    int startHour = int.parse(startParts[0]);
    int startMinute = int.parse(startParts[1]);
    int endHour = int.parse(endParts[0]);
    int endMinute = int.parse(endParts[1]);

    // Eğer endHour startHour'dan küçükse, gece yarısını geçtiğini gösterir.
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

    // 00:00 slotunun en başta olması için sıralama ekleme
    slots.sort((a, b) {
      // Slotların başlangıç saatlerini al
      int aHour = int.parse(a.split(':')[0]);
      int bHour = int.parse(b.split(':')[0]);
      return aHour.compareTo(bHour);
    });

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
    return widget.haliSaha.bookedSlots.contains(bookingString);
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

  bool _hasNotificationsInNextMonth() {
    // Şu anki seçili ayın son günü
    DateTime lastDayOfCurrentMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      0, // Ayın son günü
    );

    // Sonraki ayın başlangıç ve bitiş günleri
    DateTime firstDayOfNextMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 1,
      1,
    );

    DateTime lastDayOfNextMonth = DateTime(
      selectedDate.year,
      selectedDate.month + 2,
      0,
    );

    // Aktif rezervasyon penceresi sınırı (7 gün)
    DateTime bookingWindowLimit = TimeService.now().add(Duration(days: 7));

    // Eğer rezervasyon penceresi mevcut ayı geçiyorsa
    if (bookingWindowLimit.isAfter(lastDayOfCurrentMonth)) {
      // requestCountMap'te sonraki aya ait günler için bildirim kontrolü
      for (DateTime date in requestCountMap.keys) {
        // Tarih normalizasyonu - yalnızca yıl, ay, gün önemli
        DateTime normalizedDate = DateTime(date.year, date.month, date.day);

        // Tarih, sonraki ay içinde mi kontrol et
        bool isInNextMonth = normalizedDate
                .isAfter(firstDayOfNextMonth.subtract(Duration(days: 1))) &&
            normalizedDate.isBefore(lastDayOfNextMonth.add(Duration(days: 1)));

        if (isInNextMonth &&
            requestCountMap[normalizedDate] != null &&
            requestCountMap[normalizedDate]! > 0) {
          return true; // Sonraki ayda bildirim var
        }
      }
    }

    return false; // Sonraki ayda bildirim yok
  }

  // Rezervasyonlar Tab Widget'ı
  Widget _buildRezervasyonlarTab() {
    final daysInMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final firstDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month, 1).weekday;
    final selectedMonthYear = DateFormat.yMMMM('tr_TR').format(selectedDate);
    DateTime now = TimeService.now();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Rezervasyon Takvimi",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
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
                  blurRadius: 5,
                )
              ],
            ),
            child: Column(
              children: [
                // Ay bilgisi ve sonraki ay butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left),
                      onPressed: selectedDate.month == TimeService.now().month
                          ? null
                          : handlePrevMonth,
                      color: selectedDate.month == TimeService.now().month
                          ? Colors.grey[300]
                          : null,
                    ),
                    Text(
                      selectedMonthYear,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      // Çocuk widget'ların taşmasına izin ver
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: handleNextMonth,
                        ),
                        if (_hasNotificationsInNextMonth())
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: Offset(2, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Takvim günleri
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: daysInMonth + firstDayOfMonth - 1,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                  ),
                  itemBuilder: (context, index) {
                    if (index < firstDayOfMonth - 1) {
                      return SizedBox.shrink();
                    }

                    final day = index - firstDayOfMonth + 2;
                    final isSelected = day == selectedDate.day;
                    final currentDay =
                        DateTime(selectedDate.year, selectedDate.month, day);
                    final isPastDay = currentDay
                        .isBefore(DateTime(now.year, now.month, now.day));

                    // Bugünden itibaren maksimum 7 gün ilerisi için rezervasyon yapılabilir
                    final DateTime maxDate =
                        TimeService.now().add(Duration(days: 7));

                    // Ve takvim gösteriminde bu kontrolü ekleriz
                    final bool isInBookingWindow = !currentDay.isAfter(maxDate);

                    DateTime normalizedCurrentDay = DateTime(
                        currentDay.year, currentDay.month, currentDay.day);
                    int requestCount =
                        requestCountMap[normalizedCurrentDay] ?? 0;

                    // Seçilmiş gün arka plan (gradient) - modern bir dokunuş
                    BoxDecoration dayDecoration;
                    if (isSelected) {
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
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Gün sayısı
                            Text(
                              day.toString(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isPastDay
                                        ? Colors.grey.shade700
                                        : (!isInBookingWindow
                                            ? Colors.grey
                                                .shade700 // Rezervasyon penceresi dışı: Daha soluk metin
                                            : Colors.black87)),
                                // Rezervasyon penceresi içi: Normal metin
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: isSelected ? 16 : 14,
                              ),
                            ),

                            // Bildirim baloncuğu
                            if (!isPastDay && requestCount > 0)
                              Positioned(
                                top: 0,
                                right: 4,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 6,
                                        offset: Offset(4, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    requestCount.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Seçilen Tarih ve Gün Adı
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "${DateFormat('EEEE, dd MMMM yyyy', 'tr_TR').format(selectedDate)}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Günlük Rezervasyonlar",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          _buildDailyReservationsTable(),
        ],
      ),
    );
  }

  Widget _buildDailyReservationsTable() {
    final allSlots = timeSlots; // Örn: [ "05:00-06:00", "06:00-07:00", ... ]

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          columnWidths: {
            0: FixedColumnWidth(120),
            1: FixedColumnWidth(120),
            2: FlexColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Colors.green.shade100,
              ),
              children: [
                _tableHeaderCell(
                  "Saat",
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                ),
                _tableHeaderCell(
                  "Durum",
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                ),
                _tableHeaderCell(
                  "İşlem",
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),

            // Tüm saatleri tabloya ekle
            ...allSlots.map((slot) {
              // slot örnek olarak "05:00-06:00" formatında geliyor
              String time = slot;
              // Şimdi sadece başlangıç saatini (örn. "05:00") alalım
              String startTimeStr = time.split('-')[0]; // "05:00"
              // Başlangıç saatinden "05" kısmını elde edelim
              String hourStr = startTimeStr.split(':')[0]; // "05"
              int slotHour =
                  int.parse(hourStr); // Bu artık sayısal dönüştürülebilir

              bool reserved = isReserved(time);
              bool pending = hasPendingRequest(time);
              bool completed = isCompleted(time);

              DateTime now = TimeService.now();
              bool isPastTimeToday = isTodaySelected() && slotHour <= now.hour;

              IconData statusIcon;
              Color statusColor;
              String statusText;

              if (completed) {
                statusIcon = Icons.check_circle_outline;
                statusColor = Colors.blue;
                statusText = "Tamamlandı";
              } else if (reserved) {
                statusIcon = Icons.check_circle;
                statusColor = Colors.green;
                statusText = "Rezerve";
              } else if (pending) {
                statusIcon = Icons.priority_high;
                statusColor = Colors.orange;
                statusText = "İstek Var";
              } else if (isPastTimeToday) {
                statusIcon = Icons.history;
                statusColor = Colors.grey;
                statusText = "Geçti";
              } else {
                statusIcon = Icons.circle;
                statusColor = Colors.grey;
                statusText = "Müsait";
              }

              return TableRow(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                children: [
                  _tableCellText(
                    time,
                    textStyle: TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 18),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: _buildActionButton(
                          reserved, pending, completed, time, isPastTimeToday),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  bool isTodaySelected() {
    DateTime now = TimeService.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  bool isCompleted(String time) {
    try {
      // time: "05:00-06:00"
      String startTimeStr = time.split('-')[0]; // "05:00"

      // "HH:mm" formatından DateTime oluştur
      DateTime parsedStartTime = DateFormat("HH:mm").parse(startTimeStr);
      DateTime reservationDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        parsedStartTime.hour,
        parsedStartTime.minute,
      );

      // Aradığımız reservationDateTime stringi: "YYYY-MM-DD HH:00-(HH+1):00"
      String formattedStart = DateFormat("HH:mm").format(reservationDateTime);
      String formattedEnd = DateFormat("HH:mm")
          .format(reservationDateTime.add(Duration(hours: 1)));
      String reservationDateTimeStr =
          "${DateFormat("yyyy-MM-dd").format(selectedDate)} $formattedStart-$formattedEnd";

      var matchingReservations = haliSahaReservations
          .where((r) =>
              r.reservationDateTime == reservationDateTimeStr &&
              r.status == 'Tamamlandı')
          .toList();

      return matchingReservations.isNotEmpty;
    } catch (e) {
      debugPrint("isCompleted fonksiyonunda hata oluştu: $e");
      return false;
    }
  }

// Bu fonksiyon buton stillerini daha modern hale getirir.
// Mantık aynı kalır, sadece stil değişir.
  Widget _buildActionButton(bool reserved, bool pending, bool completed,
      String time, bool isPastTimeToday) {
    // Eğer tamamlanmışsa, Detaylar butonu çıksın:
    if (completed) {
      return ElevatedButton(
        onPressed: () {
          _showCompletedReservationDetailDialog(time);
        },
        child: Text(
          "Detaylar",
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 2,
        ),
      );
    }

    // Eğer rezerve ise
    if (reserved) {
      return ElevatedButton(
        onPressed: () {
          _showReservationDetailDialog(time);
        },
        child: Text(
          "Detaylar",
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 2,
        ),
      );
    } else if (pending) {
      return ElevatedButton(
        onPressed: () {
          _showReservationDialog(time);
        },
        child: Text(
          "Görüntüle",
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 2,
        ),
      );
    } else {
      // Eğer geçmiş saat ise ve rezervasyon yok, buton göstermeyelim:
      if (isPastTimeToday) {
        // Geçmiş saat, rezerve değil, istek yok => Buton yok, boş dön
        return SizedBox.shrink();
      }

      // Diğer durumlarda rezerve et butonu
      return ElevatedButton(
        onPressed: () async {
          await _makeReservation(time);
        },
        child: Text(
          "Rezerve Et",
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 2,
        ),
      );
    }
  }

  bool hasPendingRequest(String time) {
    String bookingDateTime =
        "${DateFormat('yyyy-MM-dd').format(selectedDate)} $time";
    return haliSahaReservations.any((reservation) =>
        reservation.reservationDateTime == bookingDateTime &&
        reservation.status == "Beklemede");
  }

  bool isReserved(String time) {
    String bookingDateTime =
        "${DateFormat('yyyy-MM-dd').format(selectedDate)} $time";
    return haliSahaReservations.any((reservation) =>
        reservation.reservationDateTime == bookingDateTime &&
        reservation.status == "Onaylandı");
  }

  void _showReservationDetailDialog(String time) {
    try {
      // Seçili gün + saat dilimi anahtarını oluştur
      final key = '${DateFormat('yyyy-MM-dd').format(selectedDate)} $time';
      print("Key: $key");
      // Tam eşleşme ile doğru rezervasyonu bul
      final reservation = haliSahaReservations.firstWhere(
        (r) => r.reservationDateTime == key,
      );
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst Kısım - Başlık ve İkon
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Rezervasyon Detayları",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // İçerik Alanı
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailItem(Icons.person, "Kullanıcı Adı",
                            reservation.userName),
                        SizedBox(height: 8),
                        _detailItem(
                            Icons.phone, "Telefon", reservation.userPhone),
                        SizedBox(height: 8),
                        _detailItem(
                            Icons.email, "E-posta", reservation.userEmail),
                        SizedBox(height: 8),
                        _detailItem(Icons.calendar_today, "Tarih ve Saat",
                            reservation.reservationDateTime),
                        // Eğer Konum bilgisi gerekli değilse aşağıdaki satırı kaldırabilirsiniz
                        // SizedBox(height: 8),
                        // _detailItem(Icons.location_on, "Konum", reservation.haliSahaLocation),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),
                  Divider(),

                  // Butonlar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rezervasyonu İptal Et Butonu
                        ElevatedButton.icon(
                          onPressed: () {
                            _showCancelConfirmation(context, reservation);
                          },
                          icon: Icon(Icons.cancel, color: Colors.white),
                          label: Text(
                            "Rezervasyonu İptal Et",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            textStyle: TextStyle(fontSize: 15),
                          ),
                        ),

                        // Kapat Butonu
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Kapat",
                            style: TextStyle(
                                color: Colors.grey.shade800, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Rezervasyon Detayları bulunamadı: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rezervasyon detayları bulunamadı.")),
      );
    }
  }

  void _showCompletedReservationDetailDialog(String time) {
    try {
      // 1️⃣  Seçili gün + slot → tek anahtar
      final key = '${DateFormat('yyyy-MM-dd').format(selectedDate)} $time';

      // 2️⃣  Sadece TAMAMLANDI durumundakilerde ara, bulunamazsa null dön
      final reservation = haliSahaReservations.firstWhere(
        (r) => r.reservationDateTime == key && r.status == 'Tamamlandı',
      );

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst Kısım - Başlık ve İkon
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Rezervasyon Detayları",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // İçerik Alanı
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailItem(Icons.person, "Kullanıcı Adı",
                            reservation.userName),
                        SizedBox(height: 8),
                        _detailItem(
                            Icons.phone, "Telefon", reservation.userPhone),
                        SizedBox(height: 8),
                        _detailItem(
                            Icons.email, "E-posta", reservation.userEmail),
                        SizedBox(height: 8),
                        _detailItem(Icons.calendar_today, "Tarih ve Saat",
                            reservation.reservationDateTime),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),
                  Divider(),

                  // Butonlar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Kapat Butonu
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Kapat",
                            style: TextStyle(
                                color: Colors.grey.shade800, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Rezervasyon Detayları bulunamadı: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rezervasyon detayları bulunamadı.")),
      );
    }
  }

// Yardımcı Widget: Detay Satırı
  Widget _detailItem(IconData icon, String title, String? value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade700),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value ?? "Bilgi yok",
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// İptal Onay Dialogu
  void _showCancelConfirmation(BuildContext context, Reservation reservation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text("Rezervasyonu İptal Et",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Text(
            "Bu rezervasyonu iptal etmek istediğinize emin misiniz?",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text("Vazgeç", style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _rejectReservation(reservation);
                Navigator.pop(context); // Onay dialogunu kapat
                Navigator.pop(context); // Ana dialogu kapat
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child:
                  Text("Evet, İptal Et", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showReservationDialog(String time) {
    // Seçilen gün + saat dilimini içeren tam anahtar
    final key = '${DateFormat('yyyy-MM-dd').format(selectedDate)} $time';

    // Güvenli arama: firstWhereOrNull (ya da try/catch)
    final reservation = haliSahaReservations.firstWhere(
      (r) => r.reservationDateTime == key && r.status == 'Beklemede',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // Arka plan rengi
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üst kısım (Başlık, ikon)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Rezervasyon Detayları",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // İçerik alanı
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kullanıcı bilgileri
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation.userName ?? "İsim bilgisi yok",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation.userPhone ?? "Telefon yok",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.email, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation.userEmail ?? "Email yok",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Divider(),
                      SizedBox(height: 12),

                      // Tarih / Saat
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reservation.reservationDateTime,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Durum: ${reservation.status}",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),

                // Alt kısım butonlar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Reddet butonu
                      ElevatedButton.icon(
                        onPressed: () {
                          _rejectReservation(reservation); // Reddet
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.close, color: Colors.white),
                        label: Text("Reddet",
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          textStyle: TextStyle(fontSize: 15),
                        ),
                      ),

                      // Onayla butonu
                      ElevatedButton.icon(
                        onPressed: () {
                          _approveReservation(reservation); // Onayla
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.check, color: Colors.white),
                        label: Text(
                          "Onayla",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          textStyle: TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveReservation(Reservation reservation) async {
    try {
      await FirebaseFirestore.instance
          .collection("reservations")
          .doc(reservation.id)
          .update({"status": "Onaylandı", 'lastUpdatedBy': 'owner'});
      debugPrint("Rezervasyon onaylandı.");
    } catch (e) {
      debugPrint("Rezervasyon onaylama hatası: $e");
    }
  }

  Future<void> _rejectReservation(Reservation reservation) async {
    try {
      await FirebaseFirestore.instance
          .collection("reservations")
          .doc(reservation.id)
          .update({"status": "İptal Edildi", 'lastUpdatedBy': 'owner'});
      debugPrint("Rezervasyon reddedildi.");
    } catch (e) {
      debugPrint("Rezervasyon reddetme hatası: $e");
    }
    _cancelReservation(reservation.reservationDateTime);
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

      Reservation reservation = Reservation(
        id: docRef.id,
        userId: _auth.currentUser!.uid,
        haliSahaId: widget.haliSaha.id,
        haliSahaName: widget.haliSaha.name,
        haliSahaLocation: widget.haliSaha.location,
        haliSahaPrice: widget.haliSaha.price,
        reservationDateTime: bookingString,
        status: "Onaylandı",
        createdAt: TimeService.now(),
        userName: widget.currentOwner.name,
        userEmail: widget.currentOwner.email,
        userPhone: widget.currentOwner.phone,
        lastUpdatedBy: widget.currentOwner.role,
      );

      // Rezervasyonu Firestore'daki "reservations" koleksiyonuna ekle
      await docRef.set(reservation.toMap(), SetOptions(merge: false));

      // Başarılı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saat $time başarıyla rezerve edildi.")),
      );
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'reservation');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rezervasyon başarısız: $msg"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelReservation(String time) async {
    String bookingString = "$time";
    print(bookingString);

    try {
      final success = await ReservationRemoteService().cancelSlot(
        haliSahaId: widget.haliSaha.id,
        bookingString: bookingString,
      );

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Rezervasyon iptal edilemedi. Lütfen tekrar deneyin."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

// UI'den kaldır
      setState(() {
        widget.haliSaha.bookedSlots.remove(bookingString);
      });

// Başarılı mesaj
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Rezervasyonunuz başarıyla iptal edildi!")),
      );
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'reservation');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rezervasyon iptali başarısız: $msg"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _tableHeaderCell(String text, {TextStyle? textStyle}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          style:
              textStyle ?? TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _tableCellText(String text, {Color? color, TextStyle? textStyle}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          style: textStyle ??
              TextStyle(
                color: color ?? Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

void _showNotificationPanel(BuildContext context, HaliSaha haliSaha) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return OwnerNotificationPanel(
        currentHaliSaha: haliSaha,
      );
    },
  );
}

// HaliSaha sınıfında copyWith metodu eklenmeli
extension HaliSahaCopyWith on HaliSaha {
  HaliSaha copyWith({
    String? name,
    String? location,
    double? price,
    String? size,
    String? surface,
    int? maxPlayers,
    String? startHour,
    String? endHour,
    String? description,
    bool? hasParking,
    bool? hasShowers,
    bool? hasShoeRental,
    bool? hasCafeteria,
    bool? hasNightLighting,
  }) {
    return HaliSaha(
      ownerId: this.ownerId,
      name: name ?? this.name,
      location: location ?? this.location,
      price: price ?? this.price,
      rating: this.rating,
      imagesUrl: this.imagesUrl,
      bookedSlots: this.bookedSlots,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      id: this.id,
      hasParking: hasParking ?? this.hasParking,
      hasShowers: hasShowers ?? this.hasShowers,
      hasShoeRental: hasShoeRental ?? this.hasShoeRental,
      hasCafeteria: hasCafeteria ?? this.hasCafeteria,
      hasNightLighting: hasNightLighting ?? this.hasNightLighting,
      description: description ?? this.description,
      size: size ?? this.size,
      surface: surface ?? this.surface,
      maxPlayers: maxPlayers ?? this.maxPlayers,
    );
  }
}
