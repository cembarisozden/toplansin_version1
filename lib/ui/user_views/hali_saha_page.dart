import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/FavoritesProvider.dart';

import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';


class HaliSahaPage extends StatefulWidget {
  final Person currentUser;

  HaliSahaPage({required this.currentUser});

  @override
  State<HaliSahaPage> createState() => _HaliSahaPageState();
}

class _HaliSahaPageState extends State<HaliSahaPage> {
  /// Firestore koleksiyon referansı
  final collectionHaliSaha =
  FirebaseFirestore.instance.collection('hali_sahalar');

  /// Tüm halı sahaları (orijinal)
  List<HaliSaha> _allHaliSahalar = [];

  /// Arama sonucu gösterilecek liste
  List<HaliSaha> halisahalar = [];

  /// Realtime dinleme
  StreamSubscription<QuerySnapshot>? _haliSahaSubscription;

  /// Arama alanı
  final TextEditingController _searchController = TextEditingController();

  String? _selectedCity;
  DateTime? _selectedDate;
  String? _selectedHourRange;

  final List<String> cities = [
    'İzmir', 'İstanbul', 'Ankara', 'Bursa', 'Antalya'
  ];

  final List<String> hourRanges = [
    '18:00-19:00',
    '19:00-20:00',
    '20:00-21:00',
    '21:00-22:00',
    '22:00-23:00',
    '23:00-00:00',
  ];


  @override
  void initState() {
    super.initState();
    _setupRealtimeHaliSahaListener();
    _searchController.addListener(_filterHaliSahalar);
  }

  // ────────────────────────────────────────────────────────────
  void _setupRealtimeHaliSahaListener() {
    _haliSahaSubscription = collectionHaliSaha.snapshots().listen((snapshot) {
      final all = snapshot.docs
          .map((d) => HaliSaha.fromJson(d.data(), d.id))
          .toList();

      setState(() {
        _allHaliSahalar = all;
      });

      _filterHaliSahalar(); // arama kutusu varsa tekrar uygula
    });
  }

  void _filterHaliSahalar() {
    final query = _searchController.text.toLowerCase();

    List<HaliSaha> filtered = _allHaliSahalar.where((saha) {
      final nameMatch = saha.name.toLowerCase().contains(query);
      final locationMatch = saha.location.toLowerCase().contains(query);

      final cityMatch = _selectedCity == null || saha.location.contains(_selectedCity!);

      bool dateTimeMatch = true;
      if (_selectedDate != null && _selectedHourRange != null) {
        final dateStr = "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
        final formattedSlot = "$dateStr ${_selectedHourRange!}";
        dateTimeMatch = !saha.bookedSlots.contains(formattedSlot);
      }

      return (nameMatch || locationMatch) && cityMatch && dateTimeMatch;
    }).toList();

    setState(() => halisahalar = filtered);
  }


  @override
  void dispose() {
    _haliSahaSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Column(
          children: [
            // Arama kutusu
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Halı saha ara...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon:
                    Icon(Icons.search, color: Colors.grey.shade600),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  /// Şehir
                  Expanded(
                    child: _buildSelectionButton(
                      label: _selectedCity ?? "Şehir",
                      icon: Icons.location_city,
                      onTap: () => _showCitySelector(context),
                    ),
                  ),
                  const SizedBox(width: 8),

                  /// Tarih
                  Expanded(
                    child: _buildSelectionButton(
                      label: _selectedDate == null
                          ? "Tarih"
                          : "${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}",
                      icon: Icons.calendar_month,
                      onTap: () => _showFancyDatePicker(context),
                    ),
                  ),
                  const SizedBox(width: 8),

                  /// Saat
                  Expanded(
                    child: _buildSelectionButton(
                      label: _selectedHourRange ?? "Saat",
                      icon: Icons.access_time,
                      onTap: () => _showHourSelector(context),
                    ),
                  ),
                ],
              ),
            ),


            Expanded(child: _buildHaliSahaList()),
          ],
        ),
      ),
    );
  }


  Future<void> _showFancyDatePicker(BuildContext context) async {
    DateTime now = DateTime.now();
    DateTime firstDate = now;
    DateTime lastDate = now.add(const Duration(days: 7));
    DateTime pickedDate = _selectedDate ?? now;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 36, color: AppColors.primary),
              const SizedBox(height: 8),
              const Text(
                "Tarih Seç",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: CalendarDatePicker(
                  initialDate: pickedDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (value) {
                    pickedDate = value;
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 20,),
                  label: const Text("Onayla", style: TextStyle(fontSize: 16,color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() => _selectedDate = pickedDate);
                    _filterHaliSahalar();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Modern seçim butonu (ortak)
  Widget _buildSelectionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 180), // max genişlik limiti
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showCitySelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: cities.map((city) {
            return ListTile(
              title: Text(city),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedCity = city);
                _filterHaliSahalar();
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showHourSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: hourRanges.map((hr) {
            return ListTile(
              title: Text(hr),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedHourRange = hr);
                _filterHaliSahalar();
              },
            );
          }).toList(),
        );
      },
    );
  }



  // ────────────────────────────────────────────────────────────
  /// SAHA LİSTESİ
  Widget _buildHaliSahaList() {
    final favProv = context.watch<FavoritesProvider>();

    if (halisahalar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Aranan kritere uygun\nhalı saha bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedCity = null;
                    _selectedDate = null;
                    _selectedHourRange = null;
                  });
                  _filterHaliSahalar();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Ionicons.refresh_outline,color: Colors.white,),
                label: const Text("Filtreleri Temizle",style:TextStyle(fontSize: 16,color: Colors.white),),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      itemCount: halisahalar.length,
      separatorBuilder: (_, __) => const SizedBox(height: 11),
      itemBuilder: (context, index) {
        final saha = halisahalar[index];
        final isFav = favProv.isFavorite(saha.id);

        return GestureDetector(
          onTap: () => _openDetail(context, saha),
          child: Material(
            elevation: 6,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── GÖRSEL + BİLGİ BAR ─────────────────────────
                Stack(
                  children: [
                    Hero(
                      tag: 'saha_${saha.id}',
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          saha.imagesUrl.isNotEmpty
                              ? saha.imagesUrl.first
                              : 'https://via.placeholder.com/640x360?text=No+Image',
                          fit: BoxFit.cover,
                          loadingBuilder: (c, w, p) => p == null
                              ? w
                              : const Center(
                              child: CircularProgressIndicator(strokeWidth: 1.6)),
                        ),
                      ),
                    ),

                    // BLUR ALT BANT
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                            color: Colors.black.withOpacity(.35),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                        size: 18, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        saha.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${saha.rating.toStringAsFixed(1)} ★',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
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

                    // FİYAT ROZETİ
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _priceBadge(saha.price),
                    ),

                    // FAVORİ BUTON
                    Positioned(
                      top: 12,
                      right: 12,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => context.read<FavoritesProvider>().toggleFavorite(saha.id),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.82),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 120),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(isFav),
                              size: 22,
                              color: isFav ? Colors.redAccent : Colors.grey.shade600,
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
    );
  }


  // ────────────────────────────────────────────────────────────
  Widget _priceBadge(num fiyat) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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



  // ────────────────────────────────────────────────────────────
  void _openDetail(BuildContext ctx, HaliSaha saha) {
    Navigator.of(ctx).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            HaliSahaDetailPage(
              haliSaha: saha,
              currentUser: widget.currentUser,
            ),
        transitionsBuilder: (_, anim, __, child) => ScaleTransition(
          scale: Tween(begin: .94, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }
}
