import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/subscription_detail_page.dart';
import 'package:toplansin/ui/user_views/user_notification_panel.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';
import 'package:toplansin/ui/user_views/user_settings_page.dart';
import 'package:toplansin/ui/views/login_page.dart';

class FavorilerPage extends StatefulWidget {
  Person currentUser;
  List<HaliSaha> favoriteHaliSahalar;
  int notificationCount;

  FavorilerPage(
      {required this.currentUser,
      required this.favoriteHaliSahalar,
      required this.notificationCount});

  @override
  State<FavorilerPage> createState() => _FavorilerPageState();
}

class _FavorilerPageState extends State<FavorilerPage> {
  Set<int> favoriteHalisaha = {};
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();
    if (doc.exists &&
        doc.data() != null &&
        doc.data()!.containsKey('favorites')) {
      List<dynamic> favIds = doc.data()!['favorites'] ?? [];

      var halisahaSnapshot =
          await FirebaseFirestore.instance.collection('hali_sahalar').get();
      var allHalisahalar = halisahaSnapshot.docs.map((d) {
        var data = d.data();
        var id = d.id;
        return HaliSaha.fromJson(data, id);
      }).toList();

      List<HaliSaha> userFavorites = [];
      for (var favId in favIds) {
        var h = allHalisahalar.firstWhere((element) => element.id == favId,
            orElse: () => null as HaliSaha);
        userFavorites.add(h);
      }

      widget.favoriteHaliSahalar = userFavorites;

      Set<int> favIndexSet = {};
      for (int i = 0; i < widget.favoriteHaliSahalar.length; i++) {
        favIndexSet.add(i);
      }

      setState(() {
        favoriteHalisaha = favIndexSet;
      });
    } else {
      setState(() {
        widget.favoriteHaliSahalar = [];
        favoriteHalisaha = {};
      });
    }
  }

  Future<void> _toggleFavorite(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final selectedHaliSaha = widget.favoriteHaliSahalar[index];

    if (favoriteHalisaha.contains(index)) {
      setState(() {
        favoriteHalisaha.remove(index);
        widget.favoriteHaliSahalar.removeAt(index);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'favorites': FieldValue.arrayRemove([selectedHaliSaha.id])
      });
    } else {
      setState(() {
        favoriteHalisaha.add(index);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'favorites': FieldValue.arrayUnion([selectedHaliSaha.id])
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Toplansın',
          style: TextStyle(
              fontFamily: "Audiowide", fontSize: 26, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        actions: [
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
                      '${widget.notificationCount}', // Bildirim sayısı
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
      drawer: Drawer(
        child: Container(
          color: Colors.grey.shade100,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
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
                    Text(widget.currentUser.name,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    Text(widget.currentUser.email,
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              ListTile(
                leading:
                    Icon(Icons.calendar_today, color: Colors.green.shade700),
                title: Text("Rezervasyonlarım",
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UserReservationsPage()));
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.event_repeat,
                  color: Colors.blue.shade700,
                ),
                title: Text("Aboneliklerim",
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SubscriptionDetailPage(currentUser: widget.currentUser, )),
                  );
                },
              ),
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
                              )));
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text("Çıkış Yap",
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.red)),
                onTap: () async {
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
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
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
          children: [
            if (widget.favoriteHaliSahalar.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "Henüz favori halı sahanız yok. Favorilere eklemek için kalp ikonuna tıklayın!",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (widget.favoriteHaliSahalar.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: widget.favoriteHaliSahalar.length,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemBuilder: (context, index) {
                    var halisaha = widget.favoriteHaliSahalar[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HaliSahaDetailPage(
                                haliSaha: halisaha,
                                currentUser: widget.currentUser),
                          ),
                        );
                      },
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(15)),
                              child: halisaha.imagesUrl.isNotEmpty
                                  ? Image.network(
                                halisaha.imagesUrl.first,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 180, color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          halisaha.name,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                        SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                color: Colors.grey.shade700,
                                                size: 16),
                                            SizedBox(width: 4),
                                            Expanded(
                                                child: Text(halisaha.location,
                                                    style: TextStyle(
                                                        color: Colors
                                                            .grey.shade800))),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.star,
                                                color: Colors.amber, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                                '${halisaha.rating.toStringAsFixed(1)}',
                                                style: TextStyle(
                                                    color:
                                                        Colors.grey.shade800)),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.monetization_on,
                                                color: Colors.green.shade700,
                                                size: 16),
                                            SizedBox(width: 4),
                                            Text('₺${halisaha.price}',
                                                style: TextStyle(
                                                    color:
                                                        Colors.grey.shade800)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 25,
                                    icon: Icon(
                                      favoriteHalisaha.contains(index)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: favoriteHalisaha.contains(index)
                                          ? Colors.red
                                          : Colors.grey.shade500,
                                    ),
                                    onPressed: () => _toggleFavorite(index),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return UserNotificationPanel(currentUser: widget.currentUser,);
      },
    );
  }
}
