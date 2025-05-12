import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/data/entitiy/reservation.dart';

class UserReservationDetailPage extends StatefulWidget {
  final Reservation reservation;

  UserReservationDetailPage({required this.reservation});

  @override
  _UserReservationDetailPageState createState() =>
      _UserReservationDetailPageState();
}

class _UserReservationDetailPageState extends State<UserReservationDetailPage> {
  bool isLoading = false;

  // Duruma göre renk sınıflandırması
  Color getStatusColor(String status) {
    switch (status) {
      case 'Onaylandı':
        return Colors.green.shade100;
      case 'Beklemede':
        return Colors.orange.shade100;
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
        return Colors.orange.shade800;
      case 'Tamamlandı':
        return Colors.blue.shade800;
      case 'İptal Edildi':
        return Colors.red.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Future<void> _showCancelConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Rezervasyonu İptal Et',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Bu rezervasyonu iptal etmek istediğinize emin misiniz?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Vazgeç',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Dialogu kapat
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('İptal Et', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop(); // Dialogu kapat
                _cancelReservation(widget.reservation.id);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelReservation(String reservationId) async {
    if (reservationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rezervasyon kimliği geçersiz."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({'status': 'İptal Edildi','lastUpdatedBy':'user'});
      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(widget.reservation.haliSahaId)
          .update({
        'bookedSlots':
            FieldValue.arrayRemove([widget.reservation.reservationDateTime])
      });
      ;

      setState(() {
        widget.reservation.status = 'İptal Edildi';
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rezervasyon başarıyla iptal edildi."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Güncelleme sırasında bir hata oluştu: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime reservationDateTime =
        DateTime.parse(widget.reservation.reservationDateTime);
    String formattedDate =
        "${reservationDateTime.day}/${reservationDateTime.month}/${reservationDateTime.year}";
    String formattedTime =
        "${reservationDateTime.hour.toString().padLeft(2, '0')}:${reservationDateTime.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          '${widget.reservation.haliSahaName} Rezervasyonu',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              "assets/halisaha_images/${widget.reservation.haliSahaName.isNotEmpty ? 'halisaha1.jpg' : 'halisaha0.jpg'}",
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.reservation.haliSahaName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                SizedBox(height: 10),
                                _buildInfoRow(
                                    Icons.calendar_today, formattedDate),
                                _buildInfoRow(Icons.access_time, formattedTime),
                                _buildInfoRow(Icons.attach_money,
                                    "${widget.reservation.haliSahaPrice} TL/saat"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Kullanıcı Bilgileri",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Divider(
                        thickness: 1.5,
                        color: Colors.green.shade700,
                      ),
                      SizedBox(height: 15),
                      _buildInfoRow(Icons.person, widget.reservation.userName),
                      _buildInfoRow(Icons.email, widget.reservation.userEmail),
                      _buildInfoRow(Icons.phone, widget.reservation.userPhone),
                    ],
                  ),
                ),
                SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: getStatusColor(widget.reservation.status),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: getStatusTextColor(widget.reservation.status),
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.reservation.status,
                        style: TextStyle(
                          color: getStatusTextColor(widget.reservation.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 35),
                if (widget.reservation.status == 'Onaylandı' ||
                    widget.reservation.status == 'Beklemede')
                  Center(
                    child: ElevatedButton(
                      onPressed: _showCancelConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        "Rezervasyonu İptal Et",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
