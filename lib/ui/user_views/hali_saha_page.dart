import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/FavoritesProvider.dart';

import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/hali_saha_detail_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';

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
    'İzmir',
    'İstanbul',
    'Ankara',
    'Bursa',
    'Antalya'
  ];

  final List<String> hourRanges = List.generate(
    18,
    (i) {
      final start = i + 6; // 6’dan başla
      final end = start + 1; // 1 saat aralık
      final s0 = start.toString().padLeft(2, '0');
      final s1 = (end == 24 ? 0 : end).toString().padLeft(2, '0');
      return '$s0:00–$s1:00';
    },
  );


  @override
  void initState() {
    super.initState();
    _setupRealtimeHaliSahaListener();
    _searchController.addListener(_filterHaliSahalar);
  }

  // ────────────────────────────────────────────────────────────
  void _setupRealtimeHaliSahaListener() {
    _haliSahaSubscription = collectionHaliSaha.snapshots().listen((snapshot) {
      final all =
          snapshot.docs.map((d) => HaliSaha.fromJson(d.data(), d.id)).toList();

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

      final cityMatch =
          _selectedCity == null || saha.location.contains(_selectedCity!);

      bool dateTimeMatch = true;
      if (_selectedDate != null && _selectedHourRange != null) {
        final dateStr =
            "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
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
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Halı saha ara...',
                            hintStyle: AppTextStyles.bodyMedium,
                            prefixIcon: Icon(Ionicons.search_outline,
                                color: Colors.grey.shade600),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  SizedBox(
                    height: 50,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          // -> Circle yerine rectangle, radius'u 8 yaptık
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: InkWell(
                          // customBorder da aynı radius ile
                          borderRadius: BorderRadius.circular(15),
                          splashColor: AppColors.primary.withOpacity(0.3),
                          onTap: () => _showFilterPanel(context),
                          child: const Padding(
                            padding: EdgeInsets.all(15),
                            child: Icon(Ionicons.options_sharp,
                                color: AppColors.primaryDark, size: 20),
                          ),
                        ),
                      ),
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
    DateTime now = TimeService.now();
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
              const Icon(Ionicons.arrow_back_circle_outline),
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
                  icon: const Icon(Icons.check_rounded,
                      size: 20, color: Colors.white),
                  label: const Text("Onayla",
                      style: TextStyle(fontSize: 16, color: Colors.white)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Ionicons.refresh_outline,
                  color: Colors.white,
                ),
                label: const Text(
                  "Filtreleri Temizle",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
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
                      tag: 'saha_${saha.id}', // ↔ detay sayfasında aynı tag
                      child: AspectRatio(
                        aspectRatio: 16 / 9, // 16 : 9 oran sabit
                        child: ProgressiveImage(
                          imageUrl: saha.imagesUrl.isNotEmpty // ❌ ternary yok
                              ? saha.imagesUrl.first
                              : null, // boş bırakmak yeterli
                          fit: BoxFit.cover,
                          borderRadius: 0,
                        ),
                      ),
                    ),

                    // BLUR ALT BANT
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24)),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
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
                            duration: const Duration(milliseconds: 120),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
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
    );
  }

  // ────────────────────────────────────────────────────────────
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

  // ────────────────────────────────────────────────────────────
  void _openDetail(BuildContext ctx, HaliSaha saha) {
    Navigator.of(ctx).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => HaliSahaDetailPage(
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

  void _showFilterPanel(BuildContext context) {
    showModalBottomSheet(
      isDismissible: false,
      enableDrag: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.95,
          child: StatefulBuilder(
            builder: (ctx, setInner) {
              final timeSlots = List.generate(24, (i) => 0 + i)
                  .map((h) => '${h.toString().padLeft(2, '0')}:00')
                  .toList();

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        MediaQuery.of(ctx).viewInsets.bottom + 100,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Filtreler',
                                  style: AppTextStyles.titleLarge
                                      .copyWith(color: AppColors.primaryDark)),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: Icon(Ionicons.close_outline, size: 28),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ————— Şehir Seçimi —————
                          _buildCitySelector(setInner),
                          const SizedBox(height: 20),

                          // ————— Tarih Seçimi —————
                          _buildDateSelector(context),
                          const SizedBox(height: 20),

                          // ————— Saat Seçimi —————
                          _buildTimeSelector(setInner, timeSlots),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _filterHaliSahalar();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFF7043),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Uygula',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedCity = null;
                              _selectedDate = null;

                            });
                            _filterHaliSahalar();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Temizle',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


  Widget _buildCitySelector(void Function(void Function()) setInner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Şehir Seçin',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cities.map((city) {
            final sel = city == _selectedCity;
            return ChoiceChip(
              label: Text(city),
              selected: sel,
              onSelected: (_) => setInner(() => _selectedCity = city),
              selectedColor: AppColors.primary.withOpacity(0.2),
              backgroundColor: Colors.grey.shade100,
              labelStyle: sel
                  ? AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600)
                  : AppTextStyles.bodyMedium.copyWith(color: Colors.black87),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tarih Seçin',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            Navigator.pop(context);
            await _showFancyDatePicker(context);
            _showFilterPanel(context); // tekrar aç
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Ionicons.calendar, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  _selectedDate == null
                      ? 'Seçiniz'
                      : DateFormat('EEE, dd MMM', 'tr').format(_selectedDate!),
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: _selectedDate == null ? Colors.grey : Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(void Function(void Function()) setInner, List<String> timeSlots) {
    int? startIndex;
    int? endIndex;

    // Mevcut aralık varsa indekslerini bul
    if (_selectedHourRange != null) {
      final parts = _selectedHourRange!.split(' - ');
      if (parts.length == 2) {
        startIndex = timeSlots.indexOf(parts[0]);
        endIndex = timeSlots.indexOf(parts[1]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saat Aralığı Seçin',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: timeSlots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (c, i) {
              final slot = timeSlots[i];
              final isSelected = startIndex != null && endIndex != null && i >= startIndex! && i <= endIndex!;

              return GestureDetector(
                onTap: () {
                  setInner(() {
                    if (startIndex == null || endIndex != null) {
                      // Yeni başlangıç seç
                      startIndex = i;
                      endIndex = null;
                      _selectedHourRange = null;
                    } else {
                      // Yeni bitiş seç
                      endIndex = i;
                      if (startIndex! <= endIndex!) {
                        _selectedHourRange = '${timeSlots[startIndex!]} - ${timeSlots[endIndex!]}';
                      } else {
                        // Ters seçilirse swap
                        _selectedHourRange = '${timeSlots[endIndex!]} - ${timeSlots[startIndex!]}';
                        final temp = startIndex;
                        startIndex = endIndex;
                        endIndex = temp;
                      }
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: isSelected
                        ? LinearGradient(colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryDark.withOpacity(0.8),
                    ])
                        : null,
                    color: isSelected ? null : Colors.grey.shade200,
                    border: isSelected
                        ? Border.all(color: AppColors.primaryDark.withOpacity(0.7), width: 1)
                        : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      slot,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedHourRange != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Seçilen aralık: $_selectedHourRange',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryDark,
                )),
          ),
      ],
    );
  }




}
