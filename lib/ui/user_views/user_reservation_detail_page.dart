import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/reservation_remote_service.dart';

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

      final success = await ReservationRemoteService().cancelSlot(
        haliSahaId: widget.reservation.haliSahaId,
        bookingString: widget.reservation.reservationDateTime,
      );

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Slot iptal edilemedi, lütfen tekrar deneyin."),
            backgroundColor: Colors.red,
          ),
        );
        return; // iptal başarısızsa durdur
      }


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
    final parts = widget.reservation.reservationDateTime.split(' '); // ["2025-05-15", "20:00-21:00"]
    final datePart = parts[0]; // "2025-05-15"
    final timePart = parts.length > 1 ? parts[1] : "00:00-01:00";

    final dateParts = datePart.split('-'); // ["2025", "05", "15"]
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

// Saat aralığını doğrudan göster
    final formattedTime = timePart; // "20:00-21:00"
    final formattedDate = "$day/$month/$year";


    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.reservation.haliSahaName} Rezervasyonu',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade800,
        centerTitle: true,
        elevation: 4,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 Üst Görsel Kart
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    "assets/halisaha_images/${widget.reservation.haliSahaName.isNotEmpty ? 'halisaha1.jpg' : 'halisaha0.jpg'}",
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),

                // 🗓️ Rezervasyon Bilgileri Kartı
                _buildCard(
                  children: [
                    _buildDetailTitle("Rezervasyon Bilgileri"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.calendar_month, formattedDate),
                    _buildInfoRow(Icons.access_time, formattedTime),
                    _buildInfoRow(Icons.attach_money,
                        "${widget.reservation.haliSahaPrice} TL/Saat"),
                  ],
                ),
                const SizedBox(height: 20),

                // 👤 Kullanıcı Bilgileri
                _buildCard(
                  children: [
                    _buildDetailTitle("Kullanıcı Bilgileri"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.person, widget.reservation.userName),
                    _buildInfoRow(Icons.email, widget.reservation.userEmail),
                    _buildInfoRow(Icons.phone, widget.reservation.userPhone),
                  ],
                ),
                const SizedBox(height: 20),

                // 🔖 Durum Bilgisi
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: getStatusColor(widget.reservation.status)
                          .withOpacity(0.15),
                      border: Border.all(
                        color: getStatusTextColor(widget.reservation.status),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.reservation.status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: getStatusTextColor(widget.reservation.status),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ❌ İptal Butonu
                if (widget.reservation.status == 'Onaylandı' ||
                    widget.reservation.status == 'Beklemede')
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _showCancelConfirmationDialog,
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text(
                        "Rezervasyonu İptal Et",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.green.shade700,
      ),
    );
  }

}
