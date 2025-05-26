import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/errors/app_error_handler.dart';   //  🔸 hata yöneticisi yolu

class OwnerUserStatisticsPannel extends StatefulWidget {
  const OwnerUserStatisticsPannel({Key? key}) : super(key: key);

  @override
  State<OwnerUserStatisticsPannel> createState() =>
      _OwnerUserStatisticsPannelState();
}

class _OwnerUserStatisticsPannelState extends State<OwnerUserStatisticsPannel> {
  late final String _ownerId;
  String _search = '';
  String _activeFilter = 'cancelCount';

  @override
  void initState() {
    super.initState();
    _ownerId = FirebaseAuth.instance.currentUser!.uid;
  }

  /* ─── SAHİBİN sahalarına ait “İptal Edildi / by=user” loglarını grupla ─── */
  Future<List<_UserStat>> _fetchCancelCounts() async {
    try {
      /* 1) Owner’ın saha ID’leri */
      final sahas = await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .where('ownerId', isEqualTo: _ownerId)
          .get();
      final sahaIds = sahas.docs.map((d) => d.id).toList();
      if (sahaIds.isEmpty) return [];

      /* 2) reservation_logs */
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
      if (sahaIds.length <= 10) {
        docs = (await FirebaseFirestore.instance
            .collection('reservation_logs')
            .where('newStatus', isEqualTo: 'İptal Edildi')
            .where('oldStatus', isEqualTo: 'Onaylandı')
            .where('by', isEqualTo: 'user')
            .where('haliSahaId', whereIn: sahaIds)
            .get())
            .docs;
      } else {
        docs = (await FirebaseFirestore.instance
            .collection('reservation_logs')
            .where('newStatus', isEqualTo: 'İptal Edildi')
            .where('by', isEqualTo: 'user')
            .get())
            .docs
            .where((d) => sahaIds.contains(d['haliSahaId']))
            .toList();
      }

      /* 3) userId’ye göre grupla */
      final Map<String, _UserStat> map = {};
      for (final doc in docs) {
        final d = doc.data();
        final uid = d['userId'] ?? '';
        final name = d['userName'] ?? 'Bilinmeyen';
        final email = d['userEmail'] ?? '';
        final phone = d['userPhone'] ?? '';

        map.update(
          uid,
              (old) {
            old.cancelCount++;
            return old;
          },
          ifAbsent: () => _UserStat(
            uid: uid,
            name: name,
            email: email,
            phone: phone,
            cancelCount: 1,
          ),
        );
      }

      final list = map.values.toList()
        ..sort((a, b) => b.cancelCount.compareTo(a.cancelCount));
      return list;
    } catch (e) {
      // Hata üst katmana fırlatılıyor, FutureBuilder yakalayacak
      throw e;
    }
  }

  /* ───────────────────────── UI ───────────────────────── */
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
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.green.shade800),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Kullanıcı İstatistikleri',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),

            /* Arama + filtre */
            // Arama + filtre
            Row(
              children: [
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
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),

                /* ▼ Filtre düğmesi */
                PopupMenuButton<String>(
                  tooltip: 'Filtrele',
                  icon: const Icon(Icons.filter_list, color: Colors.green),
                  onSelected: (value) => setState(() => _activeFilter = value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'cancelCount',
                      child: Row(
                        children: [
                          SizedBox(width: 8),
                          Text('İptal Sayısı'),
                        ],
                      ),
                    ),
                  ],
                ),

                /* Etiket — aktif filtre adı */
                const SizedBox(width: 4),
                Text(
                  _activeFilter == 'cancelCount' ? 'İptal Sayısı' : '',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),


            const SizedBox(height: 16),

            /* Liste */
            Expanded(
              child: FutureBuilder<List<_UserStat>>(
                future: _fetchCancelCounts(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    final msg = AppErrorHandler.getMessage(
                      snap.error,
                      context: 'reservation',
                    );
                    return Center(
                      child: Text(msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    );
                  }

                  var list = snap.data ?? [];

                  if (_search.isNotEmpty) {
                    list = list
                        .where((u) => u.name
                        .toLowerCase()
                        .contains(_search.toLowerCase()))
                        .toList();
                  }

                  if (list.isEmpty) {
                    return Center(
                      child: Text('Kayıt bulunamadı',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 16)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _userCard(list[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ────────── Kullanıcı kartı ────────── */
  Widget _userCard(_UserStat stat) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.green.shade700,
              child: Text(
                stat.name.isNotEmpty ? stat.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stat.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (stat.email.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.email_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(stat.email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700)),
                      ),
                    ]),
                  if (stat.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(stat.phone,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700)),
                      ]),
                    ),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, size: 18, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('${stat.cancelCount}',
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────── Model ───────────── */
class _UserStat {
  final String uid;
  final String name;
  final String email;
  final String phone;
  int cancelCount;

  _UserStat({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.cancelCount,
  });
}
