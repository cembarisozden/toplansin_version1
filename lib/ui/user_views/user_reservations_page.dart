import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';
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

  // ───────────────────────── CLOUD STREAMLER ─────────────────────────

  //// Aktif + beklemede rezervasyonlar (ana koleksiyon)
  Stream<List<Reservation>> _activeStream(String uid) => FirebaseFirestore
      .instance
      .collection('reservations')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .asyncMap((s) async {
    final list = <Reservation>[];

    for (final doc in s.docs) {
      final res = Reservation.fromDocument(doc);

      // ⏰ tarih kontrolü
      try {
        final dt = _parse(res.reservationDateTime);
        if (dt.isBefore(TimeService.now()) &&
            res.status != 'Tamamlandı' &&
            res.status != 'İptal Edildi') {
          await doc.reference.update({'status': 'Tamamlandı'});
          res.status = 'Tamamlandı';
        }
      } catch (_) {
        debugPrint('Tarih formatı hatası: ${res.reservationDateTime}');
      }

      list.add(res);
    }

    // 🔹 aktif + beklemede
    final active = list
        .where((r) => r.status == 'Onaylandı' || r.status == 'Beklemede')
        .toList();

    // 🔹 EN YENİ ÖNDE
    active.sort(
            (a, b) => _parse(b.reservationDateTime).compareTo(_parse(a.reservationDateTime)));

    return active;
  });

  /// Geçmiş rezervasyonlar (log koleksiyonu)
  Stream<List<Reservation>> _pastStream(String uid) => FirebaseFirestore
      .instance
      .collection('reservation_logs')
      .where('userId', isEqualTo: uid)
      .where('newStatus', whereIn: ['Tamamlandı', 'İptal Edildi'])
      .orderBy('reservationDateTime', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Reservation.fromDocument).toList());

  // ───────────────────────── YARDIMCI METODLAR ─────────────────────────

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

  DateTime _parse(String reservationDateTime) {
    // "2025-05-20 18:00-19:00" → 2025-05-20 18:00
    final parts = reservationDateTime.split(' ');
    final date = parts[0];
    final time = parts[1].split('-').first;
    return DateTime.parse('$date $time');
  }


  Widget _buildGrid(List<Reservation> items,
      {required int columns, required double aspect, required String emptyMsg}) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMsg,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16)));
    }
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




  // ───────────────────────── LIFECYCLE ─────────────────────────

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



  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final columns = w > 1200 ? 4 : w > 800 ? 3 : w > 600 ? 2 : 1;
    const aspect = 3 / 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0f7fa), Color(0xFFb2ebf2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            // başlık
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.green.shade800),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text('Rezervasyonlarım',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800)),
                ),
                const SizedBox(width: 48), // simetri boşluğu
              ],
            ),
            const SizedBox(height: 20),
            // arama
            TextField(
              decoration: InputDecoration(
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
            const SizedBox(height: 20),
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
            const SizedBox(height: 10),

            // içerik
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Aktif ──
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
                      return _buildGrid(list,
                          columns: columns,
                          aspect: aspect,
                          emptyMsg: 'Aktif rezervasyonunuz yok.');
                    },
                  ),

                  // ── Geçmiş ──
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
                      return _buildGrid(list,
                          columns: columns,
                          aspect: aspect,
                          emptyMsg: 'Geçmiş rezervasyonunuz yok.');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── KART WIDGET'I ─────────────────────────
class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation});
  final Reservation reservation;

  Color _bg(String s) {
    switch (s) {
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

  Color _fg(String s) {
    switch (s) {
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

  Widget _row(IconData icn, String txt) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icn, color: Colors.grey.shade600, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(txt,
              style:
              TextStyle(color: Colors.grey.shade700, fontSize: 14)),
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
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
            child: Text(reservation.haliSahaName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          // content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(Icons.calendar_today, date),
                _row(Icons.access_time, time),
                _row(Icons.location_on, reservation.haliSahaLocation),
                _row(Icons.attach_money,
                    '${reservation.haliSahaPrice} TL/saat'),
              ],
            ),
          ),
          // footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // status badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _bg(reservation.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _fg(reservation.status)),
                  ),
                  child: Text(reservation.status,
                      style: TextStyle(
                          color: _fg(reservation.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                // detay / düzenle
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            UserReservationDetailPage(reservation: reservation)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    (reservation.status == 'Tamamlandı' ||
                        reservation.status == 'İptal Edildi')
                        ? Colors.blue
                        : Colors.green,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    (reservation.status == 'Tamamlandı' ||
                        reservation.status == 'İptal Edildi')
                        ? 'Detaylar'
                        : 'Düzenle',
                    style:
                    const TextStyle(color: Colors.white, fontSize: 12),
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
