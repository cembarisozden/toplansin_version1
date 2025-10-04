import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/reservation_remote_service.dart';
import 'package:toplansin/ui/owner_views/owner_halisaha_page.dart';
import 'package:toplansin/ui/user_views/dialogs/show_styled_confirm_dialog.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';

class UserReservationDetailPage extends StatefulWidget {
  final Reservation reservation;

  UserReservationDetailPage({required this.reservation});

  @override
  _UserReservationDetailPageState createState() =>
      _UserReservationDetailPageState();
}


class _UserReservationDetailPageState extends State<UserReservationDetailPage> {
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
    final ok = await ShowStyledConfirmDialog.show(
      context,
      title: "Rezervasyonu İptal Et",
      message:
      "Bu rezervasyonu iptal etmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
      confirmText: "İptal Et",
      cancelText: "Vazgeç",
      isDestructive: true,
      // kırmızı tema
      icon: Icons.event_busy_rounded,
    );

    if (ok == true) {
      await _cancelReservation(widget.reservation.id);
    }
  }

  Future<void> _cancelReservation(String reservationId) async {
    showLoader(context);
    if (reservationId.isEmpty) {
      hideLoader();
      AppSnackBar.error(context, "Rezervasyon kimliği geçersiz.");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .set({
        'status': 'İptal Edildi',
        'lastUpdatedBy': 'user',
        'cancelReason': 'user'
      }, SetOptions(merge: true));

      final success = await ReservationRemoteService().cancelSlot(
        haliSahaId: widget.reservation.haliSahaId,
        bookingString: widget.reservation.reservationDateTime,
      );

      if (!success) {
        AppSnackBar.error(
            context, "Slot iptal edilemedi, lütfen tekrar deneyin.");
        return;
      }

      setState(() {
        widget.reservation.status = 'İptal Edildi';
      });

      AppSnackBar.success(context, "Rezervasyon başarıyla iptal edildi.");
    } catch (e) {
      setState(() {});

      final errorMsg = AppErrorHandler.getMessage(e, context: 'reservation');

      AppSnackBar.error(context, "İptal işlemi başarısız: $errorMsg");
    } finally {
      hideLoader();
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

  void _onTap() async {
    showLoader(context);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final docUser = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!docUser.exists) {
        AppSnackBar.error(context, "Kullanıcı bulunamadı!");
        return;
      }

      final currentUser = Person.fromMap(docUser.data()!);

      final snapshot = await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(widget.reservation.haliSahaId)
          .get();

      if (!snapshot.exists) {
        AppSnackBar.warning(context, "Saha bulunamadı");
        return;
      }

      final haliSaha = HaliSaha.fromJson(snapshot.data()!, snapshot.id);
      if (currentUser.role == 'user') {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) =>
                HaliSahaDetailPage(
                  haliSaha: haliSaha,
                  currentUser: currentUser,
                ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: Duration(milliseconds: 300),
          ),
        );
      } else {
        Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (_, animation, __) =>
                  OwnerHalisahaPage(
                      haliSaha: haliSaha, currentOwner: currentUser),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: Duration(milliseconds: 300),
            ),
                (route) => route.isFirst);
      }
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    } finally {
      hideLoader();
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.reservation.reservationDateTime.split(' ');
    final datePart = parts[0];
    final timePart = parts.length > 1 ? parts[1] : "00:00-01:00";

    final dateParts = datePart.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    final formattedTime = timePart;
    final formattedDate = "$day/$month/$year";
    final String defaultImageUrl =
        "https://firebasestorage.googleapis.com/your-default-url/halisaha0.jpg";


    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.reservation.haliSahaName} Rezervasyonu',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_ios_new_outlined)),
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
                Column(
                  children: [
                    GestureDetector(
                      onTap: _onTap,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('hali_sahalar')
                                  .doc(widget.reservation.haliSahaId)
                                  .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Container(
                                    width: double.infinity,
                                    height: 180,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }

                                if (snapshot.hasError || !snapshot.hasData) {
                                  return Container(
                                    width: double.infinity,
                                    height: 180,
                                    color: Colors.grey.shade300,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.broken_image,
                                        color: Colors.grey.shade600, size: 40),
                                  );
                                }

                                final data = snapshot.data!.data()
                                as Map<String, dynamic>?;
                                final List images = data?['imagesUrl'] ?? [];
                                final String imageUrl = images.isNotEmpty
                                    ? images.first
                                    : defaultImageUrl;

                                return SizedBox(
                                  width: double.infinity,
                                  // dışarıdan gelen genişlik korunur
                                  height: 180,
                                  // eski sabit yükseklik
                                  child: ProgressiveImage(
                                    imageUrl: imageUrl.isNotEmpty
                                        ? imageUrl
                                        : null, // yerel yedek görsel
                                    fit: BoxFit.cover,
                                    borderRadius: 0, // yuvarlama yok
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(12)),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black54,
                                    Colors.black87
                                  ], // daha koyu gradient
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, right: 16.0),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sahayı incele',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black54,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios_outlined,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

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

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.reservation.type == "subscription"
                          ? Color(0xFFE6F0FA)
                          : getStatusColor(widget.reservation.status)
                          .withOpacity(0.15),
                      border: Border.all(
                        color: widget.reservation.type == "subscription"
                            ? AppColors.secondaryDark
                            : getStatusTextColor(widget.reservation.status),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.reservation.type == "subscription"
                          ? "Abonelik"
                          : widget.reservation.status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: widget.reservation.type == "subscription"
                            ? AppColors.secondaryDark
                            : getStatusTextColor(widget.reservation.status),
                      ),
                    ),
                  ),
                ),


                if (widget.reservation.type == "subscription" &&
                    widget.reservation.status != 'Beklemede' &&
                    widget.reservation.status != 'Onaylandı') ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (widget.reservation.status == 'Tamamlandı'
                            ? AppColors.secondary
                            : AppColors.danger)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (widget.reservation.status == 'Tamamlandı'
                              ? AppColors.secondary
                              : AppColors.danger)
                              .withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.reservation.status == 'Tamamlandı'
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 16,
                            color: widget.reservation.status == 'Tamamlandı'
                                ? AppColors.secondary
                                : AppColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.reservation.status,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: widget.reservation.status == 'Tamamlandı'
                                  ? AppColors.secondary
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]
                else
                  SizedBox.shrink(),

                const SizedBox(height: 15),


                if (widget.reservation.type != "subscription" &&
                    widget.reservation.status == 'Onaylandı' ||
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
                          color: Colors.white,
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
