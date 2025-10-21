import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:flutter/services.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:toplansin/services/subscription_service.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/dialogs/show_styled_confirm_dialog.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

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
    final Color primaryBlue = AppColors.secondary;
    final Color lightBgColor = Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: lightBgColor,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aboneliklerim',
          style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
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
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: 'Aktif Abonelikler'),
                Tab(text: 'Geçmiş Abonelikler'),
              ],
            ),
          ),

          // İçerik
          Expanded(
            // 🔒 AUTH GUARD: Oturum yoksa aktifler için boş liste döner
            child: StreamBuilder<List<Subscription>>(
              stream: FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
                if (user == null) {
                  return Stream.value(const <Subscription>[]);
                }
                return FirebaseFirestore.instance
                    .collection('subscriptions')
                    .where('userId', isEqualTo: widget.currentUser.id)
                    .where('status', whereIn: const ['Aktif', 'Beklemede'])
                    .snapshots()
                    .map((snap) => snap.docs
                    .map((d) => Subscription.fromMap(
                  d.data(),
                  d.id,
                ))
                    .toList());
              }),
              builder: (context, activeSnap) {
                if (!activeSnap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: primaryBlue,
                      strokeWidth: 2,
                    ),
                  );
                }

                final activeSubs = activeSnap.data!; // oturum yoksa []
                return TabBarView(
                  controller: _tabController,
                  children: [
                    // 🔹 AKTİF/BEKLEMEDE
                    activeSubs.isEmpty
                        ? _buildEmptyState('Aktif aboneliğiniz bulunmamaktadır.')
                        : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: activeSubs.length,
                      itemBuilder: (context, index) {
                        final sub = activeSubs[index];
                        return AbonelikCard(sub: sub);
                      },
                    ),

                    // 🔹 GEÇMİŞ: AUTH GUARD’lı tek seferlik sorgu
                    FutureBuilder<List<Subscription>>(
                      future: () async {
                        if (FirebaseAuth.instance.currentUser == null) {
                          return <Subscription>[];
                        }
                        final qs = await FirebaseFirestore.instance
                            .collection('subscription_logs')
                            .where('userId', isEqualTo: widget.currentUser.id)
                            .where('newStatus',
                            whereIn: const ['Sona Erdi', 'İptal Edildi'])
                            .orderBy('createdAt', descending: true)
                            .get();

                        return qs.docs
                            .map((d) => Subscription.fromMap(
                          d.data(),
                          d.id,
                        ))
                            .toList();
                      }(),
                      builder: (context, pastSnap) {
                        if (!pastSnap.hasData) {
                          return Center(
                            child: CircularProgressIndicator(color: primaryBlue),
                          );
                        }
                        final past = pastSnap.data!;
                        if (past.isEmpty) {
                          return _buildEmptyState(
                              'Geçmiş aboneliğiniz bulunmamaktadır.');
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: past.length,
                          itemBuilder: (context, index) {
                            final sub = past[index];
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
        return Colors.deepOrange; // Amber
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
    String visibleSession = widget.sub.visibleSession;

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
      clipBehavior: Clip.antiAlias,
      // İçeriğin köşeleri taşmasını engeller
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
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight:FontWeight.w600,color: Colors.white),
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
                      "${price.toString()} TL/Saat",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),
                Divider(color: Colors.grey.shade300),

// Kullanıcı bilgileri
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 16, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Text(
                            widget.sub.userName,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 16, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Text(
                            widget.sub.userEmail,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 16, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Text(
                            widget.sub.userPhone,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      if (status == "İptal Edildi") ...[
                        Divider(),
                        SizedBox(height: 8),
                        FutureBuilder<DateTime?>(
                          future: fetchPastSubscriptionsCreatedAt(widget.sub.docId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Text(
                                'İptal Edilme: yükleniyor...',
                                style: TextStyle(color: Colors.grey),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text(
                                'İptal Edilme: tarih bulunamadı',
                                style: TextStyle(color: Colors.red.shade300),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data == null) {
                              return const Text(
                                'İptal Edilme: tarih bulunamadı',
                                style: TextStyle(color: Colors.grey),
                              );
                            }

                            final formatted = TimeService.formatTr(snapshot.data!);
                            return Text(
                              'İptal Edilme: $formatted',
                              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600),
                            );
                          },
                        ),
                      ],

                      if (status == "Sona Erdi") ...[
                        Divider(),
                        SizedBox(height: 8),
                        FutureBuilder<DateTime?>(
                          future: fetchPastSubscriptionsCreatedAt(widget.sub.docId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Text(
                                'Sona Erme: yükleniyor...',
                                style: TextStyle(color: Colors.grey),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data == null) {
                              return const Text(
                                'Sona Erme: tarih bulunamadı',
                                style: TextStyle(color: Colors.grey),
                              );
                            }

                            final formatted = TimeService.formatTr(snapshot.data!);
                            return Row(
                              children: [
                                Text(
                                  'Sona Erme: $formatted',
                                  style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            );
                          },
                        ),
                      ],

                    ],
                  ),
                ),

                // Sonraki seans bilgisi - beyaz arka plan
                if (isActive) ...[
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
                              'Sonraki Seans',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              visibleSession,
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
                    // 🔹 Durum etiketi
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: status == 'Beklemede'
                            ? Color(0xFFFFF8E1)
                            : (status == 'Aktif'
                                ? Color(0xFFE8F5E9)
                                : Color(0xFFEEEEEE)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withOpacity(0.5), width: 1),
                      ),
                      child: Text(
                        status,
                        style: AppTextStyles.bodySmall.copyWith(color: statusColor)
                      ),
                    ),

                    // 🔹 Butonlar
                    if (isActive) ...[
                      Builder(
                        builder: (context) {
                          final now = TimeService.now();
                          final nextDate =_parseVisibleStart(widget.sub.visibleSession);

                          final bool canCancelThisWeek = nextDate != null &&
                              nextDate.isAfter(now) &&
                              nextDate.isBefore(now.add(const Duration(days: 7)));

                          debugPrint("Next date: $nextDate");
                          debugPrint("Now: $now");

                          return Row(
                            children: [
                              if (canCancelThisWeek)
                                TextButton(
                                  onPressed: () async {
                                    final confirm =
                                        await ShowStyledConfirmDialog.show(
                                      context,
                                      title: "Bu Haftaki Seansı İptal Et",
                                      message:
                                          "Bu işlem geri alınamaz. Emin misiniz?",
                                      confirmText: "Evet, İptal Et",
                                    );
                                    if (confirm == true) {
                                      await cancelThisWeekSlot(
                                          widget.sub.docId, context);
                                      setState(() {});
                                    }
                                  },
                                  child: Text('Bu Haftayı İptal Et'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Color(0xFFFFA000),
                                    side: BorderSide(color: Color(0xFFFFA000)),
                                  ),
                                ),
                              if (canCancelThisWeek) SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final confirm = await ShowStyledConfirmDialog.show(
                                    context,
                                    title: "Aboneliği İptal Et",
                                    message:
                                        "Aboneliğiniz tamamen iptal edilecek. Emin misiniz? Bu işlem geri alınamaz.",
                                    confirmText: "Evet, İptal Et",
                                  );
                                  if (confirm == true) {
                                    await userCancelSubscription(
                                        context, widget.sub.docId);
                                  }
                                },
                                child: Text('Aboneliği İptal Et',style: AppTextStyles.bodySmall,),
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFFE53935),
                                  side: BorderSide(color: Color(0xFFE53935)),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ] else if (isPending) ...[
                      TextButton(
                        onPressed: () async {
                          final confirm = await ShowStyledConfirmDialog.show(
                            context,
                            title: "Abonelik İsteğini İptal Et",
                            message: "İsteğiniz geri çekilecek. Emin misiniz?",
                            confirmText: "Evet, İptal Et",
                          );
                          if (confirm == true) {
                            await userAboneIstegiIptalEt(
                                context, widget.sub.docId);
                          }
                        },
                        child: Text('Abonelik İsteğini İptal Et',style: AppTextStyles.bodySmall,),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF5C6BC0),
                          side: BorderSide(color: Color(0xFF5C6BC0)),
                        ),
                      ),
                    ],
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseVisibleStart(String? s) {
    if (s == null || s.isEmpty) return null;
    // Yıl-Ay-Gün Saat:Dakika (bitiş kısmı varsa görmezden gel)
    final re = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})');
    final m = re.firstMatch(s);
    if (m == null) return null;

    final year  = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day   = int.parse(m.group(3)!);
    final hour  = int.parse(m.group(4)!);
    final min   = int.parse(m.group(5)!);

    return DateTime(year, month, day, hour, min).toLocal();
  }


  Future<DateTime?> fetchPastSubscriptionsCreatedAt(String logId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('subscription_logs')
          .doc(logId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        debugPrint('⚠️ Doküman bulunamadı!');
        return null;
      }

      final data = doc.data()!;


      final ts = data['createdAt'];

      if (ts is Timestamp) {
        final date = ts.toDate();
        return date;
      } else {
        debugPrint('⚠️ Timestamp değilmiş, null dönüyor');
        return null;
      }
    } catch (e, st) {
      debugPrint('🚨 fetchPastSubscriptionsCreatedAt HATA: $e');
      debugPrint('📍 Stack: $st');
      return null;
    }
  }


  }



