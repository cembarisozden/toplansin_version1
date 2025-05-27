import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:toplansin/services/subscription_service.dart';
import 'package:toplansin/services/time_service.dart';

class SubscribePage extends StatefulWidget {
  HaliSaha halisaha;
  Person user;
  SubscribePage({required this.halisaha, required this.user});
  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  int selectedDay = 0;
  String? selectedTime;

  final List<Map<String, String>> daysOfWeek = [
    {'short': 'Pzt', 'full': 'Pazartesi'},
    {'short': 'Sal', 'full': 'Salı'},
    {'short': 'Çar', 'full': 'Çarşamba'},
    {'short': 'Per', 'full': 'Perşembe'},
    {'short': 'Cum', 'full': 'Cuma'},
    {'short': 'Cmt', 'full': 'Cumartesi'},
    {'short': 'Paz', 'full': 'Pazar'},
  ];

  final List<Color> gradientColors = [
    Color(0xFF42A5F5),
    Color(0xFF64B5F6),
  ];

  bool get canMakeReservation => selectedTime != null;

  void showSubscriptionConfirmationDialog(BuildContext contextt) {
    final selectedDayText = daysOfWeek[selectedDay]['full'];
    final selectedTimeText = selectedTime!;

    showDialog(
      context: contextt,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Abonelik Onayı',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: _buildConfirmationContent(selectedDayText!, selectedTimeText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => _handleSubscriptionConfirmation(contextt),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationContent(String dayText, String timeText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aşağıdaki gün ve saat için haftalık abonelik oluşturmak üzeresiniz. Onaylıyor musunuz?',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$dayText $timeText',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _hasReachedInstantSubscriptionLimit() async {
    final snap = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('userId', isEqualTo: widget.user.id)
        .where('status', isEqualTo: 'Beklemede')
        .get();
    return snap.size >= 2;
  }

  Future<bool> _hasReachedDailyCancelLimit() async {
    final today = DateFormat('yyyy-MM-dd').format(TimeService.now());
    final start = Timestamp.fromDate(DateTime.parse('$today 00:00:00Z'));
    final end = Timestamp.fromDate(DateTime.parse('$today 23:59:59Z'));

    final snap = await FirebaseFirestore.instance
        .collection('subscription_logs')
        .where('userId', isEqualTo: widget.user.id)
        .where('newStatus', isEqualTo: 'İptal Edildi')
        .where('by', isEqualTo: 'user')
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();

    return snap.size >= 3;
  }

  Future<void> _handleSubscriptionConfirmation(BuildContext context) async {
    Navigator.pop(context); // önce onay dialog’unu kapat

    final selectedDayText = daysOfWeek[selectedDay]['full'];
    final selectedTimeText = selectedTime!;
    final createdAt = TimeService.now();
    final startDate =
        calculateFirstSession(createdAt, selectedDay + 1, selectedTimeText);
    final sub = Subscription(
      docId: '',
      haliSahaId: widget.halisaha.id,
      userId: widget.user.id,
      haliSahaName: widget.halisaha.name,
      location: widget.halisaha.location,
      dayOfWeek: selectedDay + 1,
      time: selectedTimeText,
      price: widget.halisaha.price,
      startDate: startDate,
      endDate: "",
      visibleSession: startDate,
      nextSession: startDate,
      lastUpdatedBy: 'user',
      status: 'Beklemede',
      userName: widget.user.name,
      userEmail: widget.user.email,
      userPhone: widget.user.phone,
    );

    try {

      if (await _hasReachedInstantSubscriptionLimit()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Yeni bir abonelik isteği gönderebilmeniz için önce mevcut isteklerinizin sonuçlanmasını beklemeniz gerekiyor.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (await _hasReachedDailyCancelLimit()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Günlük abonelik iptal sınırı aşıldı. Bugün yeni abonelik isteği gönderemezsiniz.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await aboneOl(context, sub);
      print("userName: ${widget.user.name}");
      print("userPhone: ${widget.user.phone}");
      print("userEmail: ${widget.user.email}");

      await _showSuccessDialog(context, selectedDayText!, selectedTimeText);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abonelik gönderilirken bir hata oluştu.'),
          backgroundColor: Colors.red,
        ),
      );
      print("Abone olma hatası: $e");
    }
  }

  Future<void> _showSuccessDialog(
      BuildContext context, String day, String time) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Abonelik İsteği Gönderildi",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "$day günü, $time saatine yapılan abonelik isteğiniz alınmıştır.\nDurumu 'Aboneliklerim' sayfasından takip edebilirsiniz.",
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        "Tamam",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
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
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      print("🛂 initState → currentUser: ${user?.uid ?? 'null'}");

      if (user != null) {
        // Örneğin readReview() çağrısı varsa burada yap
        // readReview(widget.halisaha.id);
      }
    });

    print("START: ${widget.halisaha.startHour}");
    print("END: ${widget.halisaha.endHour}");
    final now = DateTime(2025, 5, 18); // Cumartesi
    final result =
        calculateFirstSession(now, 1, "20:00-21:00"); // Pazartesi için
    print(result); // Beklenen: 2025-05-20 20:00-21:00

    // TODO: implement initState
  }

  @override
  Widget build(BuildContext context) {
    print("📆 selectedDay: $selectedDay");
    print("🧑‍💻 currentUser: ${FirebaseAuth.instance.currentUser?.uid}");

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Haftalık Abonelik',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    //  Günler kutusu  (overflow-free)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
                        ],
                      ),
                      child: LayoutBuilder(          // 👈 1️⃣  genişliği ölç
                        builder: (context, constraints) {
                          const spacing = 8.0;       // ikonlar arası boşluk
                          final available = constraints.maxWidth - (spacing * 6); // 7 ikon → 6 boşluk
                          final circleSize = available / 7;   // her dairenin yeni genişliği

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: List.generate(daysOfWeek.length, (index) {
                              final isSelected = selectedDay == index;
                              return Padding(
                                padding: EdgeInsets.only(right: index == 6 ? 0 : spacing),
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedDay = index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: circleSize,            // 👈 2️⃣  dinamik boyut
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isSelected
                                          ? LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                          : LinearGradient(
                                        colors: [Colors.grey.shade200, Colors.grey.shade100],
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                        BoxShadow(
                                          color: Colors.blue.shade200,
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        daysOfWeek[index]['short']!,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Saatler kutusu
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.55, // 📱 dinamik yükseklik
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 25,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Müsait Saatler',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('subscriptions')
                                  .where('haliSahaId',
                                      isEqualTo: widget.halisaha.id)
                                  .where('dayOfWeek',
                                      isEqualTo: selectedDay + 1)
                                  .where('status', whereIn: [
                                'Beklemede',
                                'Aktif'
                              ]).snapshots(), // 🔄 Bu bir stream!,
                              builder: (context, snapshot) {
                                print("📢 StreamBuilder tetiklendi:");
                                print(" - hasData: ${snapshot.hasData}");
                                print(" - hasError: ${snapshot.hasError}");
                                print(
                                    " - connectionState: ${snapshot.connectionState}");
                                if (!snapshot.hasData) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                }

                                final blockedTimes = snapshot.data!.docs
                                    .map((doc) => doc['time'])
                                    .toList();
                                print("⏰ Engellenmiş saatler: $blockedTimes");
                                final timeSlots = generateTimeSlots(
                                    widget.halisaha.startHour,
                                    widget.halisaha.endHour);
                                final availableSlots = timeSlots
                                    .where(
                                        (slot) => !blockedTimes.contains(slot))
                                    .toList();

                                return SizedBox(
                                  height: screenHeight * 0.4,
                                  child: GridView.count(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 3.8,
                                    physics: const BouncingScrollPhysics(),
                                    children: availableSlots.map((time) {
                                      final isSelected = selectedTime == time;
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? LinearGradient(
                                                  colors: gradientColors,
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: isSelected
                                              ? null
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.transparent
                                                : Colors.grey.shade300,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.blue.shade200,
                                                    blurRadius: 5,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () => setState(
                                              () => selectedTime = time),
                                          icon: Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.blue.shade700,
                                          ),
                                          label: Text(
                                            time,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.blue.shade700,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (selectedTime != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${daysOfWeek[selectedDay]['full']} günü, $selectedTime saatine abone olacaksınız.',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: canMakeReservation
                            ? () => showSubscriptionConfirmationDialog(context)
                            : null,
                        icon: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Abone Ol',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.blue.shade700,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ));
  }
}
