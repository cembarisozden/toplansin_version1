import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/user_reservation_detail_page.dart';

class UserReservationsPage extends StatefulWidget {
  const UserReservationsPage({super.key});
  @override
  State<UserReservationsPage> createState() => _UserReservationsPageState();
}

class _UserReservationsPageState extends State<UserReservationsPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  late final TabController _tabController;
  String _searchTerm = '';

  // ─────────────────────── Streams ───────────────────────
  Stream<List<Reservation>> _activeStream(String uid) => FirebaseFirestore
      .instance
      .collection('reservations')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .asyncMap((s) async {
    final list = <Reservation>[];
    for (final doc in s.docs) {
      final res = Reservation.fromDocument(doc);
      try {
        final dt = _parse(res.reservationDateTime);
        if (dt.isBefore(TimeService.now()) &&
            res.status != 'Tamamlandı' &&
            res.status != 'İptal Edildi') {
          await doc.reference.update({'status': 'Tamamlandı'});
          res.status = 'Tamamlandı';
        }
      } catch (_) {}
      list.add(res);

    }
    final active = list
        .where((r) => r.status == 'Onaylandı' || r.status == 'Beklemede')
        .toList()
      ..sort((a, b) =>
          _parse(b.reservationDateTime).compareTo(_parse(a.reservationDateTime)));
    return active;
  });

  Stream<List<Reservation>> _pastStream(String uid) => FirebaseFirestore
      .instance
      .collection('reservation_logs')
      .where('userId', isEqualTo: uid)
      .where('newStatus', whereIn: ['Tamamlandı', 'İptal Edildi'])
      .orderBy('reservationDateTime', descending: true)
      .snapshots(includeMetadataChanges: false)
      .map((s) => s.docs.map(Reservation.fromDocument).toList());

  // ───────────────────── Helpers ─────────────────────
  List<Reservation> _filter(List<Reservation> list) {
    if (_searchTerm.isEmpty) return list;
    final q = _searchTerm.toLowerCase();
    return list.where((r) {
      final name = r.haliSahaName.toLowerCase();
      final date = r.reservationDateTime.toLowerCase();
      final st   = r.status.toLowerCase();
      return name.contains(q) || date.contains(q) || st.contains(q);
    }).toList();
  }

  DateTime _parse(String ts) {
    final parts = ts.split(' ');
    final time  = parts[1].split('-').first;
    return DateTime.parse('${parts[0]} $time');
  }

  // tek sütun = ListView, çoklu sütun = GridView
  Widget _buildItems(List<Reservation> items,
      {required int columns, required String emptyMsg}) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMsg,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16)));
    }

    // ••• 1 sütun  →  ListView  (overflow ihtimali sıfır)
    if (columns == 1) {
      return ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => ReservationCard(reservation: items[i]),
      );
    }

    // ••• 2–4 sütun  →  GridView  (aspect dinamiktir)
    final aspect = columns == 2
        ? 0.9
        : columns == 3
        ? 1.1
        : 1.3;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: aspect,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => ReservationCard(reservation: items[i]),
    );
  }

  // ───────────────────── Lifecycle ─────────────────────
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

  // ───────────────────── UI ─────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final columns = w > 1200 ? 4 : w > 800 ? 3 : w > 600 ? 2 : 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(                                   // 👈  üst çentiklerde taşma yok
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFe0f7fa), Color(0xFFb2ebf2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // başlık & arama
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('Rezervasyonlarım',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleLarge.copyWith(color:AppColors.primaryDark)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintStyle: AppTextStyles.bodyMedium,
                  hintText: 'Rezervasyon ara...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchTerm = v),
              ),
              const SizedBox(height: 12),

              // sekmeler
              TabBar(
                controller: _tabController,
                labelColor: Colors.green.shade800,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.green.shade800,
                tabs: const [
                  Tab(text: 'Aktif Rezervasyonlar'),
                  Tab(text: 'Geçmiş Rezervasyonlar'),
                ],
              ),
              const SizedBox(height: 8),

              // içerik
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Aktif
                    StreamBuilder<List<Reservation>>(
                      stream: _activeStream(_auth.currentUser!.uid),
                      builder: (_, snap) {
                        if (snap.hasError) {
                          return Center(child: Text('Hata: ${snap.error}',
                              style: const TextStyle(color: Colors.red)));
                        }
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final list = _filter(snap.data!);
                        return _buildItems(list,
                            columns: columns,
                            emptyMsg: 'Aktif rezervasyonunuz yok.');
                      },
                    ),

                    // Geçmiş
                    StreamBuilder<List<Reservation>>(
                      stream: _pastStream(_auth.currentUser!.uid),
                      builder: (_, snap) {
                        if (snap.hasError) {
                          return Center(child: Text('Hata: ${snap.error}',
                              style: const TextStyle(color: Colors.red)));
                        }
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final list = _filter(snap.data!);
                        return _buildItems(list,
                            columns: columns,
                            emptyMsg: 'Geçmiş rezervasyonunuz yok.');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────── Card Widget ─────────────────────
class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation});
  final Reservation reservation;

  Color _bg(String s) {
    switch (s) {
      case 'Onaylandı':   return Colors.green.shade100;
      case 'Beklemede':   return Colors.yellow.shade100;
      case 'Tamamlandı':  return Colors.blue.shade100;
      case 'İptal Edildi':return Colors.red.shade100;
      default:            return Colors.grey.shade100;
    }
  }
  Color _fg(String s) {
    switch (s) {
      case 'Onaylandı':   return Colors.green.shade800;
      case 'Beklemede':   return Colors.yellow.shade800;
      case 'Tamamlandı':  return Colors.blue.shade800;
      case 'İptal Edildi':return Colors.red.shade800;
      default:            return Colors.grey.shade800;
    }
  }

  Widget _row(IconData icn, String txt) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icn, color: Colors.grey.shade600, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(txt,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final parts = reservation.reservationDateTime.split(' ');
    final date = parts[0];
    final time = parts.length > 1 ? parts[1] : '';

    return Card(
      color: Colors.grey.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              reservation.haliSahaName,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight:FontWeight.w600,color: Colors.white,overflow: TextOverflow.ellipsis),

            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _row(Icons.calendar_today, date),
                _row(Icons.access_time, time),
                _row(Icons.location_on, reservation.haliSahaLocation),
                _row(Icons.attach_money, '${reservation.haliSahaPrice} TL/saat'),
                const Divider(),
                _row(Icons.person, reservation.userName),
                _row(Icons.phone, reservation.userPhone),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 250;
                final statusBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bg(reservation.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _fg(reservation.status)),
                  ),
                  child: Text(
                    reservation.status,
                    style: AppTextStyles.bodySmall.copyWith(color: _fg(reservation.status)),
                  ),
                );
                final actionBtn = ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserReservationDetailPage(reservation: reservation),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    (reservation.status == 'Tamamlandı' || reservation.status == 'İptal Edildi')
                        ? Colors.blue
                        : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    (reservation.status == 'Tamamlandı' || reservation.status == 'İptal Edildi')
                        ? 'Detaylar'
                        : 'Düzenle',
                    style:  AppTextStyles.bodySmall.copyWith(color: Colors.white,fontWeight: FontWeight.w400),
                  ),
                );
                return narrow
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [statusBadge, const SizedBox(height: 8), actionBtn],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [statusBadge, actionBtn],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

