import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reservation.dart';
import 'package:toplansin/ui/owner_views/owner_add_halisaha.dart';
import 'package:toplansin/ui/owner_views/owner_halisaha_page.dart';
import 'package:toplansin/ui/owner_views/owner_profile_settings.dart';
import 'package:toplansin/core/providers/OwnerNotificationProvider.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';
import 'package:badges/badges.dart' as badges;

class OwnerMainPage extends StatefulWidget {
  final Person currentOwner;
  List<HaliSaha> halisahalar = [];

  OwnerMainPage({required this.currentOwner});

  @override
  _OwnerMainPageState createState() => _OwnerMainPageState();
}

class _OwnerMainPageState extends State<OwnerMainPage> {
  var collectionHaliSaha = FirebaseFirestore.instance.collection("hali_sahalar");
  List<Reservation> haliSahaReservationsRequests = [];
  var owner=FirebaseAuth.instance.currentUser;

  Future<void> readHaliSaha() async {
    if (FirebaseAuth.instance.currentUser == null) {
      print('Kullanıcı oturum açmamış.');
      return;
    }

    QuerySnapshot querySnapshot = await collectionHaliSaha
        .where("ownerId", isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .get();

    var documents = querySnapshot.docs;

    setState(() {
      widget.halisahalar.clear();
      for (var document in documents) {
        var data = document.data() as Map<String, dynamic>;
        var key = document.id;
        var hali_saha = HaliSaha.fromJson(data, key);
        widget.halisahalar.add(hali_saha);
        print("Okunan HaliSaha: ${hali_saha.name}");
      }
    });
  }

  void listenToReservationsRequests(String haliSahaId) {
    try {
      var stream = FirebaseFirestore.instance
          .collection("reservations")
          .where("haliSahaId", isEqualTo: haliSahaId)
          .where("status", isEqualTo: 'Beklemede')
          .snapshots();

      stream.listen((snapshot) {
        List<Reservation> reservations = [];
        for (var document in snapshot.docs) {
          var reservation = Reservation.fromDocument(document);
          reservations.add(reservation);
        }

        setState(() {
          haliSahaReservationsRequests = reservations;
        });

        Provider.of<NotificationProvider>(context, listen: false)
            .setNotificationCount(haliSahaId, reservations.length);

        debugPrint(
            "Beklemede rezervasyonlar başarıyla güncellendi: ${reservations.length} adet.");
      });
    } catch (e) {
      debugPrint("Rezervasyonları dinlerken hata oluştu: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    readHaliSaha().then((_) {
      for (var saha in widget.halisahalar) {
        listenToReservationsRequests(saha.id);
      }
    });
  }



  Future<void> _logout() async {
    if (owner != null) {
      await FirebaseFirestore.instance.collection('users').doc(owner?.uid).update({
        'fcmToken': FieldValue.delete(),
      });
    }
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Halı Saha Yönetimi",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [

        ],
        elevation: 4,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => OwnerAddHaliSaha()));
        },
        child: Icon(Icons.add, color: Colors.white, size: 30),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        tooltip: "Halı Saha Ekle",
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.grey.shade100,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  widget.currentOwner.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                accountEmail: Text(widget.currentOwner.email),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: AssetImage("assets/halisaha_images/halisaha0.jpg"),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: Colors.grey.shade800),
                title: Text(
                  'Hesap Ayarları',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OwnerProfileSettings(currentOwner: widget.currentOwner),
                    ),
                  );
                },
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text(
                  'Çıkış Yap',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: widget.halisahalar.length,
          itemBuilder: (context, index) {
            var saha = widget.halisahalar[index];
            final notificationCount = notificationProvider.getNotificationCount(saha.id);

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              margin: EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OwnerHalisahaPage(
                        haliSaha: saha,
                        currentOwner: widget.currentOwner,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          "assets/halisaha_images/${saha.imagesUrl.isNotEmpty ? saha.imagesUrl.first : 'halisaha0.jpg'}",
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              saha.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green.shade800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "${saha.location} - ${saha.price} TL/saat",
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      if (notificationCount > 0)
                        badges.Badge(
                          badgeContent: Text(
                            '$notificationCount',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          badgeStyle: badges.BadgeStyle(
                            badgeColor: Colors.red,
                            elevation: 2,
                            borderSide: BorderSide(color: Colors.white, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
