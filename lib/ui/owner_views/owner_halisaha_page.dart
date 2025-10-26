import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/core/providers/owner_providers/StatsProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/reservation_remote_service.dart';
import 'package:toplansin/services/subscription_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/owner_views/dialogs/show_custom_hours_dialog.dart';
import 'package:toplansin/ui/owner_views/owner_access_code_page.dart';
import 'package:toplansin/ui/owner_views/owner_past_reservation_page.dart';
import 'package:toplansin/ui/owner_views/owner_past_subscriptions.dart';
import 'package:toplansin/ui/owner_views/owner_photo_management_page.dart';
import 'package:toplansin/ui/owner_views/owner_reviews_page.dart';
import 'package:toplansin/core/providers/owner_providers/OwnerNotificationProvider.dart';
import 'package:toplansin/ui/owner_views/owner_user_statistics_panel.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerHalisahaPage extends StatefulWidget {
  HaliSaha haliSaha;
  final Person currentOwner;
  var notificationCount;
  BuildContext context;

  OwnerHalisahaPage({
    required this.haliSaha,
    required this.currentOwner,
    required this.context,
  });

  @override
  _OwnerHalisahaPageState createState() => _OwnerHalisahaPageState();
}

class _OwnerHalisahaPageState extends State<OwnerHalisahaPage> {
  DateTime selectedDate = TimeService.now();
  String? selectedTime;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<QuerySnapshot>? _allReservationsSubscription;
  StreamSubscription<QuerySnapshot>? _todaysApprovedReservationsSubscription;
  StreamSubscription<QuerySnapshot>? _pendingReservationsSubscription;
  StreamSubscription<DocumentSnapshot>? haliSahaSubscription;
  StreamSubscription<User?>? _authSub;

  List<Reservation> haliSahaReservations = [];
  List<Reservation> haliSahaReservationsApproved = [];
  List<Reservation> haliSahaReservationsRequests = [];
  List<DateTime> requestDays = [];
  Map<DateTime, int> requestCountMap = {}; // GÜN İSTEK SAYILARI İÇİN EKLENDİ

  num todaysRevenue = 0;
  int todaysReservation = 0;
  int occupancyRate = 0;
  int totalOpenHours = 0;

  Map<int, int> pendingCountsByDay = {};

  String selectedDay = "Pzt";

  bool _useOverrides = false;
  Map<int, ({String start, String end})> _overrides = {};
  bool _loadingHours = true;


  Future<void> _fetchStartEndOverrides() async {
    try {
      setState(() => _loadingHours = true);
      final info = await loadStartEndOverrides(widget.haliSaha.id);
      if (!mounted) return;
      setState(() {
        _useOverrides = info.useOverrides; // koleksiyon boş değilse true
        _overrides    = info.map;          // 0..6 -> (start,end)
        _loadingHours = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Hata durumunda varsayılan saatlere düş
      _useOverrides = false;
      _overrides.clear();
      setState(() => _loadingHours = false);
    }
  }


  void listenToReservations(String haliSahaId) {
    // Eski abonelikleri güvenle kapat
    _allReservationsSubscription?.cancel();
    _todaysApprovedReservationsSubscription?.cancel();
    _pendingReservationsSubscription?.cancel();
    _authSub?.cancel();

    // 0) Auth değişimini dinle: logout'ta state temizle
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (!mounted) return;
        setState(() {
          // Tüm user-scoped state'leri sıfırla
          haliSahaReservations = const <Reservation>[];
          haliSahaReservationsApproved = const <Reservation>[];
          todaysRevenue = 0;
          todaysReservation = 0;
          occupancyRate = 0;
          requestDays = const <DateTime>[];
          requestCountMap = <DateTime, int>{};
        });
      }
    });

