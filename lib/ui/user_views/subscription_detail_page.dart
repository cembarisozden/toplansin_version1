import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:flutter/services.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:toplansin/services/subscription_service.dart';

class SubscriptionDetailPage extends StatefulWidget {
  final Person currentUser;
  SubscriptionDetailPage({required this.currentUser});
  @override
  _SubscriptionDetailPageState createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Durum çubuğunu şeffaf yap
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ana mavi renk - uygulamanın diğer sayfalarındaki mavi ile uyumlu
    final Color primaryBlue = Color(0xFF1976D2);
    final Color lightBgColor = Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: lightBgColor,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aboneliklerim',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryBlue,
              labelColor: primaryBlue,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                Tab(text: 'Aktif Abonelikler'),
                Tab(text: 'Geçmiş Abonelikler'),
              ],
            ),
          ),

          // İçerik
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subscriptions')
                  .where('userId', isEqualTo: widget.currentUser.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: primaryBlue,
                      strokeWidth: 2,
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;

                final activeSubs = allDocs.where((doc) {
                  final status = doc['status'];
                  return status == 'Aktif' || status == 'Beklemede';
                }).toList();
;
                return TabBarView(
                  controller: _tabController,
                  children: [
                    activeSubs.isEmpty
                        ? _buildEmptyState(
                        'Aktif aboneliğiniz bulunmamaktadır.')
                        : ListView.builder(
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.all(16),
                      itemCount: activeSubs.length,
                      itemBuilder: (context, index) {
                        final data = activeSubs[index].data() as Map<String, dynamic>;
                        final sub = Subscription.fromMap(data, activeSubs[index].id);
                        return AbonelikCard(sub: sub);
                      },
                    ),
                    // 🔹 GEÇMİŞ: FutureBuilder ile log'ları bir defa oku
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('subscription_logs')
                          .where('userId', isEqualTo: widget.currentUser.id)
                          .where('newStatus', whereIn: ['Sona Erdi', 'İptal Edildi'])
                          .orderBy('createdAt', descending: true)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator(color: primaryBlue));
                        }

                        final pastLogs = snapshot.data!.docs;
                        if (pastLogs.isEmpty) {
                          return _buildEmptyState('Geçmiş aboneliğiniz bulunmamaktadır.');
                        }

                        return ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: pastLogs.length,
                          itemBuilder: (context, index) {
                            final data = pastLogs[index].data() as Map<String, dynamic>;
                            final sub = Subscription.fromMap(data, pastLogs[index].id);
                            return AbonelikCard(sub: sub);
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AbonelikCard extends StatefulWidget {
  final Subscription sub;
  AbonelikCard({
    super.key,
    required this.sub,
  });
  @override
  State<AbonelikCard> createState() => _AbonelikCardState();
}

class _AbonelikCardState extends State<AbonelikCard> {
  String _convertDayNumberToText(int day) {
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    if (day >= 1 && day <= 7) return 'Her ${days[day - 1]}';
    return 'Bilinmeyen Gün';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aktif':
        return Color(0xFF4CAF50); // Yeşil
      case 'Sona Erdi':
        return Colors.grey.shade600;
      case 'Beklemede':
        return Color(0xFFFFA000); // Amber
      case 'İptal Edildi':
        return Color(0xFFE53935); // Kırmızı
      default:
        return Colors.black;
    }
  }


  @override
  Widget build(BuildContext context) {
    String status = widget.sub.status;
    String title = widget.sub.haliSahaName;
    String day = _convertDayNumberToText(widget.sub.dayOfWeek);
    String time = widget.sub.time;
    num price = widget.sub.price;
    String location = widget.sub.location;
    String nextSession = widget.sub.nextSession;

    final Color statusColor = _statusColor(status);
    final isActive = status == 'Aktif';
    final isPending = status == 'Beklemede';
    final isEnded = status == 'Sona Erdi';
    final Color primaryBlue = Color(0xFF1976D2);
    final Color primaryGreen = Color(0xFF4CAF50);

    // Tüm kart için border radius değeri
    final double cardBorderRadius = 12.0;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
      ),
      clipBehavior: Clip.antiAlias, // İçeriğin köşeleri taşmasını engeller
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık kısmı - gradient ile (rezervasyon sayfasındaki gibi)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, primaryBlue],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // İçerik kısmı - beyaz arka plan
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarih, saat, konum ve fiyat bilgileri
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                Row(
                  children: [
                    Icon(
                      Icons.monetization_on_outlined,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      price.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),

                // Sonraki seans bilgisi - beyaz arka plan
                if (isActive || isEnded) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: primaryBlue,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEnded ? 'Bitiş Tarihi' : 'Sonraki Seans',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              nextSession,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Durum etiketi
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: status == 'Beklemede'
                            ? Color(0xFFFFF8E1) // Amber light
                            : (status == 'Aktif'
                            ? Color(0xFFE8F5E9) // Green light
                            : Color(0xFFEEEEEE)), // Grey light
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Butonlar
                    if (isActive)
                      Row(
                        children: [
                          _buildButton(
                            onPressed: () {},
                            label: 'Bu Haftayı İptal Et',
                            color: Color(0xFFFFA000)
                                .withOpacity(0.8), // Amber daha soft
                          ),
                          SizedBox(width: 8),
                          _buildButton(
                            onPressed: () async {
                              await userCancelSubscription(context,widget.sub.docId);
                            },
                            label: 'Aboneliği İptal Et',
                            color: Color(0xFFE53935)
                                .withOpacity(0.8), // Kırmızı daha soft
                          ),
                        ],
                      )
                    else if (isPending)
                      _buildButton(
                        onPressed: () async {
                          await userAboneIstegiIptalEt(context,widget.sub.docId);
                        },

                        label: 'Abonelik İsteğini İptal Et',
                        color: Color(0xFF5C6BC0)
                            .withOpacity(0.8), // Indigo daha soft
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required String label,
    required Color color,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color, width: 1),
        ),
        minimumSize: Size(0, 32),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}