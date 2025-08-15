import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/HomeProvider.dart';
import 'package:toplansin/core/providers/bottomNavProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/favoriler_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/banner/phone_verify_banner.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';
import 'package:toplansin/ui/user_views/user_acces_code_page.dart';
import 'package:toplansin/ui/user_views/user_settings_page.dart';
import '../../data/entitiy/person.dart';
import '../user_views/user_reservations_page.dart';
import '../user_views/subscription_detail_page.dart';
import '../user_views/shared/theme/app_colors.dart';

class DashboardBody extends StatefulWidget {
  Person? user;

  DashboardBody({super.key, this.user});

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  List<HaliSaha> favoriteHaliSahalar = [];

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().init();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    favoriteHaliSahalar = context.watch<HomeProvider>().favoriteHaliSahalar;
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
            ),
          ),
          child: Column(
            children: [
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.userChanges(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final noPhone = user?.phoneNumber == null;
                  if (!noPhone) return SizedBox.shrink();
                  return PhoneVerifyBanner(
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            UserSettingsPage(currentUser: widget.user!),
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                            child: _welcomeCard(widget.user!.name)),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: accessCodeNote(context),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: infoBanner(
                            context: context,
                            text:
                                'Hey kaptan, tüm abonelik ve rezervasyonlarını aşağıdan görüntüleyebilirsin, kontrol sende!',
                            icon: Ionicons.caret_down_outline,
                            // ister başka ikon
                            iconColor: AppColors.secondary, // marka rengin
                            // gradientStart / gradientEnd / borderColor vb. parametreleri
                            // geçmezsen varsayılanlar kullanılır.
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                            child: _actionRow(widget.user!, context)),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: infoBanner(
                              context: context,
                              text: "Hemen başla, müsait saatleri kaçırma!",
                              icon: Ionicons.football_outline),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: favoritesPitches(
                            favoriteHaliSahalar: favoriteHaliSahalar,
                            user: widget.user!,
                            onSeeAllTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FavorilerPage(
                                        currentUser: widget.user!),
                                  ));
                            },
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: trendPitches(
                            user: widget.user!,
                            onSeeAllTrends: () {
                              Provider.of<BottomNavProvider>(context,
                                      listen: false)
                                  .setIndex(1);
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget accessCodeNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accessOrange.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Ionicons.key_outline,
                    size: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Mevcut saha erişim kodların ve rezervasyon yapabileceğin sahalar",
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              "Yalnızca erişimin olan sahalara rezervasyon yapabilirsin. Diğer sahalar için ilgili "
              "halı saha ile iletişime geçerek bir “Erişim Kodu” alman gerekir.",
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              // — CTA: Erişim Kodlarım —
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserAccessCodePage(),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accessOrange,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(.18),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Ionicons.key_outline, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Erişim Kodlarım",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // — Yardım linki —
              TextButton(
                onPressed: () => _showAccessCodeHelpSheet(context),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  "Kod nasıl alınır?",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccessCodeHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accessOrange.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Ionicons.help_circle_outline,
                        size: 18, color: AppColors.accessOrange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Erişim Kodu nasıl alınır?",
                      style: AppTextStyles.titleSmall.copyWith(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "1) İlgili halı sahanın profilindeki iletişim bilgilerinden saha ile görüş.\n"
                "2) Rezervasyon yapabilmek için kişisel “Saha Erişim Kodu” talep et.\n"
                "3) Aldığın kodu “Saha Erişim Kodlarım” sayfasına ekle.\n"
                "4) Güvenlik için kodu kimseyle paylaşma.",
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const UserAccessCodePage(), // HaliSahaAccessCodesPage(),
                      ),
                    );
                  },
                  icon: const Icon(Ionicons.key_outline, size: 18),
                  label: const Text("Erişim Kodlarım’a Git"),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.accessOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget favoritesPitches({
    required List<HaliSaha> favoriteHaliSahalar,
    required VoidCallback onSeeAllTap,
    required Person user,
  }) {
    if (favoriteHaliSahalar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*  Başlık + “Tümünü Gör”  */
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.favorite, color: Colors.red, size: 20),
              SizedBox(width: 6),
              Text(
                'Favorilediklerin',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: onSeeAllTap,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              )
              //  TextButton const olamıyor (callback değişken)
            ],
          ),
        ),

        /*  Yatay kart listesi  */
        SizedBox(
          height: 120,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            // iOS benzeri akıcılık
            scrollDirection: Axis.horizontal,
            itemExtent: 132,
            // 120 + 12 padding
            addAutomaticKeepAlives: false,
            // RAM dostu
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: favoriteHaliSahalar.length,
            itemBuilder: (context, index) {
              final saha = favoriteHaliSahalar[index];

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: saha.id,
                        child: ProgressiveImage(
                          imageUrl: saha.imagesUrl.first,
                          width: 120,
                          height: 120,
                          borderRadius: 16,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HaliSahaDetailPage(
                                currentUser: user,
                                haliSaha: saha,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /*── Sadece etiket alanını blur + yarı saydam arka plan ──*/
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            // düşük maliyet
                            child: Container(
                              height: 36,
                              color: Colors.black45,
                              // %55 opak
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Text(
                                saha.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 2,
                                      offset: Offset(0.5, 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget trendPitches({
    required VoidCallback onSeeAllTrends,
    required Person user,
  }) {
    final trendHaliSahalar = context.watch<HomeProvider>().trendHaliSahalar;

    if (trendHaliSahalar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*  Başlık + “Tümünü Gör”  */
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Ionicons.flash, color: Colors.orange, size: 20),
              SizedBox(width: 6),
              Text(
                'Trendler',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Spacer(),
              TextButton(
                onPressed: onSeeAllTrends,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              )
              //  TextButton const olamıyor (callback değişken)
            ],
          ),
        ),

        /*  Yatay kart listesi  */
        SizedBox(
          height: 120,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            // iOS benzeri akıcılık
            scrollDirection: Axis.horizontal,
            itemExtent: 132,
            // 120 + 12 padding
            addAutomaticKeepAlives: false,
            // RAM dostu
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: trendHaliSahalar.length,
            itemBuilder: (context, index) {
              final saha = trendHaliSahalar[index];

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: "trend" + saha.id,
                        child: ProgressiveImage(
                          imageUrl: saha.imagesUrl.first,
                          width: 120,
                          height: 120,
                          borderRadius: 16,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HaliSahaDetailPage(
                                currentUser: user,
                                haliSaha: saha,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /*── Sadece etiket alanını blur + yarı saydam arka plan ──*/
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            // düşük maliyet
                            child: Container(
                              height: 36,
                              color: Colors.black45,
                              // %55 opak
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 8, right: 8),
                              child: Text(
                                saha.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black38,
                                      blurRadius: 2,
                                      offset: Offset(0.5, 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _welcomeCard(String name) {
    final firstName =
        (name.trim().isEmpty ? "Kaptan" : name.trim().split(' ').first);
    final h = TimeService.now().hour;
    final greeting =
        h < 12 ? "Günaydın" : (h < 18 ? "İyi günler" : "İyi akşamlar");

    const double cardHeight = 140; // istersen 132–156 arası oynat
    const double radius = 20;

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment(-1, -0.8),
          end: Alignment(1.1, 0.9),
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // yumuşak ışık baloncukları (mevcut _blurBubble'ını kullanıyoruz)
          Positioned(top: -28, right: -24, child: _blurBubble(110, .14)),
          Positioned(bottom: -20, left: -10, child: _blurBubble(80, .10)),

          // diagonal parlama dokusu
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.10),
                    Colors.transparent,
                    Colors.white.withOpacity(.06)
                  ],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // sol yuvarlak ikon rozeti
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.18),
                    border: Border.all(
                        color: Colors.white.withOpacity(.35), width: 1),
                  ),
                  child: const Icon(Icons.sports_soccer,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),

                // metinler
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // küçük selamlama satırı
                      Text(greeting + ",",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          )),
                      const SizedBox(height: 2),
                      // isim: ana vurgu
                      Text(
                        firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // tagline (kısa ve temiz)
                      Row(
                        children: [
                          const Icon(Icons.flash_on_rounded,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text("Müsait saatleri keşfet, sahayı kap!",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget diamondDivider({
    Color color = const Color(0xFF94A3B8), // ana renk
    double thickness = 1.5, // çizgi kalınlığı
    double gap = 10, // elmas-çizgi arası boşluk
    double size = 10, // elmas köşegen uzunluğu
  }) {
    // Tek satırda çağırılabilir bölücüyü döndürür
    return Row(
      children: [
        // Sol çizgi (uccunda fade)
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withOpacity(0.0),
                  color,
                  color.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: gap),
        // Elmas
        Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: size,
            height: size,
            color: color,
          ),
        ),
        SizedBox(width: gap),
        // Sağ çizgi
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withOpacity(0.0),
                  color,
                  color.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget infoBanner({
    required BuildContext context,
    required String text,
    IconData icon = Icons.info,
    Color iconColor = const Color(0xFF3B82F6),
    Color gradientStart = const Color(0xFFF8FAFC),
    Color gradientEnd = const Color(0xFFE2E8F0),
    Color borderColor = const Color(0xFFD1D5DB),
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    double radius = 14,
    double fontSize = 15,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          // ikon rozet
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),

          // metin
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurBubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _actionRow(Person user, BuildContext context) {
    return Row(children: [
      _actionBtn(
        context: context,
        icon: Ionicons.calendar_outline,
        title: 'Rezervasyonlarım',
        buttonColors:
            LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserReservationsPage()),
        ),
      ),
      const SizedBox(width: 16),
      _actionBtn(
        context: context,
        icon: Ionicons.repeat_outline,
        title: 'Aboneliklerim',
        buttonColors: LinearGradient(
            colors: [AppColors.secondary, AppColors.secondaryDark]),
        onTap: (context) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SubscriptionDetailPage(currentUser: user)),
        ),
      ),
    ]);
  }

  Widget _actionBtn({
    required IconData icon,
    required String title,
    required void Function(BuildContext context) onTap,
    required BuildContext context,
    required LinearGradient buttonColors,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => onTap.call(context), // veya context
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(
              gradient: buttonColors,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 25),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
}
