import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/user_reservation_detail_page.dart';

class UserReservationsPage extends StatefulWidget {
  @override
  _UserReservationsPageState createState() => _UserReservationsPageState();
  final FirebaseAuth _auth = FirebaseAuth.instance;
}

class _UserReservationsPageState extends State<UserReservationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchTerm = '';

  Stream<List<Reservation>> readReservations(String userId) {
    return FirebaseFirestore.instance
        .collection("reservations")
        .where("userId", isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      // Firestore’dan gelen her değişiklikte bu kısım çalışır
      List<Reservation> reservations = [];

      for (var document in snapshot.docs) {
        var reservation = Reservation.fromDocument(document);

        // Tarih ve saat kontrolü
        DateTime? reservationDateTime;
        try {
          var rawDateTime = reservation.reservationDateTime;
          var datePart = rawDateTime.split(' ')[0];
          var timePart = rawDateTime.split(' ')[1].split('-')[0];
          var formattedDateTime = '$datePart $timePart';
          reservationDateTime = DateTime.parse(formattedDateTime);
                } catch (e) {
          debugPrint("Tarih formatı hatası: ${reservation.reservationDateTime}");
        }

        // Status güncellemesi (eğer tarih geçmişse ve status hâlâ Tamamlandı/İptal değilse)
        if (reservationDateTime != null) {
          if (reservationDateTime.isBefore(TimeService.now()) &&
              reservation.status != 'Tamamlandı' &&
              reservation.status != 'İptal Edildi') {
            // Firestore'da status güncellemesi
            await document.reference.update({'status': 'Tamamlandı'});
            // reservation nesnesinin status’unu da yerelde güncelleyebiliriz
            reservation.status = 'Tamamlandı';
          }
        }

        reservations.add(reservation);
      }

      return reservations;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Rezervasyonları filtreleme
  List<Reservation> _filterReservations(List<Reservation> reservations) {
    if (searchTerm.isEmpty) {
      return reservations;
    }
    return reservations.where((reservation) {
      final fieldLower = reservation.haliSahaName.toLowerCase();
      final dateLower = reservation.reservationDateTime.toLowerCase();
      final statusLower = reservation.status.toLowerCase();
      final searchLower = searchTerm.toLowerCase();

      return fieldLower.contains(searchLower) ||
          dateLower.contains(searchLower) ||
          statusLower.contains(searchLower);
    }).toList();
  }

  // Aktif ve Geçmiş rezervasyonları ayırma
  List<Reservation> getActiveReservations(List<Reservation> all) {
    return _filterReservations(all)
        .where((r) => r.status == 'Onaylandı' || r.status == 'Beklemede')
        .toList();
  }

  List<Reservation> getPastReservations(List<Reservation> all) {
    return _filterReservations(all)
        .where((r) => r.status == 'Tamamlandı' || r.status == 'İptal Edildi')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200
        ? 4
        : screenWidth > 800
        ? 3
        : screenWidth > 600
        ? 2
        : 1;
    double childAspectRatio = 3 / 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0f7fa), Color(0xFFb2ebf2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 15),
            // Başlık ve Geri Dön Butonu
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.green.shade800),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    'Rezervasyonlarım',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 48),
              ],
            ),
            SizedBox(height: 20),
            // Arama Çubuğu
            TextField(
              decoration: InputDecoration(
                hintText: 'Rezervasyon ara...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchTerm = value;
                });
              },
            ),
            SizedBox(height: 20),
            // Sekmeler
            TabBar(
              controller: _tabController,
              labelColor: Colors.green.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.green.shade800,
              tabs: [
                Tab(text: 'Aktif Rezervasyonlar'),
                Tab(text: 'Geçmiş Rezervasyonlar'),
              ],
            ),
            SizedBox(height: 10),

            // ---- 2) STREAMBUILDER ile veriyi canlı dinliyoruz ----
            Expanded(
              child: StreamBuilder<List<Reservation>>(
                stream: readReservations(widget._auth.currentUser!.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Bir hata oluştu: ${snapshot.error}',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  // Tüm rezervasyonlar
                  final allReservations = snapshot.data!;
                  // Filtrelenmiş listeler
                  final activeReservations = getActiveReservations(allReservations);
                  final pastReservations = getPastReservations(allReservations);

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // Aktif Rezervasyonlar
                      activeReservations.isNotEmpty
                          ? GridView.builder(
                        padding: EdgeInsets.all(8),
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: activeReservations.length,
                        itemBuilder: (context, index) {
                          final reservation = activeReservations[index];
                          return ReservationCard(reservation: reservation);
                        },
                      )
                          : Center(
                        child: Text(
                          'Aktif rezervasyonunuz yok.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Geçmiş Rezervasyonlar
                      pastReservations.isNotEmpty
                          ? GridView.builder(
                        padding: EdgeInsets.all(8),
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: pastReservations.length,
                        itemBuilder: (context, index) {
                          final reservation = pastReservations[index];
                          return ReservationCard(reservation: reservation);
                        },
                      )
                          : Center(
                        child: Text(
                          'Geçmiş rezervasyonunuz yok.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
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
    );
  }
}

class ReservationCard extends StatelessWidget {
  final Reservation reservation;

  ReservationCard({required this.reservation});

  Color getStatusColor(String status) {
    switch (status) {
      case 'Onaylandı':
        return Colors.green.shade100;
      case 'Beklemede':
        return Colors.yellow.shade100;
      case 'Tamamlandı':
        return Colors.blue.shade100;
      case 'İptal Edildi':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color getStatusTextColor(String status) {
    switch (status) {
      case 'Onaylandı':
        return Colors.green.shade800;
      case 'Beklemede':
        return Colors.yellow.shade800;
      case 'Tamamlandı':
        return Colors.blue.shade800;
      case 'İptal Edildi':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tarih ve saat ayrıştırma
    List<String> dateTimeParts = reservation.reservationDateTime.split(' ');
    String date = dateTimeParts.isNotEmpty ? dateTimeParts[0] : 'Tarih Yok';
    String time = dateTimeParts.length > 1 ? dateTimeParts[1] : 'Saat Yok';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              reservation.haliSahaName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Card Content
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarih
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey.shade600, size: 16),
                    SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                // Saat
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey.shade600, size: 16),
                    SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                // Lokasyon
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.grey.shade600, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reservation.haliSahaLocation,
                        style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                // Fiyat
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        color: Colors.grey.shade600, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '${reservation.haliSahaPrice} TL/saat',
                      style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Card Footer
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Durum
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(reservation.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: getStatusTextColor(reservation.status),
                    ),
                  ),
                  child: Text(
                    reservation.status,
                    style: TextStyle(
                      color: getStatusTextColor(reservation.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Buton
                ElevatedButton(
                  onPressed: () {
                    // Detay sayfasına yönlendirme
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserReservationDetailPage(reservation: reservation),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    reservation.status == 'Tamamlandı' ||
                        reservation.status == 'İptal Edildi'
                        ? Colors.blue
                        : Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    reservation.status == 'Tamamlandı' ||
                        reservation.status == 'İptal Edildi'
                        ? 'Detaylar'
                        : 'Düzenle',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
