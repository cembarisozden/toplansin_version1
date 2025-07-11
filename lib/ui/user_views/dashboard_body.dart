import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/HomeProvider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/ui/user_views/favoriler_page.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
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
  List<HaliSaha> favoriteHaliSahalar=[];
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().init();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    favoriteHaliSahalar=context.watch<HomeProvider>().favoriteHaliSahalar;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
          ),
        ),
        child: Column(
          children: [
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
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: infoBanner(
                            context: context,
                            text:
                            'Hey kaptan, tüm abonelik ve rezervasyonlarını aşağıdan görüntüleyebilirsin, kontrol sende!',
                            icon: Ionicons.caret_down_outline,           // ister başka ikon
                            iconColor: AppColors.secondary,           // marka rengin
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
                          padding:const EdgeInsets.fromLTRB(20,20, 20, 0),
                          sliver:SliverToBoxAdapter(
                            child: infoBanner(
                                context: context,
                                text: "Hemen başla, müsait saatleri kaçırma!",
                                icon: Ionicons.football_outline
                            ),
                          ) ,
                        ),


                      SliverPadding(
                        padding:EdgeInsets.fromLTRB(20, 20, 20, 0) ,
                        sliver:SliverToBoxAdapter(
                          child:favoritesPitches(
                            favoriteHaliSahalar:favoriteHaliSahalar,
                            user: widget.user!,
                            onSeeAllTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => FavorilerPage(currentUser: widget.user!),
                              ));
                            },
                          ),
                        ) ,
                      ),
                      SliverPadding(
                        padding:EdgeInsets.fromLTRB(20, 20, 20, 0) ,
                        sliver:SliverToBoxAdapter(
                          child:trendPitches(
                            favoriteHaliSahalar:favoriteHaliSahalar,
                            user: widget.user!,
                            onSeeAllTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => FavorilerPage(currentUser: widget.user!),
                              ));
                            },
                          ),
                        ) ,
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ]
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget favoritesPitches({
    required List<HaliSaha> favoriteHaliSahalar,
    required VoidCallback onSeeAllTap,
    required Person user,
  }) {
    if (favoriteHaliSahalar.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
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
                ],
              ),
              GestureDetector(
                onTap: onSeeAllTap,
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: favoriteHaliSahalar.length,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              final saha = favoriteHaliSahalar[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HaliSahaDetailPage(
                          currentUser: user,
                          haliSaha: saha,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(saha.imagesUrl.first),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.25),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      children: [
                        // Blur kutusu arka plan
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                color: Colors.black.withOpacity(0.25),
                                child: Text(
                                  saha.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget trendPitches({
    required List<HaliSaha> favoriteHaliSahalar,
    required VoidCallback onSeeAllTap,
    required Person user,
  }) {
    if (favoriteHaliSahalar.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(Ionicons.flash, color: Colors.red, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Trendler',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onSeeAllTap,
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: favoriteHaliSahalar.length,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              final saha = favoriteHaliSahalar[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HaliSahaDetailPage(
                          currentUser: user,
                          haliSaha: saha,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(saha.imagesUrl.first),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.25),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      children: [
                        // Blur kutusu arka plan
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                color: Colors.black.withOpacity(0.25),
                                child: Text(
                                  saha.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _welcomeCard(String name) {
    const radius = 32.0;
    const iconSize = 72.0;
    final firstName = name
        .split(' ')
        .first;

    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment(-1, -1.2),
          end: Alignment(1.2, 1),
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: -40, right: -40, child: _blurBubble(140, .18)),
          Positioned(bottom: -20, right: 40, child: _blurBubble(90, .10)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white.withOpacity(.22),
                    border: Border.all(
                        color: Colors.white.withOpacity(.35), width: 1),
                  ),
                  child: const Icon(
                      Icons.sports_soccer, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hoş geldin,',
                          style: TextStyle(
                              color: Colors.white.withOpacity(.92),
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(firstName,
                          style: const TextStyle(
                            fontSize: 36,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.flash_on_rounded, size: 20,
                            color: Colors.amber),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Saha hazır, top hazır, peki ya sen?',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontSize: 14,
                                height: 1.3),
                          ),
                        ),
                      ]),
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
    Color  color     = const Color(0xFF94A3B8), // ana renk
    double thickness = 1.5,                     // çizgi kalınlığı
    double gap       = 10,                      // elmas-çizgi arası boşluk
    double size      = 10,                      // elmas köşegen uzunluğu
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
    required String   text,
    IconData          icon           = Icons.info,
    Color             iconColor      = const Color(0xFF3B82F6),
    Color             gradientStart  = const Color(0xFFF8FAFC),
    Color             gradientEnd    = const Color(0xFFE2E8F0),
    Color             borderColor    = const Color(0xFFD1D5DB),
    EdgeInsetsGeometry padding       =
    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    double            radius         = 14,
    double            fontSize       = 15,
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
        buttonColors:LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        onTap: (context) =>
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserReservationsPage()),
            ),
      ),
      const SizedBox(width: 16),
      _actionBtn(
        context: context,
        icon: Ionicons.repeat_outline,
        title: 'Aboneliklerim',
        buttonColors:LinearGradient(colors: [AppColors.secondary, AppColors.secondaryDark]),
        onTap: (context) =>
            Navigator.push(
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
                  Expanded(child:
                  Text(
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