    // 1) Tüm rezervasyonlar (auth'a bağlı switch)
    _allReservationsSubscription =
        FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) {
        // unauth → Firestore'a bağlanma
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .snapshots();
    }).listen((snapshot) {
      final reservations = snapshot.docs
          .map((d) => Reservation.fromDocument(d))
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        haliSahaReservations = reservations;
      });

      debugPrint("Rezervasyonlar güncellendi: ${reservations.length} adet.");
    }, onError: (e, st) {
      debugPrint('allReservations stream error: $e');
    });

    // 2) Bugüne ait Onaylandı/Tamamlandı rezervasyonlar (auth'a bağlı)
    final now = TimeService.now();
    final todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowDate =
        "${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";

    final startDateTime = "$todayDate 00:00-00:00";
    final endDateTime = "$tomorrowDate 00:00-00:00";

    _todaysApprovedReservationsSubscription =
        FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .where("status", whereIn: ['Onaylandı', 'Tamamlandı'])
          .where("reservationDateTime", isGreaterThanOrEqualTo: startDateTime)
          .where("reservationDateTime", isLessThan: endDateTime)
          .snapshots();
    }).listen((snapshot) {
      final todaysApproved = snapshot.docs
          .map((d) => Reservation.fromDocument(d))
          .toList(growable: false);

      // Geliri ve doluluğu hesapla
      final revenue = calculateTodaysRevenue(todaysApproved);
      final totalHours = calculateOpenHours(
          widget.haliSaha.startHour, widget.haliSaha.endHour);
      final count = todaysApproved.length;
      final occRate = totalHours > 0 ? (count * 100) ~/ totalHours : 0;

      if (!mounted) return;
      setState(() {
        haliSahaReservationsApproved = todaysApproved;
        todaysRevenue = revenue;
        todaysReservation = count;
        occupancyRate = occRate;
      });

      debugPrint("Onaylanan/Tamamlanan (bugün): $count adet, Gelir: $revenue");
    }, onError: (e, st) {
      debugPrint('todaysApproved stream error: $e');
    });

    // 3) Beklemede rezervasyonlar (auth'a bağlı)
    _pendingReservationsSubscription =
        FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .where("status", isEqualTo: 'Beklemede')
          .snapshots();
    }).listen((snapshot) {
      final reservations = <Reservation>[];
      final tempRequestDays = <DateTime>[];
      final tempRequestCount = <DateTime, int>{};

      for (final doc in snapshot.docs) {
        final reservation = Reservation.fromDocument(doc);
        reservations.add(reservation);

        // reservationDateTime formatı: "YYYY-MM-DD HH:mm-HH:mm"
        final raw = doc['reservationDateTime'] as String? ?? '';
        final dateStr = (raw.split(' ').isNotEmpty) ? raw.split(' ')[0] : '';
        try {
          final dayOnly = DateTime.parse(dateStr);
          final normalized = DateTime(dayOnly.year, dayOnly.month, dayOnly.day);
          tempRequestDays.add(dayOnly);
          tempRequestCount.update(normalized, (v) => v + 1, ifAbsent: () => 1);
        } catch (_) {
          // parse edilemeyen kayıtları atla
        }
      }

      if (!mounted) return;
      setState(() {
        haliSahaReservationsRequests = reservations;
        requestDays = tempRequestDays;
        requestCountMap = tempRequestCount;
      });

      debugPrint("Beklemede rezervasyonlar: ${reservations.length} adet.");
    }, onError: (e, st) {
      debugPrint('pendingReservations stream error: $e');
    });
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
    // önce eski dinlemeyi kapat
    haliSahaSubscription?.cancel();

    // Eğer bu doküman public okunabiliyorsa, auth guard zorunlu değil.
    // Ama kurallar auth istiyorsa, aşağıdaki asyncExpand guard'ı iş görür.
    haliSahaSubscription =
        FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
      // Kurallar auth istemiyorsa, user == null olsa da bağlanmak isteyebilirsin:
      // return FirebaseFirestore.instance.collection('hali_sahalar').doc(haliSahaId).snapshots();

      // Kurallar auth istiyorsa (PERMISSION_DENIED görüyorsan) unauth iken bağlanma:
      if (user == null) {
        return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
      }
      return FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(haliSahaId) // ⬅️ parametreyi kullan
          .snapshots();
    }).listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final h = HaliSaha.fromJson(data, haliSahaId);

      // +90 temizleme (küçük helper)
      String _normalizePhone(String raw) {
        if (raw.startsWith('+90 ')) return raw.substring(4);
        if (raw.startsWith('+90')) return raw.substring(3);
        return raw;
      }

      // Controller’lara yazmak için setState gerekmez
      nameController.text = h.name;
      locationController.text = h.location;
      priceController.text = h.price.toString();
      phoneController.text = _normalizePhone(h.phone);
      sizeController.text = h.size;
      surfaceController.text = h.surface;
      maxPlayersController.text = h.maxPlayers.toString();
      startHourController.text = h.startHour;
      endHourController.text = h.endHour;
      descriptionController.text = h.description;
      latController.text = h.latitude.toString();
      lngController.text = h.longitude.toString();

      if (!mounted) return;
      setState(() {
        currentHaliSaha = h;

        hasParking = h.hasParking;
        hasShowers = h.hasShowers;
        hasShoeRental = h.hasShoeRental;
        hasCafeteria = h.hasCafeteria;
        hasNightLighting = h.hasNightLighting;
        hasCameras = h.hasCameras;
        hasFoodService = h.hasFoodService;
        hasFoosball = h.hasFoosball;
        hasMaleToilet = h.hasMaleToilet;
        hasFemaleToilet = h.hasFemaleToilet;
        acceptsCreditCard = h.acceptsCreditCard;
        hasGoalkeeper = h.hasGoalkeeper;
        hasPlayground = h.hasPlayground;
        hasPrayerRoom = h.hasPrayerRoom;
        hasInternet = h.hasInternet;
      });
    }, onError: (e, st) {
      debugPrint('listenHaliSaha error: $e');
    });
  }

  // Bildirim ayarları gibi diğer değişkenler
  String selectedCurrency = "TRY";
  String selectedLanguage = "tr";
  bool emailNotifications = true;
  bool smsNotifications = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
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
  bool hasMaleToilet = false;
  bool hasFoodService = false;
  bool acceptsCreditCard = false;
  bool hasFoosball = false;
  bool hasCameras = false;
  bool hasGoalkeeper = false;
  bool hasPlayground = false;
  bool hasPrayerRoom = false;
  bool hasInternet = false;
  bool hasFemaleToilet = false;

  // Yerel Halı Saha Durumu
  late HaliSaha currentHaliSaha = widget.haliSaha;

  // Yükleniyor durumu
  bool _isLoading = false;

  @override
  void initState() {
    listenToReservations(widget.haliSaha.id);
    super.initState();
    listenHaliSaha(widget.haliSaha.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStartEndOverrides());
  }

  @override
  void dispose() {
    _allReservationsSubscription?.cancel();
    _todaysApprovedReservationsSubscription?.cancel();
    _pendingReservationsSubscription?.cancel();
    haliSahaSubscription?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
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
                      builder: (context) => OwnerPastReservationsPage(
                          haliSahaId: widget.haliSaha.id)),
                );
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
                isScrollable: true,
                labelColor: Colors.green.shade800,
                unselectedLabelColor: Colors.grey.shade600,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                // Sekme genişliği kadar olacak
                indicator: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                labelStyle:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                      child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 4), // ✅ Sekme içi denge
                    child: Text("Genel Bakış"),
                  )),
                  Tab(
                      child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text("Saha Bilgileri"),
                  )),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Consumer<OwnerNotificationProvider>(
                        builder: (context, provider, child) {
                          int reservationNotificationCount =
                              provider.getNotificationCount(
                                  'reservation_${widget.haliSaha.id}');

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text("Rezervasyonlar"),
                              if (reservationNotificationCount > 0)
                                Positioned(
                                  right: -12,
                                  top: -6,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$reservationNotificationCount',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Consumer<OwnerNotificationProvider>(
                        builder: (context, provider, child) {
                          int subscriptionNotificationCount =
                              provider.getNotificationCount(
                                  'subscription_${widget.haliSaha.id}');

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text("Abonelikler"),
                              if (subscriptionNotificationCount > 0)
                                Positioned(
                                  right: -12,
                                  top: -6,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$subscriptionNotificationCount',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  )
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
                _buildSahaBilgileriTab(context),
                _buildRezervasyonlarTab(),
                _buildAboneliklerTab(),
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

  final List<Map<String, String>> days = [
    {'id': 'Pzt', 'label': 'Pzt'},
    {'id': 'Sal', 'label': 'Salı'},
    {'id': 'Çar', 'label': 'Çar'},
    {'id': 'Per', 'label': 'Per'},
    {'id': 'Cum', 'label': 'Cum'},
    {'id': 'Cmt', 'label': 'Cmt'},
    {'id': 'Paz', 'label': 'Paz'},
  ];

  final List<Map<String, String>> mockSlots = [
    {"time": "00:00-01:00", "status": "abone", "statusText": "Abone"},
    {"time": "01:00-02:00", "status": "musait", "statusText": "Müsait"},
    {"time": "17:00-18:00", "status": "musait", "statusText": "Müsait"},
    {"time": "18:00-19:00", "status": "musait", "statusText": "Müsait"},
    {"time": "19:00-20:00", "status": "musait", "statusText": "Müsait"},
    {"time": "20:00-21:00", "status": "musait", "statusText": "Müsait"},
    {"time": "21:00-22:00", "status": "musait", "statusText": "Müsait"},
    {"time": "22:00-23:00", "status": "istek", "statusText": "İstek Var"},
    {"time": "23:00-00:00", "status": "musait", "statusText": "Müsait"},
  ];

  Widget statusBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAboneliklerTab() {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Abonelik Yönetimi",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OwnerPastSubscriptionsPage(
                                  haliSahaId: widget.haliSaha.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 20, color: Colors.white),
                          label: const Text(
                            "Geçmiş Aboneler",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade500,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Günler (Beklemede badge'leri)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: (() {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
                        }
                        return FirebaseFirestore.instance
                            .collection('subscriptions')
                            .where('haliSahaId', isEqualTo: widget.haliSaha.id)
                            .where('status', isEqualTo: 'Beklemede')
                            .snapshots();
                      })(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError || !snapshot.hasData) {
                          return buildDayButtonsWithBadges(const <int, int>{});
                        }
                        final docs = snapshot.data!.docs;
                        final Map<int, int> pendingCountsByDay = <int, int>{};
                        for (final d in docs) {
                          final day = d.data()['dayOfWeek'];
                          if (day is int) {
                            pendingCountsByDay[day] = (pendingCountsByDay[day] ?? 0) + 1;
                          }
                        }
                        return buildDayButtonsWithBadges(pendingCountsByDay);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Durum Özeti + Tablo
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: (() {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
                        }
                        return FirebaseFirestore.instance
                            .collection('subscriptions')
                            .where('haliSahaId', isEqualTo: widget.haliSaha.id)
                            .where('dayOfWeek', isEqualTo: getDayOfWeekNumber(selectedDay)) // 1..7
                            .snapshots();
                      })(),
                      builder: (context, snapshot) {
                        // Slotları her seferinde aynı jeneratörden üret (selectedDay bazlı)
                        if (_loadingHours) {
                          return const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        // Bu haftanın selectedDay gününü referans tarih olarak al
                        final refDate = _refDateForSelectedDay();
                        final generatedSlots = generateTimeSlotsForDate(
                          date: refDate,
                          useOverrides: _useOverrides,
                          overrides: _overrides,
                          defaultStart: widget.haliSaha.startHour,
                          defaultEnd: widget.haliSaha.endHour,
                          durationMinutes: 60,
                        )..sort();

                        if (snapshot.hasError) {
                          final int aktifCount = 0, istekCount = 0;
                          final int musaitCount = generatedSlots.length;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  statusBadge("$aktifCount Abone", Icons.check_circle, Colors.blue),
                                  statusBadge("$istekCount İstek", Icons.error_outline, Colors.orange),
                                  statusBadge("$musaitCount Müsait", Icons.circle_outlined, Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTableSkeleton(
                                dayTitle: getDayName(selectedDay),
                                timeSlots: generatedSlots,
                                byTime: const {},
                              ),
                            ],
                          );
                        }

                        if (!snapshot.hasData) {
                          return const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        // Tek geçişte sayımlar + slot→doc index
                        final docs = snapshot.data!.docs;
                        int aktifCount = 0;
                        int istekCount = 0;

                        final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byTime = {};
                        for (final d in docs) {
                          final data = d.data();
                          final status = data['status'] as String? ?? '';
                          final time = data['time'] as String?;

                          if (status == 'Aktif') {
                            aktifCount++;
                          } else if (status == 'Beklemede') {
                            istekCount++;
                          }

                          if (time != null && status != 'İptal Edildi' && status != 'Sona Erdi') {
                            byTime[time] = d; // aynı saate birden çok kayıt varsa son gelen kalır
                          }
                        }

                        // Kaba özet
                        final musaitCountRaw = generatedSlots.length - (aktifCount + istekCount);
                        final musaitCount = musaitCountRaw < 0 ? 0 : musaitCountRaw;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                statusBadge("$aktifCount Abone", Icons.check_circle, Colors.blue),
                                statusBadge("$istekCount İstek", Icons.error_outline, Colors.orange),
                                statusBadge("$musaitCount Müsait", Icons.circle_outlined, Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTableSkeleton(
                              dayTitle: getDayName(selectedDay),
                              timeSlots: generatedSlots,
                              byTime: byTime,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Seçili gün ('Pzt','Sal',...) için bu haftadan bir referans tarih üret
  DateTime _refDateForSelectedDay() {
    final now = TimeService.now();
    final monday = now.subtract(Duration(days: now.weekday - 1)); // 1=Mon..7=Sun
    final dayNumber = getDayOfWeekNumber(selectedDay); // 1..7
    final offset = dayNumber - 1; // Pazartesi = 0
    return DateTime(monday.year, monday.month, monday.day).add(Duration(days: offset));
  }

  /// Küçük yardımcı: tablo iskeleti (tekrar eden UI’yi toplar)
  Widget _buildTableSkeleton({
    required String dayTitle,
    required List<String> timeSlots, // (geri uyum için tutuldu)
    required Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byTime,
  }) {
    if (_loadingHours) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // ► Slotları her zaman aynı jeneratörden üret (override + cross-midnight uyumlu)
    final refDate = _refDateForSelectedDay();
    final slots = generateTimeSlotsForDate(
      date: refDate,
      useOverrides: _useOverrides,
      overrides: _overrides,
      defaultStart: widget.haliSaha.startHour,
      defaultEnd: widget.haliSaha.endHour,
      durationMinutes: 60,
    )..sort();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.blue),
            title: Text(dayTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Günlük Abonelikler", style: TextStyle(fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                Expanded(child: Text("Saat",  style: TextStyle(fontWeight: FontWeight.w500))),
                Expanded(child: Text("Durum", style: TextStyle(fontWeight: FontWeight.w500))),
                Expanded(child: Text("İşlem",  style: TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
          ),

          ...slots.map((slot) {
            final matching = byTime[slot]; // "HH:mm-HH:mm" → snapshot
            String status = 'musait';
            String statusText = 'Müsait';
            IconData icon = Icons.circle_outlined;
            Color iconColor = Colors.grey;

            // Abonelikte tarih kritik değil; istersen "geçti" kontrolünü devre dışı bırak
            // final isPast = _isPastForSelectedDay(slot);

            if (matching != null) {
              final s = matching.data()['status'] as String? ?? '';
              if (s == 'Aktif') {
                status = 'abone';
                statusText = 'Abone';
                icon = Icons.check_circle;
                iconColor = Colors.blue;
              } else if (s == 'Beklemede') {
                status = 'istek';
                statusText = 'İstek Var';
                icon = Icons.error_outline;
                iconColor = Colors.orange;
              }
            }
            // else if (isPast) { ... }  // abonelikte gerekmiyorsa kapalı

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey, width: 0.2),
                  bottom: BorderSide(color: Colors.grey, width: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(slot)),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, color: iconColor, size: 16),
                        const SizedBox(width: 6),
                        Text(statusText, style: TextStyle(color: iconColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (matching == null) {
                          final data = await showInputDialog(context, title: "Abone Bilgisi");
                          if (data == null) return;

                          final int dayOfWeekForSelected = getDayOfWeekNumber(selectedDay);

                          await addOwnerSubscription(
                            context: context,
                            haliSahaId: widget.haliSaha.id,
                            haliSahaName: widget.haliSaha.name,
                            location: widget.haliSaha.location,
                            dayOfWeek: dayOfWeekForSelected,
                            time: slot,
                            price: widget.haliSaha.price,
                            ownerUserId: widget.currentOwner.id,
                            ownerName: data.name,
                            ownerPhone: data.phone,
                            ownerEmail: widget.currentOwner.email,
                          );
                        } else {
                          _showSubscriptionDialog(context, matching);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: status == "abone"
                            ? Colors.green
                            : status == "istek"
                            ? Colors.orange
                            : Colors.blue,
                        minimumSize: const Size.fromHeight(36),
                      ),
                      child: Text(
                        status == "abone"
                            ? "Detaylar"
                            : status == "istek"
                            ? "Görüntüle"
                            : "Abone Gir",
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }


  Widget buildDayButtonsWithBadges(Map<int, int> pendingCountsByDay) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0; // daireler arası boşluk
          final maxW = constraints.maxWidth;
          final btnSize =
              ((maxW - spacing * 6) / 7).clamp(36.0, 48.0); // 7 gün, 6 aralık

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            children: days.map((day) {
              final isSelected = selectedDay == day['id'];
              final dayNumber = getDayOfWeekNumber(day['id']!);
              final badgeCount = pendingCountsByDay[dayNumber] ?? 0;

              return GestureDetector(
                onTap: () => setState(() => selectedDay = day['id']!),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: btnSize,
                      width: btnSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(btnSize / 2),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        day['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        },
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
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.count(
                // ← ❶ return eklendi
                crossAxisCount: 2,
                // daima 2 sütun
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth < 360 ? 1.3 : 1.4,
                // dar ekranda kart biraz uzasın
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildInfoCard("Günlük Gelir", "₺$todaysRevenue"),
                  _buildInfoCard(
                      "Bugünkü Rezervasyonlar", "$todaysReservation"),
                  _buildInfoCard("Doluluk Oranı", "$occupancyRate%",
                      isProgress: true, icon: Icons.show_chart),
                  _buildInfoCard("Müşteri Memnuniyeti",
                      "${currentHaliSaha.rating.toStringAsFixed(1)}/5",
                      icon: Icons.thumb_up),
                ],
              );
            },
          ),
          ownerOperations(context, currentHaliSaha),
        ],
      ),
    );
  }

  Widget actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Widget Function() destination,
  }) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination()),
        );
      },
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 3,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget ownerOperations(BuildContext context, HaliSaha currentHaliSaha) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          "Operasyonel İşlemler",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 20),

        // Saha Erişim Kodu Yönetimi
        actionButton(
          context: context,
          icon: Icons.key_outlined,
          label: "Saha Erişim Kodu Yönetimi",
          backgroundColor: Color(0xFFE65100),
          destination: () =>
              OwnerAccessCodePage(haliSahaId: currentHaliSaha.id),
        ),
        const SizedBox(height: 16),

        // Fotoğraf Yönetimi
        actionButton(
          context: context,
          icon: Icons.photo_library,
          label: "Fotoğraf Yönetimi",
          backgroundColor: Colors.green.shade700,
          destination: () => OwnerPhotoManagementPage(
            images: currentHaliSaha.imagesUrl,
            haliSahaId: currentHaliSaha.id,
          ),
        ),
        const SizedBox(height: 16),

        // Değerlendirmeleri Görüntüle
        actionButton(
          context: context,
          icon: Icons.comment,
          label: "Değerlendirmeleri Görüntüle",
          backgroundColor: Colors.blue.shade700,
          destination: () => OwnerReviewsPage(
            haliSahaId: currentHaliSaha.id,
          ),
        ),
        const SizedBox(height: 16),

        // Kullanıcı İstatistikleri
        actionButton(
          context: context,
          icon: Icons.bar_chart_rounded,
          label: "Kullanıcı İstatistikleri",
          backgroundColor: Colors.redAccent.shade700,
          destination: () =>
              OwnerUserStatisticPanel(haliSahaId: widget.haliSaha.id),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    String value, {
    String? subtitle,
    bool isProgress = false,
    IconData? icon,
  }) {
    return Card(
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 👉  yalnızca içerik kadar yükseklik
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Başlık satırı ───────────────────────────────
            if (icon != null)
              Row(
                children: [
                  Icon(icon, size: 20, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),

            const SizedBox(height: 8),

            // ─── Değer ───────────────────────────────────────
            Text(
              value,
              style: const TextStyle(
                fontSize: 23, // 👉  daha kompakt
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            // ─── Alt başlık (isteğe bağlı) ──────────────────
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],

            // ─── Yüzdelik çubuk (isteğe bağlı) ──────────────
            if (isProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: occupancyRate / 100, // mevcut değişkenini kullanıyor
                  color: Colors.green.shade600,
                  backgroundColor: Colors.green.shade100,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSahaBilgileriTab(BuildContext context) {
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
                  _buildTextField('Enlem (Latitude)', latController,
                      isNumber: true, maxLength: 20),
                  _buildTextField('Boylam (Longitude)', lngController,
                      isNumber: true, maxLength: 20),
                  buildPhoneNumberField(phoneController),
                  _buildTextField("Saatlik Ücret (TL)", priceController,
                      isNumber: true, maxLength: 20),
                  _buildTextField("Saha Boyutu", sizeController, maxLength: 20),
                  _buildTextField("Zemin Tipi", surfaceController,
                      maxLength: 40),
                  _buildTextField("Maksimum Oyuncu", maxPlayersController,
                      isNumber: true, maxLength: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Açılış Saati (örn. 09:00)',
                          startHourController,
                          maxLength: 5,
                          inputFormatters: [
                            _hhmmMask,
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'Kapanış Saati (örn. 23:00)',
                          endHourController,
                          maxLength: 5,
                          inputFormatters: [
                            _hhmmMask,
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await showCustomHoursDialog(
                              context: context, haliSahaId: widget.haliSaha.id);
                          ;
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          backgroundColor: Color(0xFF1ABC9C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                        child: const Text(
                          'Özel Saat Bilgileri Gir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 16,
                  ),
                  _buildTextField("Açıklama", descriptionController,
                      isMultiline: true, maxLength: 800),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            // 1) Yükleniyor durumunu başlat
                            setState(() => _isLoading = true);

                            // 2) Asenkron güncelleme metodunu çağır
                            await _updateHaliSaha();

                            // 3) Yükleniyor durumunu bitir
                            setState(() => _isLoading = false);
                            FocusScope.of(context).unfocus();
                          },
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
              _buildFeatureSwitch("Kamera Var", hasCameras, (value) {
                setState(() {
                  hasCameras = value;
                });
              }),
              _buildFeatureSwitch("Yemek Var", hasFoodService, (value) {
                setState(() {
                  hasFoodService = value;
                });
              }),
              _buildFeatureSwitch("Langırt Var", hasFoosball, (value) {
                setState(() {
                  hasFoosball = value;
                });
              }),
              _buildFeatureSwitch("Erkek Tuvaleti Var", hasMaleToilet, (value) {
                setState(() {
                  hasMaleToilet = value;
                });
              }),
              _buildFeatureSwitch("Kadın Tuvaleti Var", hasFemaleToilet,
                  (value) {
                setState(() {
                  hasFemaleToilet = value;
                });
              }),
              _buildFeatureSwitch("Kredi Kartı Geçerli", acceptsCreditCard,
                  (value) {
                setState(() {
                  acceptsCreditCard = value;
                });
              }),
              _buildFeatureSwitch("Kiralık Kaleci Var", hasGoalkeeper, (value) {
                setState(() {
                  hasGoalkeeper = value;
                });
              }),
              _buildFeatureSwitch("Çocuk Oyun Alanı Var", hasPlayground,
                  (value) {
                setState(() {
                  hasPlayground = value;
                });
              }),
              _buildFeatureSwitch("Mescit Var", hasPrayerRoom, (value) {
                setState(() {
                  hasPrayerRoom = value;
                });
              }),
              _buildFeatureSwitch("İnternet Var", hasInternet, (value) {
                setState(() {
                  hasInternet = value;
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
                      ? ProgressiveImage(
                          imageUrl: currentHaliSaha.imagesUrl.first,
                          fit: BoxFit.cover,
                        )
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

  String? _timeValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // boş bırakmaya izin (opsiyonel)
    final reg = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$'); // HH:MM
    if (!reg.hasMatch(v.trim())) return "Geçerli saat biçimi: 20:00";
    return null;
  }

  // 12 -> 12:  123 -> 12:3  1234 -> 12:34  (sadece sayı ve :)
  TextInputFormatter get _hhmmMask => TextInputFormatter.withFunction(
        (oldValue, newValue) {
      // 🔹 Sadece rakamlar ve ':' izinli
      var t = newValue.text.replaceAll(RegExp(r'[^0-9:]'), '');

      // 🔹 Fazla ':' varsa ilkini bırak diğerlerini sil
      if (':'.allMatches(t).length > 1) {
        final firstColon = t.indexOf(':');
        t = t.substring(0, firstColon + 1) +
            t.substring(firstColon + 1).replaceAll(':', '');
      }

      // 🔹 ':' yoksa ve 3–4 karakter girilmişse otomatik yerleştir
      if (!t.contains(':') && t.length > 2) {
        t = '${t.substring(0, 2)}:${t.substring(2)}';
      }

      // 🔹 Toplam uzunluk en fazla 5 karakter (HH:MM)
      if (t.length > 5) t = t.substring(0, 5);

      return TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    },
  );


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
      activeThumbColor: Colors.green.shade600,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isMultiline = false,
    int maxLength = 500,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        // ⬅️ DEĞİŞTİ
        inputFormatters: inputFormatters,
        controller: controller,
        keyboardType: isNumber
            ? TextInputType.number
            : (isMultiline ? TextInputType.multiline : TextInputType.text),
        maxLines: isMultiline ? 4 : 1,
        maxLength: maxLength,
        validator: validator,
        // ⬅️ Artık çalışır
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
    showLoader(context);
    print("Güncelleme işlemi başlatıldı.");

    final rawInput = phoneController.text.trim();
    final newPhone = '+90${toNumericString(rawInput)}';
    final oldPhone = currentHaliSaha.phone;

    print('📞 Old Phone: $oldPhone');
    print('📞 New Phone: $newPhone');

    // Giriş doğrulama
    String? validationError = _validateInputs();
    if (validationError != null) {
      print("Doğrulama hatası: $validationError");
      AppSnackBar.error(context, validationError);
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
      final lat = double.tryParse(latController.text.replaceAll(',', '.'));
      final lng = double.tryParse(lngController.text.replaceAll(',', '.'));
      print("Fiyat: $price, Maksimum Oyuncu: $maxPlayers");

      // Güncellenmiş Halı Saha nesnesi oluşturma
      HaliSaha updatedSaha = currentHaliSaha.copyWith(
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        price: price,
        phone: newPhone,
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
        hasCameras: hasCameras,
        hasFemaleToilet: hasFemaleToilet,
        hasFoodService: hasFoodService,
        hasFoosball: hasFoosball,
        hasGoalkeeper: hasGoalkeeper,
        hasInternet: hasInternet,
        hasMaleToilet: hasMaleToilet,
        hasPlayground: hasPlayground,
        hasPrayerRoom: hasPrayerRoom,
        acceptsCreditCard: acceptsCreditCard,
        longitude: lng,
        latitude: lat,
      );
      print(
          "Güncellenmiş Halı Saha nesnesi oluşturuldu: ${updatedSaha.toJson()}");

      // Değiştirilen alanları belirleme
      Map<String, dynamic> updateData =
          _getChangedFields(currentHaliSaha, updatedSaha);
      if (updateData.isEmpty) {
        AppSnackBar.show(context, 'Değişiklik yapmadınız.');
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
      AppSnackBar.success(context, 'Halı Saha başarıyla güncellendi.');
      print("Başarı mesajı gösterildi.");
    } catch (e, stack) {
      // Hata durumunda kullanıcıya bildirim
      print("Güncelleme sırasında bir hata oluştu: $e");
      print(stack);
      if (mounted) {
        AppSnackBar.error(context,
            'Güncelleme sırasında bir hata oluştu. Lütfen tekrar deneyin.');
      }
    } finally {
      hideLoader();
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
    if (oldSaha.hasMaleToilet != newSaha.hasMaleToilet)
      changedFields['hasMaleToilet'] = newSaha.hasMaleToilet;
    if (oldSaha.hasFemaleToilet != newSaha.hasFemaleToilet)
      changedFields['hasFemaleToilet'] = newSaha.hasFemaleToilet;
    if (oldSaha.hasFoodService != newSaha.hasFoodService)
      changedFields['hasFoodService'] = newSaha.hasFoodService;
    if (oldSaha.acceptsCreditCard != newSaha.acceptsCreditCard)
      changedFields['acceptsCreditCard'] = newSaha.acceptsCreditCard;
    if (oldSaha.hasFoosball != newSaha.hasFoosball)
      changedFields['hasFoosball'] = newSaha.hasFoosball;
    if (oldSaha.hasCameras != newSaha.hasCameras)
      changedFields['hasCameras'] = newSaha.hasCameras;
    if (oldSaha.hasGoalkeeper != newSaha.hasGoalkeeper)
      changedFields['hasGoalkeeper'] = newSaha.hasGoalkeeper;
    if (oldSaha.hasPlayground != newSaha.hasPlayground)
      changedFields['hasPlayground'] = newSaha.hasPlayground;
    if (oldSaha.hasPrayerRoom != newSaha.hasPrayerRoom)
      changedFields['hasPrayerRoom'] = newSaha.hasPrayerRoom;
    if (oldSaha.hasInternet != newSaha.hasInternet)
      changedFields['hasInternet'] = newSaha.hasInternet;

    if (oldSaha.phone != newSaha.phone) changedFields['phone'] = newSaha.phone;
    if (oldSaha.longitude != newSaha.longitude)
      changedFields['longitude'] = newSaha.longitude;
    if (oldSaha.latitude != newSaha.latitude)
      changedFields['latitude'] = newSaha.latitude;

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
    if (phoneController.text.trim().isEmpty) {
      return "İletişim Telefon Numarası boş olamaz.";
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
    if (lngController.text.trim().isEmpty) {
      return "Boylam boş olamaz.";
    }
    if (latController.text.trim().isEmpty) {
      return "Enlem boş olamaz.";
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
      AppSnackBar.warning(context,
          "Şu an için sadece ${DateFormat.yMMMd('tr_TR').format(today)} - ${DateFormat.yMMMd('tr_TR').format(bookingWindowEnd)} arası rezervasyon yapılabilir.");
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
    final allSlots = generateTimeSlotsForDate(
      date: selectedDate,                      // o gün
      useOverrides: _useOverrides,             // sahaya özel saatler
      overrides: _overrides,
      defaultStart: widget.haliSaha.startHour,
      defaultEnd: widget.haliSaha.endHour,
      durationMinutes: 60,                     // değişkense modelden çek
    )..sort();                                  // saatleri sıralı göster

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          columnWidths: const {
            0: FixedColumnWidth(120),
            1: FixedColumnWidth(120),
            2: FlexColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.green.shade100),
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
              final time = slot;

              // Statü belirleme
              final reserved              = isReserved(time);
              final pending               = hasPendingRequest(time);
              final completed             = isCompleted(time);                // içeride _formatSlotWithDate kullan
              final subscriptionReserved  = isSubscriptionReserved(time);
              final isPastTimeToday       = _isPastForSelectedDay(time);

              IconData statusIcon;
              Color statusColor;
              String statusText;

              if (completed) {
                statusIcon  = Icons.check_circle_outline;
                statusColor = Colors.blue;
                statusText  = "Tamamlandı";
              } else if (subscriptionReserved) {
                statusIcon  = Icons.check_circle;
                statusColor = AppColors.secondary;
                statusText  = "Abone";
              } else if (reserved) {
                statusIcon  = Icons.check_circle;
                statusColor = AppColors.primary;
                statusText  = "Rezerve";
              } else if (pending) {
                statusIcon  = Icons.priority_high;
                statusColor = Colors.orange;
                statusText  = "İstek Var";
              } else if (isPastTimeToday) {
                statusIcon  = Icons.history;
                statusColor = Colors.grey;
                statusText  = "Geçti";
              } else {
                statusIcon  = Icons.circle;
                statusColor = Colors.grey;
                statusText  = "Müsait";
              }

              return TableRow(
                decoration: const BoxDecoration(color: Colors.white),
                children: [
                  _tableCellText(
                    time,
                    textStyle: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 18),
                          const SizedBox(width: 6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: _buildActionButton(
                        reserved,
                        pending,
                        completed,
                        time,
                        isPastTimeToday,
                      ),
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


  // --- Helpers: dakika hassasiyetli ve cross-midnight destekli ---
  DateTime _slotStartDT(String slot, DateTime day) {
    // slot: "HH:mm-HH:mm"
    final parts = slot.split('-');
    final s = parts[0].split(':');
    final h = int.parse(s[0]);
    final m = int.parse(s[1]);
    return DateTime(day.year, day.month, day.day, h, m);
  }

  DateTime _slotEndDT(String slot, DateTime day) {
    final parts = slot.split('-');
    final e = parts[1].split(':');
    var h = int.parse(e[0]);
    var m = int.parse(e[1]);
    var end = DateTime(day.year, day.month, day.day, h, m);
    final start = _slotStartDT(slot, day);
    if (end.isBefore(start)) {
      // 23:30-00:30 gibi ertesi güne sarmışsa
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  bool _isPastForSelectedDay(String slot) {
    final now = TimeService.now();
    final start = _slotStartDT(slot, selectedDate);
    final end   = _slotEndDT(slot, selectedDate);

    final today = DateTime(now.year, now.month, now.day);
    final sel   = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    if (sel.isBefore(today)) return true;   // dünkü tüm slotlar geçti
    if (sel.isAfter(today))  return false;  // yarınkiler geçmedi
    // bugün: slotun BİTİŞ saatine göre karar ver (09:00-10:00 09:05'te "geçti" olmasın)
    return now.isAfter(end);
  }

  String _formatSlotWithDate(String slot, DateTime day) {
    final start = _slotStartDT(slot, day);
    final end   = _slotEndDT(slot, day);
    final ymd = DateFormat('yyyy-MM-dd').format(day);
    final s = DateFormat('HH:mm').format(start);
    final e = DateFormat('HH:mm').format(end);
    return '$ymd $s-$e'; // DB/karşılaştırma formatı
  }


  bool isTodaySelected() {
    DateTime now = TimeService.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  bool isCompleted(String slot) {
    try {
      final key = _formatSlotWithDate(slot, selectedDate);
      return haliSahaReservations.any((r) =>
      r.reservationDateTime == key && r.status == 'Tamamlandı');
    } catch (_) { return false; }
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
          final input = await showInputDialog(
            context,
            title: 'Rezervasyon Bilgisi',
          );
          if (input == null) return;

          await _makeReservation(
              time: time, name: input.name, phoneNo: input.phone);
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

  bool isSubscriptionReserved(String time) {
    final bookingDateTime =
        "${DateFormat('yyyy-MM-dd').format(selectedDate)} $time";

    return haliSahaReservations.any(
      (reservation) =>
          reservation.reservationDateTime == bookingDateTime &&
          reservation.status == "Onaylandı" &&
          reservation.type ==
              "subscription", // ✅ sadece abonelik rezervasyonları
    );
  }

  void _showReservationDetailDialog(String time) {
    try {
      // Seçili gün + saat dilimi anahtarını oluştur
      final key = '${DateFormat('yyyy-MM-dd').format(selectedDate)} $time';
      final reservation = haliSahaReservations.firstWhere(
        (r) => r.reservationDateTime == key,
      );
      final statsProvider = StatsProvider();
      statsProvider.loadStats(reservation);
      showDialog(
        context: context,
        builder: (context) {
          return ChangeNotifierProvider<StatsProvider>(
            create: (_) {
              final svc = StatsProvider();
              svc.loadStats(reservation);
              return svc;
            },
            child: Builder(
              builder: (ctx) {
                final stats = ctx.watch<StatsProvider>();
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth >= 600;
                      return SafeArea(
                        child: FractionallySizedBox(
                          widthFactor: isTablet ? 0.6 : 0.97,
                          heightFactor: isTablet ? 0.75 : 0.83,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ─── HEADER ─────────────────────────
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.blue.shade400
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info,
                                          color: Colors.white, size: 28),
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

                                // ─── BODY (scrollable) ─────────────────
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Detay öğeleri
                                          _detailItem(
                                              Icons.person,
                                              "Kullanıcı Adı",
                                              reservation.userName),
                                          const SizedBox(height: 8),
                                          phoneDetailItem(Icons.phone,
                                              "Telefon", reservation.userPhone),
                                          const SizedBox(height: 8),
                                          _detailItem(Icons.email, "E-posta",
                                              reservation.userEmail),
                                          const SizedBox(height: 8),
                                          _detailItem(
                                              Icons.calendar_today,
                                              "Tarih ve Saat",
                                              reservation.reservationDateTime),

                                          const SizedBox(height: 12),
                                          const Divider(),
                                          const SizedBox(height: 12),

                                          // ─── Kullanıcı Hareketleri ────────────
                                          const Text(
                                            'Kullanıcı Hareketleri (Son 3 Ay)',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Consumer<StatsProvider>(
                                            builder:
                                                (context, statsProvider, _) {
                                              if (statsProvider.isLoading) {
                                                return const Center(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 24),
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              }

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildStatCard(
                                                      title: 'Bu Sahadaki',
                                                      approved: statsProvider
                                                          .ownApprovedCount,
                                                      cancelled: statsProvider
                                                          .ownCancelledCount,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: _buildStatCard(
                                                      title: 'Tüm Sahalardaki',
                                                      approved: statsProvider
                                                          .allApprovedCount,
                                                      cancelled: statsProvider
                                                          .allCancelledCount,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),

                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const Divider(height: 1),

                                // ─── FOOTER BUTTONS ───────────────────
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(16)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Rezervasyonu İptal Et
                                      Expanded(
                                        child: reservation.type ==
                                                "subscription"
                                            ? SizedBox.shrink()
                                            : ElevatedButton.icon(
                                                onPressed: () {
                                                  _showCancelConfirmation(
                                                      context, reservation);
                                                },
                                                label: Text(
                                                    "Rezervasyonu İptal Et",
                                                    style: AppTextStyles
                                                        .labelMedium
                                                        .copyWith(
                                                            color:
                                                                Colors.white)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 15),
                                                  textStyle: const TextStyle(
                                                      fontSize: 16),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Kapat
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            "Kapat",
                                            style: AppTextStyles.labelMedium
                                                .copyWith(
                                                    color: Colors.grey.shade800,
                                                    fontSize: 15),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Rezervasyon Detayları bulunamadı: $e");
      AppSnackBar.error(context, "Rezervasyon detayları bulunamadı.");
    }
  }

  void _showCancelConfirmation(BuildContext context, Reservation reservation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
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
                        phoneDetailItem(
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
      AppSnackBar.error(context, "Rezervasyon detayları bulunamadı.");
    }
  }

  Widget buildPhoneNumberField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          // Eskiden kullandığın formatter aynen kalsın
          PhoneInputFormatter(
              defaultCountryCode: 'TR', allowEndlessPhone: false),
        ],
        maxLength: 12,
        buildCounter: (context,
            {required currentLength, required isFocused, required maxLength}) {
          if (maxLength == null) return null;
          return Text(
            '$currentLength / $maxLength',
            style: TextStyle(
              fontSize: 11,
              color:
                  currentLength > maxLength ? Colors.red : Colors.grey.shade600,
            ),
          );
        },
        decoration: InputDecoration(
          // +90 kısmı artık silinemez, hep orada sabit durur
          prefixText: '+90 ',
          prefixStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),

          labelText: 'İletişim Telefon Numarası',
          hintText: '5XX XXX XX XX',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  String getDayNameFromNumber(int dayOfWeek) {
    const days = {
      1: "Pazartesi",
      2: "Salı",
      3: "Çarşamba",
      4: "Perşembe",
      5: "Cuma",
      6: "Cumartesi",
      7: "Pazar",
    };
    return days[dayOfWeek] ?? "Gün";
  }

  void _showSubscriptionDialog(
      BuildContext rootCtx, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final userName = data['userName'] ?? 'İsim yok';
    final userPhone = data['userPhone'] ?? 'Telefon yok';
    final userEmail = data['userEmail'] ?? 'Email yok';
    final status = data['status'] ?? 'Durum yok';
    final time = data['time'] ?? '';
    final dayOfWeek = data['dayOfWeek'] ?? 1;

    final displaySlot = "Her ${getDayNameFromNumber(dayOfWeek)} $time";

    showDialog(
      context: rootCtx,
      builder: (dialogCtx) {
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
                          "Abonelik Detayları",
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
                      _detailItem(Icons.person, "Kullanıcı Adı", userName),
                      SizedBox(height: 8),
                      phoneDetailItem(Icons.phone, "Telefon", userPhone),
                      SizedBox(height: 8),
                      _detailItem(Icons.person, "E-Posta", userEmail),
                      SizedBox(height: 12),
                      Divider(),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displaySlot,
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
                              "Durum: $status",
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
                    mainAxisAlignment: status == "Beklemede"
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.spaceEvenly,
                    children: [
                      if (status == "Beklemede") ...[
                        // 🔴 Reddet
                        ElevatedButton.icon(
                          onPressed: () {
                            ownerRejectSubscription(rootCtx, doc.id);
                            Navigator.pop(dialogCtx);
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

                        // ✅ Onayla
                        ElevatedButton.icon(
                          onPressed: () {
                            approveSubscription(rootCtx, doc.id);
                            Navigator.pop(dialogCtx);
                          },
                          icon: Icon(Icons.check, color: Colors.white),
                          label: Text("Onayla",
                              style: TextStyle(color: Colors.white)),
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
                      ] else if (status == "Aktif") ...[
                        // 🔴 Aboneliği iptal et
                        ElevatedButton.icon(
                          onPressed: () {
                            ownerCancelSubscription(rootCtx, doc.id);
                            Navigator.pop(dialogCtx);
                          },
                          icon: Icon(Icons.cancel, color: Colors.white),
                          label: Text("Aboneliği İptal Et",
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

                        // 🔘 Kapat
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text("Kapat"),
                        ),
                      ]
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
            ),
          )
        ],
      ),
    );
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

  Widget phoneDetailItem(IconData icon, String title, String? phone) {
    final displayValue = (phone ?? 'Bilgi yok').trim();
    final bool hasPhone =
        displayValue.isNotEmpty && displayValue != 'Bilgi yok';

    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade700),
        const SizedBox(width: 8),
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
              const SizedBox(height: 2),
              hasPhone
                  ? InkWell(
                      onTap: () => _callNumber(displayValue),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          displayValue,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            // 🔹 tıklanabilir vurgusu
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            // 🔹 altı çizili
                            decorationThickness: 1.3,
                            decorationColor: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      displayValue,
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

  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("❌ Arama başlatılamadı: $phone");
    }
  }

  void _showReservationDialog(String time) {
    // 1️⃣ Rezervasyonu bul
    final key = '${DateFormat('yyyy-MM-dd').format(selectedDate)} $time';
    final reservation = haliSahaReservations.firstWhere(
      (r) => r.reservationDateTime == key && r.status == 'Beklemede',
    );

    // 2️⃣ Dialog’u, StatsProvider ile sarmala ve hemen yüklemeye başla
    showDialog(
      context: context,
      builder: (context) {
        return ChangeNotifierProvider<StatsProvider>(
          create: (_) {
            final svc = StatsProvider();
            svc.loadStats(reservation);
            return svc;
          },
          child: Builder(
            builder: (ctx) {
              // 3️⃣ Burada provider’ı dinle
              final stats = ctx.watch<StatsProvider>();

              return Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SafeArea(
                  child: FractionallySizedBox(
                    widthFactor:
                        MediaQuery.of(context).size.width >= 600 ? 0.6 : 0.97,
                    heightFactor:
                        MediaQuery.of(context).size.width >= 600 ? 0.75 : 0.83,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ─── HEADER ─────────────────────────
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.blue.shade400
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                const Icon(Icons.info,
                                    color: Colors.white, size: 28),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Rezervasyon Detayları",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Ionicons.close_outline,
                                      size: 26, color: Colors.white),
                                ),
                              ],
                            ),
                          ),

                          // ─── BODY (scrollable) ─────────────────
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Detay satırları
                                  _detailItem(Icons.person, "Kullanıcı Adı",
                                      reservation.userName),
                                  const SizedBox(height: 8),
                                  phoneDetailItem(Icons.phone, "Telefon",
                                      reservation.userPhone),
                                  const SizedBox(height: 8),
                                  _detailItem(Icons.email, "E-posta",
                                      reservation.userEmail),
                                  const SizedBox(height: 8),
                                  _detailItem(
                                      Icons.calendar_today,
                                      "Tarih ve Saat",
                                      reservation.reservationDateTime),

                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),

                                  // Kullanıcı hareketleri başlığı
                                  const Text(
                                    'Kullanıcı Hareketleri (Son 3 Ay)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Consumer<StatsProvider>(
                                    builder: (context, statsProvider, _) {
                                      if (statsProvider.isLoading) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 24),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatCard(
                                              title: 'Bu Sahadaki',
                                              approved: statsProvider
                                                  .ownApprovedCount,
                                              cancelled: statsProvider
                                                  .ownCancelledCount,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatCard(
                                              title: 'Tüm Sahalardaki',
                                              approved: statsProvider
                                                  .allApprovedCount,
                                              cancelled: statsProvider
                                                  .allCancelledCount,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),

                          const Divider(height: 1),

                          // ─── FOOTER BUTTONS ───────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                // Reddet
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _rejectReservation(reservation);
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    label: const Text("Reddet",
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      textStyle: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Onayla
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _approveReservation(reservation);
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.check,
                                        color: Colors.white),
                                    label: const Text("Onayla",
                                        style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      textStyle: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int approved,
    required int cancelled,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _statLine(
                icon: Icons.check_circle,
                color: Colors.green.shade600,
                value: approved,
                label: 'Tamamlanan',
              ),
              const SizedBox(height: 6),
              _statLine(
                icon: Icons.cancel,
                color: Colors.red.shade600,
                value: cancelled,
                label: 'İptal Edilen',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statLine({
    required IconData icon,
    required Color color,
    required int value,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        //  ➜  Sığmazsa yazıları küçült ve overflow’u engelle
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<_SubInput?> showInputDialog(BuildContext context,
      {required String title}) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+90');
    final formKey = GlobalKey<FormState>();

    return showDialog<_SubInput>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header (green→blue gradient) ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF05C46B), Color(0xFF06A4FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Ionicons.person_outline, color: Colors.white),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Lütfen aşağıyı doldur',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ──
            Container(
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(18)),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration('👤  Ad Soyad'),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Ad girin'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(13),
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        ],
                        decoration: _decoration('📞  Telefon (+90…)'),
                        validator: (v) => (v == null || v.length != 13)
                            ? '11 haneli numara'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade600,
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Vazgeç'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              onPressed: () {
                                if (formKey.currentState!.validate()) {
                                  Navigator.pop(
                                    ctx,
                                    _SubInput(
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim(),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Gönder',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ── Input decoration helper ──
  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Future<void> _approveReservation(Reservation reservation) async {
    showLoader(context);
    try {
      await FirebaseFirestore.instance
          .collection("reservations")
          .doc(reservation.id)
          .update({"status": "Onaylandı", 'lastUpdatedBy': 'owner'});
      AppSnackBar.success(context, 'Rezervasyon Onaylandı!');
      debugPrint("Rezervasyon onaylandı.");
    } catch (e) {
      debugPrint("Rezervasyon onaylama hatası: $e");
    } finally {
      hideLoader();
    }
  }

  Future<void> _rejectReservation(Reservation reservation) async {
    showLoader(context);
    try {
      await FirebaseFirestore.instance
          .collection("reservations")
          .doc(reservation.id)
          .set({
        "status": "İptal Edildi",
        'lastUpdatedBy': 'owner',
        'cancelReason': 'owner'
      }, SetOptions(merge: true));
      debugPrint("Rezervasyon reddedildi.");

      final printData = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservation.id)
          .get();
      print(printData.data());
    } catch (e) {
      debugPrint("Rezervasyon reddetme hatası: $e");
      hideLoader();
    }
    cancelReservation(reservation.reservationDateTime);
  }

  Future<void> _makeReservation(
      {required String time,
      required String name,
      required String phoneNo}) async {
    showLoader(context);
    String formattedDate =
        DateFormat('yyyy-MM-dd').format(selectedDate); // örn: "2025-07-28"
    String bookingString =
        "$formattedDate $time"; // örn: "2025-07-28 17:00-18:00"

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
        AppSnackBar.error(
            context, "Slot rezerve edilemedi, lütfen başka bir saat deneyin.");
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

      Reservation reservation = Reservation(
        id: docRef.id,
        userId: _auth.currentUser!.uid,
        haliSahaId: widget.haliSaha.id,
        haliSahaName: widget.haliSaha.name,
        haliSahaLocation: widget.haliSaha.location,
        haliSahaPrice: widget.haliSaha.price,
        reservationDateTime: bookingString,
        startTime: startTime,
        status: "Onaylandı",
        createdAt: TimeService.nowUtc(),
        userName: name,
        userEmail: widget.currentOwner.email,
        userPhone: phoneNo,
        type: "manual",
        lastUpdatedBy: widget.currentOwner.role,
      );

      // Rezervasyonu Firestore'daki "reservations" koleksiyonuna ekle
      await docRef.set(reservation.toMap(), SetOptions(merge: false));

      // Başarılı mesajı göster
      AppSnackBar.success(context, "Saat $time başarıyla rezerve edildi.");
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'reservation');

      AppSnackBar.error(context, "Rezervasyon başarısız: $msg");
    } finally {
      hideLoader();
    }
  }

  Future<void> cancelReservation(String time) async {
    String bookingString = "$time";
    print(bookingString);

    try {
      final success = await ReservationRemoteService().cancelSlot(
        haliSahaId: widget.haliSaha.id,
        bookingString: bookingString,
      );

      if (!success) {
        AppSnackBar.error(
            context, 'Rezervasyon iptal edilemedi lütfen takrar deneyin!');

        return;
      }

// UI'den kaldır
      setState(() {
        widget.haliSaha.bookedSlots.remove(bookingString);
      });

// Başarılı mesaj
      AppSnackBar.success(context, 'Rezervasyon başarıyla iptal edildi.');
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'reservation');

      AppSnackBar.error(context, 'Rezervasyon iptali başarısız!');
    } finally {
      hideLoader();
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

extension HaliSahaCopyWith on HaliSaha {
  HaliSaha copyWith({
    String? name,
    String? location,
    String? phone,
    num? price,
    num? rating,
    String? size,
    String? surface,
    int? maxPlayers,
    String? startHour,
    String? endHour,
    String? description,
    List<String>? imagesUrl,
    List<String>? bookedSlots,
    bool? hasParking,
    bool? hasShowers,
    bool? hasShoeRental,
    bool? hasCafeteria,
    bool? hasNightLighting,
    bool? hasMaleToilet,
    bool? hasFemaleToilet,
    bool? hasFoodService,
    bool? acceptsCreditCard,
    bool? hasFoosball,
    bool? hasCameras,
    bool? hasGoalkeeper,
    bool? hasPlayground,
    bool? hasPrayerRoom,
    bool? hasInternet,
    double? latitude,
    double? longitude,
  }) {
    return HaliSaha(
      ownerId: ownerId,
      name: name ?? this.name,
      location: location ?? this.location,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      imagesUrl: imagesUrl ?? this.imagesUrl,
      bookedSlots: bookedSlots ?? this.bookedSlots,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      id: id,
      hasParking: hasParking ?? this.hasParking,
      hasShowers: hasShowers ?? this.hasShowers,
      hasShoeRental: hasShoeRental ?? this.hasShoeRental,
      hasCafeteria: hasCafeteria ?? this.hasCafeteria,
      hasNightLighting: hasNightLighting ?? this.hasNightLighting,
      hasMaleToilet: hasMaleToilet ?? this.hasMaleToilet,
      hasFemaleToilet: hasFemaleToilet ?? this.hasFemaleToilet,
      hasFoodService: hasFoodService ?? this.hasFoodService,
      acceptsCreditCard: acceptsCreditCard ?? this.acceptsCreditCard,
      hasFoosball: hasFoosball ?? this.hasFoosball,
      hasCameras: hasCameras ?? this.hasCameras,
      hasGoalkeeper: hasGoalkeeper ?? this.hasGoalkeeper,
      hasPlayground: hasPlayground ?? this.hasPlayground,
      hasPrayerRoom: hasPrayerRoom ?? this.hasPrayerRoom,
      hasInternet: hasInternet ?? this.hasInternet,
      description: description ?? this.description,
      size: size ?? this.size,
      surface: surface ?? this.surface,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

/// Geri dönen model
class _SubInput {
  _SubInput({required this.name, required this.phone});

  final String name;
  final String phone;
}
