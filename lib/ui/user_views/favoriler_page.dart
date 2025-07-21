import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/FavoritesProvider.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';

class FavorilerPage extends StatelessWidget {
  final Person currentUser;

  const FavorilerPage({Key? key, required this.currentUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favProv = context.watch<FavoritesProvider>();
    final favorites = favProv.favorites;

    return Scaffold(
      // ── APP BAR ────────────────────────────────────────────────────────────
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Favorilerim',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            )),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      // ── GÖVDE (aynı kart tasarımı) ────────────────────────────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: favorites.isEmpty
            ? Center(
                child: Text(
                  'Henüz favoriniz yok.',
                  style: TextStyle(
                      fontSize: 16, color: Colors.white.withOpacity(.8)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                itemCount: favorites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 11),
                itemBuilder: (context, index) {
                  final saha = favorites[index];
                  final isFav = favProv.isFavorite(saha.id);

                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HaliSahaDetailPage(
                          haliSaha: saha,
                          currentUser: currentUser,
                        ),
                      ),
                    ),
                    child: Material(
                      elevation: 6,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              // ── FOTO ───────────────────────────────────
                              Hero(
                                tag:
                                    'fav_${saha.id}', // detay sayfasında aynı tag
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ProgressiveImage(
                                    imageUrl: saha.imagesUrl
                                            .isNotEmpty // ❌ ternary yok
                                        ? saha.imagesUrl.first
                                        : null, // boş bırakmak yeterli
                                    fit: BoxFit.cover,
                                    borderRadius: 12,
                                  ),
                                ),
                              ),
                              // ── ALT BLUR BAR ─────────────────────────
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(24)),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 18, sigmaY: 18),
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 10, 20, 14),
                                      color: Colors.black.withOpacity(.35),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            saha.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  size: 18,
                                                  color: Colors.white70),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  saha.location,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${saha.rating.toStringAsFixed(1)} ★',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ── FİYAT ROZETİ ─────────────────────────
                              Positioned(
                                top: 14,
                                left: 14,
                                child: _priceBadge(saha.price),
                              ),

                              // ── FAVORİ BUTON ─────────────────────────
                              Positioned(
                                top: 12,
                                right: 12,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => context
                                      .read<FavoritesProvider>()
                                      .toggleFavorite(saha.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.82),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 120),
                                      child: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        key: ValueKey(isFav),
                                        size: 22,
                                        color: isFav
                                            ? Colors.redAccent
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // Kartlarda kullanılan fiyat rozeti
  Widget _priceBadge(num fiyat) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF43A047).withOpacity(.65),
                width: 1.4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              '₺$fiyat',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      );
}
