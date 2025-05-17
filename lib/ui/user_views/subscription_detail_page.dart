import 'package:flutter/material.dart';

class SubscriptionDetailPage extends StatefulWidget {
  @override
  _SubscriptionDetailPageState createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  @override
  Widget build(BuildContext context) {
    final Color themeColor = Colors.blue.shade700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0f7fa), Color(0xFFb2ebf2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              SizedBox(height: 25),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: themeColor),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Text(
                      'Aboneliklerim',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              DefaultTabController(
                length: 2,
                child: Expanded(
                  child: Column(
                    children: [
                      Container(
                        child: TabBar(
                          indicatorColor: themeColor,
                          labelColor: themeColor,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: TextStyle(fontSize: 16),
                          unselectedLabelStyle: TextStyle(fontSize: 14),
                          tabs: const [
                            Tab(text: 'Aktif Abonelikler'),
                            Tab(text: 'Geçmiş Abonelikler'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView(
                              children: [
                                AbonelikCard(
                                  title: 'Karşıyaka Halı Saha',
                                  location: 'Karşıyaka/İzmir',
                                  day: 'Her Çarşamba',
                                  time: '20:00-21:00',
                                  price: '300.0 TL/hafta',
                                  remaining: '8 kalan seans',
                                  nextSession: '22.05.2025 - 20:00-21:00',
                                ),
                                AbonelikCard(
                                  title: 'Göztepe Halısaha',
                                  location: 'Göztepe/İzmir',
                                  day: 'Her Cumartesi',
                                  time: '18:00-19:00',
                                  price: '600.0 TL/hafta',
                                  remaining: '20 kalan seans',
                                  nextSession: '18.05.2025 - 18:00-19:00',
                                ),
                              ],
                            ),
                            ListView(
                              children: [
                                AbonelikCard(
                                  title: 'Bornova Halı Saha',
                                  location: 'Bornova/İzmir',
                                  day: 'Her Pazartesi',
                                  time: '19:00-20:00',
                                  price: '250.0 TL/hafta',
                                  remaining: '12 tamamlanan seans',
                                  nextSession: '28.04.2025',
                                  isPast: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AbonelikCard extends StatelessWidget {
  final String title, location, day, time, price, remaining, nextSession;
  final bool isPast;

  const AbonelikCard({
    super.key,
    required this.title,
    required this.location,
    required this.day,
    required this.time,
    required this.price,
    required this.remaining,
    required this.nextSession,
    this.isPast = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blue.shade700;
    final Color bgBadgeColor = isPast ? Colors.grey : primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Üst görsel alanı gibi mavi bir header + durum etiketi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade700.withOpacity(0.2),
                  Colors.blue.shade300.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sports_soccer, size: 36, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              location,
                              style: TextStyle(
                                  fontSize: 15, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgBadgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPast ? 'Sona Erdi' : 'Aktif',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          /// İçerik bölümü
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    infoBadge(Icons.calendar_today, day, primaryColor),
                    infoBadge(Icons.access_time, time, primaryColor),
                    infoBadge(Icons.monetization_on, price, primaryColor),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event, color: primaryColor),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPast ? 'Bitiş Tarihi' : 'Sonraki Seans',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(nextSession, style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!isPast) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          label: Text(
                            'Bu Haftayı İptal Et',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.orange.shade300, width: 1.5),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.orange.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            shadowColor: Colors.orange.withOpacity(0.2),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          label: Text(
                            'Aboneliği İptal Et',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.red.shade300, width: 1.5),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.red.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            shadowColor: Colors.red.withOpacity(0.2),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}
