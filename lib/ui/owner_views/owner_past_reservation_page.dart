import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';

enum DateFilter { all, today, last7Days, thisMonth }

class OwnerPastReservationsPage extends StatefulWidget {
  final String haliSahaId;

  const OwnerPastReservationsPage({super.key, required this.haliSahaId});

  @override
  State<OwnerPastReservationsPage> createState() =>
      _OwnerPastReservationsPageState();
}

class _OwnerPastReservationsPageState extends State<OwnerPastReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';
  DateFilter _filter = DateFilter.all;

  // ────────────────── LOG SORGUSU (status parametreli) ──────────────────
  Stream<List<Reservation>> _logStream(String status) =>
      FirebaseFirestore.instance
          .collection('reservation_logs')
          .where('haliSahaId', isEqualTo: widget.haliSahaId)
          .where('newStatus', isEqualTo: status)
          .orderBy('reservationDateTime', descending: true)
          .snapshots()
          .map((s) => s.docs.map(Reservation.fromDocument).toList());

  // ────────────────── YARDIMCILAR ──────────────────
  DateTime? _parse(String raw) {
    try {
      final parts = raw.split(' ');
      return DateTime.parse('${parts[0]} ${parts[1].split('-').first}');
    } catch (_) {
      return null;
    }
  }

  List<Reservation> _applyFilters(List<Reservation> list) {
    final now = TimeService.now();
    DateTime? start;
    switch (_filter) {
      case DateFilter.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case DateFilter.last7Days:
        start = now.subtract(const Duration(days: 7));
        break;
      case DateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case DateFilter.all:
        start = null;
        break;
    }
    return list.where((r) {
      final dt = _parse(r.reservationDateTime);
      final matchDate = start == null || (dt != null && dt.isAfter(start));
      final matchSearch =
          r.userName.toLowerCase().contains(_search.toLowerCase()) ?? false;
      return matchDate && matchSearch;
    }).toList();
  }

  Widget _buildGrid(List<Reservation> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('Kayıt bulunamadı.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
      );
    }

    final w = MediaQuery.of(context).size.width;
    final cols = w > 1200
        ? 4
        : w > 800
            ? 3
            : w > 600
                ? 2
                : 1;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 3 / 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => ReservationCard(reservation: items[i]),
    );
  }

  // ────────────────── LIFECYCLE ──────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // ────────────────── UI ──────────────────
  @override
  Widget build(BuildContext context) {
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
            // başlık ve geri
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.green.shade800),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text('Geçmiş Rezervasyonlar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800)),
                ),
                const SizedBox(width: 48)
              ],
            ),
            const SizedBox(height: 20),

            // arama + tarih filtresi
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı ara...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<DateFilter>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: DateFilter.all, child: Text('Tümü')),
                  DropdownMenuItem(
                      value: DateFilter.today, child: Text('Bugün')),
                  DropdownMenuItem(
                      value: DateFilter.last7Days, child: Text('Son 7 Gün')),
                  DropdownMenuItem(
                      value: DateFilter.thisMonth, child: Text('Bu Ay')),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ]),
            const SizedBox(height: 16),

            // sekmeler
            TabBar(
              controller: _tabController,
              labelColor: Colors.green.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.green.shade800,
              tabs: const [
                Tab(text: 'Tamamlanmış'),
                Tab(text: 'İptal Edilen'),
              ],
            ),
            const SizedBox(height: 10),

            // içerik
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── TAMAMLANMIŞ ───────────────────────────────────────────
                  StreamBuilder<List<Reservation>>(
                    stream: _logStream('Tamamlandı'),
                    builder: (_, snap) {
                      if (snap.hasError) {
                        final msg = AppErrorHandler.getMessage(
                          snap.error,
                          context: 'reservation',
                        );
                        return Center(
                          child: Text(msg,
                              style: const TextStyle(color: Colors.red)),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = _applyFilters(snap.data!);
                      return _buildGrid(list);
                    },
                  ),

// ── İPTAL EDİLEN ──────────────────────────────────────────
                  StreamBuilder<List<Reservation>>(
                    stream: _logStream('İptal Edildi'),
                    builder: (_, snap) {
                      if (snap.hasError) {
                        final msg = AppErrorHandler.getMessage(
                          snap.error,
                          context: 'reservation',
                        );
                        return Center(
                          child: Text(msg,
                              style: const TextStyle(color: Colors.red)),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = _applyFilters(snap.data!);
                      return _buildGrid(list);
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
