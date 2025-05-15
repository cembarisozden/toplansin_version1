import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/abonelik_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/user_notification_panel.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';
import 'package:toplansin/ui/user_views/user_settings_page.dart';
import 'package:toplansin/ui/views/login_page.dart';

class HaliSahaPage extends StatefulWidget {
  final Person currentUser;
  List<HaliSaha> favoriteHaliSahalar;
  int notificationCount;

  HaliSahaPage({
    required this.currentUser,
    required this.favoriteHaliSahalar,
    required this.notificationCount,
  });

  User? user = FirebaseAuth.instance.currentUser;

  @override
  State<HaliSahaPage> createState() => _HaliSahaPageState();
}

class _HaliSahaPageState extends State<HaliSahaPage> {
  /// Firestore koleksiyon referansı
  final collectionHaliSaha =
      FirebaseFirestore.instance.collection("hali_sahalar");

  /// Tüm halı sahaları tutan liste (orijinal, filtrelenmemiş).
  List<HaliSaha> _allHaliSahalar = [];

  /// Ekranda gösterdiğimiz filtrelenmiş liste (arama yapıldığında burası güncellenir).
  List<HaliSaha> halisahalar = [];

  /// Favori seçilen halı sahaların index bilgisi (listenin index’i) tutuluyor.
  /// Dilerseniz id bazlı da tutabilirsiniz.
  Set<int> favoriteHalisaha = {};

  /// Firestore realtime dinleme için Subscription.
  StreamSubscription<QuerySnapshot>? _haliSahaSubscription;

  /// Arama alanı için TextEditingController
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupRealtimeHaliSahaListener();

    _searchController.addListener(_filterHaliSahalar);

