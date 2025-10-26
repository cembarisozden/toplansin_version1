import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/owner_providers/OwnerNotificationProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/owner_views/owner_add_halisaha.dart';
import 'package:toplansin/ui/owner_views/owner_halisaha_page.dart';
import 'package:toplansin/ui/owner_views/owner_profile_settings.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';
import 'package:badges/badges.dart' as badges;

class OwnerMainPage extends StatefulWidget {
  final Person currentOwner;
  const OwnerMainPage({required this.currentOwner, Key? key}) : super(key: key);

  @override
  State<OwnerMainPage> createState() => _OwnerMainPageState();
}

class _OwnerMainPageState extends State<OwnerMainPage> {
  // Aynı saha için dinleyicileri bir kez başlatmak için set:
  final _startedListenersForSahaIds = <String>{};

  User? get _owner => FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    final owner = _owner;
    if (owner != null) {
      // Hata olsa bile uygulama çökmesin
      await FirebaseFirestore.instance
          .collection('users')
          .doc(owner.uid)
          .update({'fcmToken': FieldValue.delete()})
          .catchError((_) {});
    }
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OwnerNotificationProvider>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Halı Saha Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerAddHaliSaha()));
          // StreamBuilder sayesinde ekstra refresh gerekmez.
        },
        backgroundColor: Colors.green.shade700,
        tooltip: "Halı Saha Ekle",
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      drawer: _buildDrawer(),
      body: Container(
        color: Colors.grey.shade100,
        child: user == null
            ? const Center(child: Text("Oturum bulunamadı. Lütfen tekrar giriş yapın."))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("hali_sahalar")
              .where("ownerId", isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            // Boş durum:
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sports_soccer, size: 48, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Text(
                        "Henüz kayıtlı halı sahan yok.",
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Sağ alttan yeni bir halı saha ekleyebilirsin.",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Snapshot'tan listeyi oluştur
            final sahalar = docs
                .map((d) => HaliSaha.fromJson(d.data(), d.id))
                .toList(growable: false);

            // Bildirim dinleyicilerini sadece bir kez başlat
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final notifProv = context.read<OwnerNotificationProvider>();
              for (final saha in sahalar) {
                if (_startedListenersForSahaIds.add(saha.id)) {
                  // Provider metodların StreamSubscription döndürüyorsa yakalayıp dispose'da cancel edebilirsin.
                  notifProv.startReservationListener(saha.id);
                  notifProv.startSubscriptionListener(saha.id);
                }
              }
            });

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sahalar.length,
              itemBuilder: (context, index) {
                final saha = sahalar[index];

                final resCount = provider.getNotificationCount("reservation_${saha.id}") ?? 0;
                final subCount = provider.getNotificationCount("subscription_${saha.id}") ?? 0;
                final notificationCount = resCount + subCount;

                final String? imageUrl =
                (saha.imagesUrl.isNotEmpty) ? saha.imagesUrl.first : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Sol yeşil vurgu şeridi
                        Positioned.fill(
                          left: 0,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.green.shade600, Colors.green.shade400],
                                ),
                              ),
                            ),
                          ),
                        ),

                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OwnerHalisahaPage(
                                    context: context,
                                    haliSaha: saha,
                                    currentOwner: widget.currentOwner,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Sol görsel
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          height: 72,
                                          width: 72,
                                          child: imageUrl != null
                                              ? ProgressiveImage(
                                            imageUrl: imageUrl,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          )
                                              : Container(
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.image_not_supported),
                                          ),
                                        ),
                                        // hafif alttan parlama
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.center,
                                                  colors: [
                                                    Colors.black.withOpacity(0.12),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  // Orta metin alanı
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // İsim
                                        Text(
                                          saha.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16.5,
                                            color: Colors.grey.shade900,
                                            height: 1.05,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        // Konum
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                saha.location,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  color: Colors.grey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  // Sağ: bildirim (önemli) + ok ikonu
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Bildirim: varsa belirgin rozet, yoksa sade zil
                                      if (notificationCount > 0)
                                        badges.Badge(
                                          position: badges.BadgePosition.topEnd(top: -8, end: -6),
                                          badgeContent: Text(
                                            '$notificationCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          badgeStyle: badges.BadgeStyle(
                                            badgeColor: Colors.red,
                                            elevation: 2,
                                            borderSide: const BorderSide(color: Colors.white, width: 1),
                                            borderRadius: BorderRadius.circular(12),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          ),
                                          child: Icon(Icons.notifications_active_rounded,
                                              size: 22, color: Colors.grey.shade800),
                                        )
                                      else
                                        Icon(Icons.notifications_none_rounded,
                                            size: 22, color: Colors.grey.shade400),

                                      const SizedBox(width: 12),

                                      // Ok ikonu (navigasyon)
                                      Icon(Icons.arrow_forward_ios_rounded,
                                          size: 18, color: Colors.grey.shade400),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );


              },
            );
          },
        ),
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.grey.shade100,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                widget.currentOwner.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(widget.currentOwner.email),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.green.shade700),
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
              title: const Text('Hesap Ayarları', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OwnerProfileSettings(currentOwner: widget.currentOwner),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
