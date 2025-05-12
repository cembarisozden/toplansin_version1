import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/ui/user_views/user_reservation_detail_page.dart';

class OwnerCompletedReservationsPage extends StatefulWidget {
  final String haliSahaId;
  OwnerCompletedReservationsPage({required this.haliSahaId});

  @override
  _OwnerCompletedReservationsPageState createState() =>
      _OwnerCompletedReservationsPageState();
}

class _OwnerCompletedReservationsPageState
    extends State<OwnerCompletedReservationsPage> {
  String searchTerm = '';
  List<Reservation> mockReservations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    readCompletedReservations(widget.haliSahaId);
  }

  Future<void> readCompletedReservations(String haliSahaId) async {
    try {
      // "Tamamlandı" statüsündeki rezervasyonları haliSahaId bazında çek
      var collectionReservations = FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .where("status", isEqualTo: "Tamamlandı");

      var value = await collectionReservations.get();
      var documents = value.docs;

      List<Reservation> reservations = [];
      for (var document in documents) {
        var reservation = Reservation.fromDocument(document);

        reservations.add(reservation);
      }

      // Rezervasyonları tarih-saat'e göre sıralayalım
      reservations.sort((a, b) {
        DateTime? dateA = _parseReservationDateTime(a.reservationDateTime);
        DateTime? dateB = _parseReservationDateTime(b.reservationDateTime);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });

      setState(() {
        mockReservations = reservations;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Rezervasyonları okurken hata oluştu: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime? _parseReservationDateTime(String? rawDateTime) {
    if (rawDateTime == null) return null;
    try {
      // Ör: "2024-12-18 17:00-18:00"
      var datePart = rawDateTime.split(' ')[0]; // "2024-12-18"
      var timePart = rawDateTime.split(' ')[1].split('-')[0]; // "17:00"
      var formattedDateTime = '$datePart $timePart'; // "2024-12-18 17:00"
      return DateTime.parse(formattedDateTime);
    } catch (e) {
      debugPrint("Tarih formatı hatası: $rawDateTime");
      return null;
    }
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

    var filteredReservations = _filterReservations(mockReservations);

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
                    'Tamamlanmış Rezervasyonlar',
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
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredReservations.isNotEmpty
                  ? GridView.builder(
                padding: EdgeInsets.all(8),
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredReservations.length,
                itemBuilder: (context, index) {
                  final reservation = filteredReservations[index];
                  return ReservationCard(reservation: reservation);
                },
              )
                  : Center(
                child: Text(
                  'Tamamlanmış rezervasyon bulunamadı.',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 16),
                ),
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
    List<String> dateTimeParts = reservation.reservationDateTime.split(' ');
    String date = dateTimeParts.isNotEmpty ? dateTimeParts[0] : 'Tarih Yok';
    String time = dateTimeParts.length > 1 ? dateTimeParts[1] : 'Saat Yok';

    // Kullanıcı iletişim bilgisi
    String userContact = reservation.userPhone ?? "İletişim yok";
    // Kullanıcı ismi
    String userName = reservation.userName ?? "İsim yok";

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Halı Saha adı
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
          // Kullanıcı İletişim Bilgisi - Ön Planda
          Padding(
            padding: EdgeInsets.only(top: 10, left: 12, right: 12),
            child: Row(
              children: [
                Icon(Icons.phone, color: Colors.green.shade700, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userContact,
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Kullanıcı İsmi
          Padding(
            padding: EdgeInsets.only(top: 8, left: 12, right: 12),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.grey.shade700, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    userName,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tarih ve Saat
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey.shade600, size: 16),
                    SizedBox(width: 6),
                    Text(
                      date,
                      style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        color: Colors.grey.shade600, size: 16),
                    SizedBox(width: 6),
                    Text(
                      time,
                      style:
                      TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Durum ve Buton
          Container(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(reservation.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: getStatusTextColor(reservation.status)),
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
                    backgroundColor: reservation.status == 'Tamamlandı' ||
                        reservation.status == 'İptal Edildi'
                        ? Colors.blue
                        : Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Detaylar',
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