    _loadFavorites();
  }

  /// Canlı (realtime) dinlemeyi ayarlayan fonksiyon
  void _setupRealtimeHaliSahaListener() {
    _haliSahaSubscription = collectionHaliSaha.snapshots().listen((snapshot) {
      List<HaliSaha> allHalisahalar = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        var key = doc.id;
        var haliSaha = HaliSaha.fromJson(data, key);
        allHalisahalar.add(haliSaha);
      }

      setState(() {
        _allHaliSahalar = allHalisahalar;
      });

      // Yeni veri geldiğinde arama filtresi tekrar uygulansın
      _filterHaliSahalar();
    }, onError: (error) {
      print("Hata oluştu: $error");
    });
  }

  /// Metin girişi değiştiğinde veya Firestore değiştiğinde filtreleme yapan fonksiyon
  void _filterHaliSahalar() {
    final query = _searchController.text.toLowerCase();

    // Eğer arama kutusu boşsa tüm halı sahaları göster
    if (query.isEmpty) {
      setState(() {
        halisahalar = List.from(_allHaliSahalar);
      });
    } else {
      // Arama kutusuna girilen metin hem isme hem lokasyona göre aranabilir
      setState(() {
        halisahalar = _allHaliSahalar.where((haliSaha) {
          final nameLower = haliSaha.name.toLowerCase();
          final locationLower = haliSaha.location.toLowerCase();
          return nameLower.contains(query) || locationLower.contains(query);
        }).toList();
      });
    }
  }

  /// Firestore'dan kullanıcının favori halı sahalarını çekiyoruz.
  Future<void> _loadFavorites() async {
    if (widget.user == null) return;
    final userId = widget.user!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (doc.exists &&
        doc.data() != null &&
        doc.data()!.containsKey('favorites')) {
      List<dynamic> favIds = doc.data()!['favorites'] ?? [];
      List<HaliSaha> userFavorites = [];
      Set<int> favIndexSet = {};

      // henüz _allHaliSahalar boş olabilir (dinleme gecikmeli gelebilir),
      // bu nedenle futureBuilder veya streamBuilder mantığı da kullanılabilir.
      // Kolaylık için bu haliyle bırakıyoruz.

      for (var favId in favIds) {
        int index =
            _allHaliSahalar.indexWhere((element) => element.id == favId);
        if (index != -1) {
          userFavorites.add(_allHaliSahalar[index]);
          favIndexSet.add(index);
        }
      }

      setState(() {
        widget.favoriteHaliSahalar = userFavorites;
        favoriteHalisaha = favIndexSet;
      });
    } else {
      setState(() {
        widget.favoriteHaliSahalar = [];
        favoriteHalisaha = {};
      });
    }
  }

  /// Favori ekleme/çıkarma mantığı
  Future<void> _toggleFavorite(int index) async {
    if (widget.user == null) return;
    final userId = widget.user!.uid;

    /// Ekranda görüntülenen halisahalar listesi üzerinden gidiyoruz
    final selectedHaliSaha = halisahalar[index];

    // Tüm halı sahalar içinde selectedHaliSaha'nın indeksi (favoriSet’i güncellemek için)
    final realIndex = _allHaliSahalar
        .indexWhere((element) => element.id == selectedHaliSaha.id);

    if (favoriteHalisaha.contains(realIndex)) {
      // Zaten favori ise => Çıkart
      setState(() {
        favoriteHalisaha.remove(realIndex);
        widget.favoriteHaliSahalar
            .removeWhere((saha) => saha.id == selectedHaliSaha.id);
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayRemove([selectedHaliSaha.id])
      });
    } else {
      // Favoriye ekle
      setState(() {
        favoriteHalisaha.add(realIndex);
        widget.favoriteHaliSahalar.add(selectedHaliSaha);
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'favorites': FieldValue.arrayUnion([selectedHaliSaha.id])
      });
    }
  }

  @override
  void dispose() {
    _haliSahaSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Toplansın',
          style: TextStyle(
            fontFamily: "Audiowide",
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        actions: [
          // Bildirim ikonu
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  _showNotificationPanel(context);
                },
              ),
              if (widget.notificationCount != 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${widget.notificationCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      drawer: _buildDrawer(context),

      /// Gövde
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
          children: [
            // Arama alanı
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Halı saha ara...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _buildHaliSahaList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Drawer (yan menü) inşa eden fonksiyon
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.grey.shade100,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            /// Header
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade700, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        color: Colors.green.shade700, size: 40),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.currentUser.name,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(widget.user?.email ?? "",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            /// Rezervasyonlarım

            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.green.shade700),
              title: Text("Rezervasyonlarım",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserReservationsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.event_repeat, color: Colors.blue.shade700,),
              title: Text("Aboneliklerim",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AboneliklerimPage()),
                );
              },
            ),

            /// Ayarlar
            ListTile(
              leading: Icon(Icons.settings, color: Colors.grey.shade700),
              title: Text("Ayarlar",
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserSettingsPage(
                      currentUser: widget.currentUser,
                    ),
                  ),
                );
              },
            ),

            Divider(),

            /// Çıkış Yap
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text("Çıkış Yap",
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.red)),
              onTap: () async {
                if (widget.user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.user?.uid)
                      .update({
                    'fcmToken': FieldValue.delete(),
                  });
                }
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Halı saha listesi (filtrelenmiş liste: `halisahalar`)
  Widget _buildHaliSahaList() {
    return ListView.builder(
      itemCount: halisahalar.length,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        var halisaha = halisahalar[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HaliSahaDetailPage(
                  haliSaha: halisaha,
                  currentUser: widget.currentUser,
                ),
              ),
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 3,
            margin: EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resim
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  child: (halisaha.imagesUrl.isNotEmpty)
                      ? Image.asset(
                          "assets/halisaha_images/${halisaha.imagesUrl.first}",
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(height: 180, color: Colors.grey.shade300),
                ),
                // Bilgiler
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ad, lokasyon, vs.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              halisaha.name,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: Colors.grey.shade700, size: 16),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    halisaha.location,
                                    style:
                                        TextStyle(color: Colors.grey.shade800),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '${halisaha.rating.toStringAsFixed(1)}',
                                  style: TextStyle(color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.monetization_on,
                                    color: Colors.green.shade700, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  '₺${halisaha.price}',
                                  style: TextStyle(color: Colors.grey.shade800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Favori ikonu
                      IconButton(
                        iconSize: 26,
                        icon: Icon(
                          // Gerçek index'i bulmak için
                          favoriteHalisaha.contains(
                            _allHaliSahalar.indexWhere(
                              (element) => element.id == halisaha.id,
                            ),
                          )
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: favoriteHalisaha.contains(
                                  _allHaliSahalar.indexWhere(
                                      (element) => element.id == halisaha.id))
                              ? Colors.redAccent
                              : Colors.grey.shade500,
                        ),
                        onPressed: () {
                          _toggleFavorite(index);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Bildirim alt panelini açan fonksiyon
  void _showNotificationPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return UserNotificationPanel();
      },
    );
  }
}
