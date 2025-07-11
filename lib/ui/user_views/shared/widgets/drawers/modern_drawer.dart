/// -------- ModernDrawer.dart (header sabitlenmiş) --------
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/favoriler_page.dart';
import 'package:toplansin/ui/user_views/subscription_detail_page.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';
import 'package:toplansin/ui/user_views/user_settings_page.dart';
import 'package:toplansin/ui/views/login_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';

class ModernDrawer extends StatelessWidget {
  const ModernDrawer({
    super.key,
    required this.currentUser,
    required this.firebaseUser,
  });

  final Person currentUser;
  final User?  firebaseUser;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      width: 300,
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius:
        const BorderRadius.horizontal(right: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
          child: Container(
            decoration:
            BoxDecoration(color: Colors.white.withOpacity(0.88)),
            child: Column(
              children: [
                // ---------- HEADER (profil + ad + mail) ----------
                DrawerHeader(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.only(left: 20, right: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Icon(Ionicons.person,
                            size: 38, color: Color(0xFF0F6B35)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${currentUser.name}",
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(firebaseUser?.email ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70,fontSize: 14),),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- MENÜ ----------
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _sectionHeader(context, 'HIZLI ERİŞİM'),
                      _tile(
                        context,
                        icon: Ionicons.calendar_outline,
                        label: 'Rezervasyonlarım',
                        color: Colors.green,
                        page: const UserReservationsPage(),
                      ),
                      _tile(
                        context,
                        icon: Ionicons.repeat_outline,
                        label: 'Aboneliklerim',
                        color: Colors.blue,
                        page: SubscriptionDetailPage(
                            currentUser: currentUser),
                      ),
                      _tile(
                        context,
                        icon: Ionicons.heart_outline,
                        label: 'Favorilerim',
                        color: Colors.red,
                        page: FavorilerPage(currentUser: currentUser),
                      ),
                      _sectionHeader(context, 'GENEL'),
                      _tile(
                        context,
                        icon: Ionicons.settings_outline,
                        label: 'Ayarlar',
                        color: Colors.grey.shade700,
                        page:
                        UserSettingsPage(currentUser: currentUser),
                      ),
                      const Divider(thickness: .8),
                      _tile(
                        context,
                        icon: Ionicons.log_out_outline,
                        label: 'Çıkış Yap',
                        color: Colors.red,
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                ),

                // ---------- VERSION ----------
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Text(
                      snap.hasData ? 'v${snap.data!.version}' : '...',
                      style: textTheme.labelSmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------- yardımcılar -----------------
  Widget _tile(
      BuildContext ctx, {
        required IconData icon,
        required String label,
        required Color color,
        Widget? page,
        VoidCallback? onTap,
      }) =>
      ListTile(
        leading: Icon(icon, color: color),
        horizontalTitleGap: 4,
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        onTap: () {
          Navigator.pop(ctx);
          if (onTap != null) return onTap();
          if (page != null) {
            Navigator.of(ctx).push(_slideRoute(page));
          }
        },
      );

  Widget _sectionHeader(BuildContext ctx, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
    child: Text(
      text,
      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.1, color: Colors.grey.shade700),
    ),
  );

  Route _slideRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(anim),
      child: child,
    ),
  );

  Future<void> _signOut(BuildContext ctx) async {
    if (firebaseUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser!.uid)
          .update({'fcmToken': FieldValue.delete()});
    }
    await FirebaseAuth.instance.signOut();
    if (ctx.mounted) {
      Navigator.pushReplacement(
          ctx, MaterialPageRoute(builder: (_) =>  LoginPage()));
    }
  }
}
