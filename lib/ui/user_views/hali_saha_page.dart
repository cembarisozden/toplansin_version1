import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  final Person? currentUser;

  HaliSahaPage({this.currentUser});

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
  int? _startHour;
  int? _endHour;
  bool hasParking = false;
  bool hasShowers = false;
  bool hasShoeRental = false;
  bool hasCafeteria = false;
  bool hasNightLighting = false;
  bool hasMaleToilet = false;
  bool hasFoodService = false;
  bool acceptsCreditCard = false;
  bool hasFoosball = false;
  bool hasCameras = false;
  bool hasGoalkeeper = false;
  bool hasPlayground = false;
  bool hasPrayerRoom = false;
  bool hasInternet = false;
  bool hasFemaleToilet = false;

// State içinde
  num _minPrice = 0, _maxPrice = 5000;
  num _selectedMinPrice = 0, _selectedMaxPrice = 5000;
  bool _priceFilterActive = false;
  int _selectedRating = 0;

  // ── ekle
  late final FocusNode _searchFocus;
  final _searchHeaderKey = const ValueKey('search_header');
  List<HaliSaha> _baseFiltered = []; // diğer filtrelerin sonucu (isim hariç)
  final ValueNotifier<String> _searchText =
      ValueNotifier<String>(''); // sadece arama metni

  final List<String> cities = [
    'İzmir',
    'İstanbul',
    'Ankara',
    'Bursa',
    'Antalya'
  ];

  @override
  void initState() {
    super.initState();
    _startHour = null;
    _endHour = null;

    _searchFocus = FocusNode();

    _setupRealtimeHaliSahaListener();
  }

  // ────────────────────────────────────────────────────────────
  void _setupRealtimeHaliSahaListener() {
    _haliSahaSubscription = collectionHaliSaha.snapshots().listen((snapshot) {
      final all =
          snapshot.docs.map((d) => HaliSaha.fromJson(d.data(), d.id)).toList();

      if (!listEquals(_allHaliSahalar, all)) {
        setState(() => _allHaliSahalar = all);
        _recomputeBaseFiltered(); // isim aramasına dokunmuyor
      }
    });
  }

  /// Gece geçişlerini de hesaba katarak bir saatin saha açık olup olmadığını döner.
  bool isOpenAt(int hour, int openingHour, int closingHourNormalized) {
    // hour: 0-23, openingHour 0-23, closingHourNormalized ∈ [1..47]
    int normalizedHour = hour;
    if (hour < openingHour) normalizedHour += 24;
    return normalizedHour >= openingHour &&
        normalizedHour < closingHourNormalized;
  }

  bool _matchesFacilities(HaliSaha saha) {
    if (hasParking && !saha.hasParking) return false;
    if (hasShowers && !saha.hasShowers) return false;
    if (hasShoeRental && !saha.hasShoeRental) return false;
    if (hasCafeteria && !saha.hasCafeteria) return false;
    if (hasNightLighting && !saha.hasNightLighting) return false;
    if (hasMaleToilet && !saha.hasMaleToilet) return false;
    if (hasFemaleToilet && !saha.hasFemaleToilet) return false;
    if (hasFoodService && !saha.hasFoodService) return false;
    if (acceptsCreditCard && !saha.acceptsCreditCard) return false;
    if (hasFoosball && !saha.hasFoosball) return false;
    if (hasCameras && !saha.hasCameras) return false;
    if (hasGoalkeeper && !saha.hasGoalkeeper) return false;
    if (hasPlayground && !saha.hasPlayground) return false;
    if (hasPrayerRoom && !saha.hasPrayerRoom) return false;
    if (hasInternet && !saha.hasInternet) return false;
    return true;
  }

  // TÜM filtreler (isim/konum HARİÇ)
  void _recomputeBaseFiltered() {
    final hasCity = _selectedCity != null;
    final hasDate = _selectedDate != null;
    final hasTime = _startHour != null && _endHour != null;
    final hasPrice = _priceFilterActive;
    final hasRating = _selectedRating > 0;

    final df = DateFormat('yyyy-MM-dd');
    final today = TimeService.now();
    final dateStr = hasDate ? df.format(_selectedDate!) : null;

    // Filtre yoksa → tüm liste
    if (!hasCity &&
        !hasDate &&
        !hasTime &&
        !hasParking &&
        !hasShowers &&
        !hasShoeRental &&
        !hasCafeteria &&
        !hasNightLighting &&
        !hasMaleToilet &&
        !hasFemaleToilet &&
        !hasFoodService &&
        !acceptsCreditCard &&
        !hasFoosball &&
        !hasCameras &&
        !hasGoalkeeper &&
        !hasPlayground &&
        !hasPrayerRoom &&
        !hasInternet &&
        !hasPrice &&
        !hasRating) {
      if (!listEquals(_baseFiltered, _allHaliSahalar)) {
        setState(() {
          _baseFiltered = List.from(_allHaliSahalar);
          halisahalar =
              List.from(_allHaliSahalar); // kritik: ekranda görünen liste
        });
      }
      return;
    }

    int reqStart = hasTime ? _startHour! : 6;
    int reqEnd = hasTime ? _endHour! : 24;
    if (reqEnd <= reqStart) reqEnd += 24;

    final List<HaliSaha> result = [];
    for (final saha in _allHaliSahalar) {
      // Şehir filtresi (case-insensitive, konumu içeriyorsa)
      if (hasCity &&
          !saha.location.toLowerCase().contains(_selectedCity!.toLowerCase())) {
        continue;
      }
      if (!_matchesFacilities(saha)) continue;

      if (hasPrice) {
        if (saha.price < _selectedMinPrice || saha.price > _selectedMaxPrice) {
          continue;
        }
      }
      if (hasRating && saha.rating < _selectedRating) continue;

      final openH = int.parse(saha.startHour.split(':')[0]);
      final rawClose = int.parse(saha.endHour.split(':')[0]);
      final closeH = rawClose <= openH ? rawClose + 24 : rawClose;

      bool anyFree = false;
      final daysToCheck = hasDate ? 1 : 7;
      for (var d = 0; d < daysToCheck && !anyFree; d++) {
        final baseDate =
            hasDate ? df.parse(dateStr!) : today.add(Duration(days: d));
        for (var h = reqStart; h < reqEnd; h++) {
          final slotHour = h % 24;
          final dayOffset = h ~/ 24;
          final slotDate = baseDate.add(Duration(days: dayOffset));

          int normHour = slotHour < openH ? slotHour + 24 : slotHour;
          if (normHour < openH || normHour >= closeH) continue;

          final dayStr = df.format(slotDate);
          final slot = '$dayStr ${slotHour.toString().padLeft(2, '0')}:00-'
              '${(slotHour + 1).toString().padLeft(2, '0')}:00';

          final isBooked = saha.bookedSlots.any(
            (bs) => bs.replaceAll('–', '-').trim() == slot,
          );
          if (!isBooked) {
            anyFree = true;
            break;
          }
        }
      }
      if (!anyFree) continue;

      result.add(saha);
    }

    if (!listEquals(_baseFiltered, result)) {
      setState(() {
        _baseFiltered = result;
        halisahalar = result; // kritik: ekranda görünen liste
      });
    }
  }

// SADECE isim/konum araması (state dokunmadan hesap döner)
  List<HaliSaha> _applyNameSearch(List<HaliSaha> source, String queryRaw) {
    final q = queryRaw.toLowerCase().trim();
    if (q.isEmpty) return source;
    return source.where((saha) {
      return saha.name.toLowerCase().contains(q) ||
          saha.location.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _haliSahaSubscription?.cancel();
    _searchFocus.dispose();
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
              child: RepaintBoundary(
                // header stabilize
                key: _searchHeaderKey,
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(25),
                          child: TextField(
                            key: const ValueKey('search_field'),
                            controller: _searchController,
                            focusNode: _searchFocus,
                            textInputAction: TextInputAction.search,
                            // İSİM ARAMASI: sadece ValueNotifier'ı güncelle
                            onSubmitted: (_) =>
                                _searchText.value = _searchController.text,
                            // onTapOutside: (_) => _searchFocus.unfocus(), // istersen kapalı kalsın
                            decoration: InputDecoration(
                              hintText: 'Halı saha ara...',
                              hintStyle: AppTextStyles.bodyLarge,
                              prefixIcon: Icon(
                                Ionicons.search_outline,
                                color: Colors.grey.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 50,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Ink(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            splashColor: AppColors.primary.withOpacity(0.3),
                            onTap: () => _showFilterPanel(context),
                            child: const Padding(
                              padding: EdgeInsets.all(15),
                              child: Icon(
                                Ionicons.options_sharp,
                                color: Colors.white,
                                size: 25,
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
                    _recomputeBaseFiltered();
                  },
                ),
              ),
              SizedBox(
                height: 6,
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.arrow_back_ios_new,
                      size: 20, color: AppColors.textPrimary),
                  label: Text("Geri",
                      style: TextStyle(
                          fontSize: 16, color: AppColors.textPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
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
  Widget _buildHaliSahaList() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (_, textValue, __) {
        final query = textValue.text.trim().toLowerCase();

        // Görünüm: isim/konum araması yalnızca UI’da uygulanır
        final List<HaliSaha> view = query.isEmpty
            ? _baseFiltered
            : _applyNameSearch(_baseFiltered, query);

        if (view.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
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
                        // _searchController.clear(); // arama metnini korumak istersen kapalı kalsın
                        _selectedCity = null;
                        _selectedDate = null;
                        _startHour = null;
                        _endHour = null;
                        hasParking = false;
                        hasShowers = false;
                        hasShoeRental = false;
                        hasCafeteria = false;
                        hasNightLighting = false;
                        hasMaleToilet = false;
                        hasFemaleToilet = false;
                        hasFoodService = false;
                        acceptsCreditCard = false;
                        hasFoosball = false;
                        hasCameras = false;
                        hasGoalkeeper = false;
                        hasPlayground = false;
                        hasPrayerRoom = false;
                        hasInternet = false;
                        _selectedMinPrice = _minPrice;
                        _selectedMaxPrice = _maxPrice;
                        _priceFilterActive = false;
                        _selectedRating = 0;
                      });
                      _recomputeBaseFiltered();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Ionicons.refresh_outline,
                        color: Colors.white),
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          itemCount: view.length,
          separatorBuilder: (_, __) => const SizedBox(height: 11),
          itemBuilder: (context, index) {
            final saha = view[index];

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
                        Stack(
                          children: [
                            Hero(
                              tag: 'saha_${saha.id}',
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ProgressiveImage(
                                  imageUrl: saha.imagesUrl.isNotEmpty
                                      ? saha.imagesUrl.first
                                      : null,
                                  fit: BoxFit.cover,
                                  borderRadius: 0,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(24)),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
                                          style: AppTextStyles.titleMedium
                                              .copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 19,
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
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                        color: Colors.white),
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
                            Positioned(
                                top: 14,
                                left: 14,
                                child: _priceBadge(saha.price)),
                            // ✅ Favori sadece oturum varken
                            if (widget.currentUser != null)
                              if (widget.currentUser != null)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Consumer<FavoritesProvider>(
                                    builder: (_, favProv, __) {
                                      final isFav = favProv.isFavorite(saha.id);
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        onTap: () =>
                                            favProv.toggleFavorite(saha.id),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(.82),
                                            shape: BoxShape.circle,
                                          ),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(
                                                milliseconds: 120),
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
                                      );
                                    },
                                  ),
                                ),
                          ],
                        ),
                      ]),
                ));
          },
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
                          _buildTimeSelector(setInner),
                          const SizedBox(height: 40),
                          _buildFacilitiesSelector(setInner),
                          const SizedBox(height: 40),
                          _buildPriceSelector(setInner),
                          const SizedBox(height: 40),
                          _buildRatingSelector(setInner),
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
                            _recomputeBaseFiltered();
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
                              _startHour = null;
                              _endHour = null;
                              hasParking = false;
                              hasShowers = false;
                              hasShoeRental = false;
                              hasCafeteria = false;
                              hasNightLighting = false;
                              hasMaleToilet = false;
                              hasFemaleToilet = false;
                              hasFoodService = false;
                              acceptsCreditCard = false;
                              hasFoosball = false;
                              hasCameras = false;
                              hasGoalkeeper = false;
                              hasPlayground = false;
                              hasPrayerRoom = false;
                              hasInternet = false;
                              _selectedMinPrice = _minPrice;
                              _selectedMaxPrice = _maxPrice;
                              _priceFilterActive = false;
                              _selectedRating = 0;
                            });
                            _recomputeBaseFiltered();
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
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
                        : AppTextStyles.bodyMedium
                            .copyWith(color: Colors.black87),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tarih Seçin',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.primaryDark)),
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
                      color:
                          _selectedDate == null ? Colors.grey : Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(void Function(void Function()) setInner) {
    const double minHour = 0.0, maxHour = 24.0;

// Eğer null ise minHour, null ise maxHour
    final double start = _startHour?.toDouble() ?? minHour;
    final double end = _endHour?.toDouble() ?? maxHour;

    String fmt(double v) => '${v.toInt().toString().padLeft(2, '0')}:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saat Aralığı',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHourBox(fmt(start)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
            const SizedBox(width: 8),
            _buildHourBox(fmt(end)),
          ],
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: RangeValues(start, end),
          min: minHour,
          max: maxHour,
          divisions: (maxHour - minHour).toInt(),
          labels: RangeLabels(fmt(start), fmt(end)),
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade300,
          onChanged: (values) {
            if (values.end - values.start >= 1) {
              setInner(() {
                _startHour = values.start.toInt();
                _endHour = values.end.toInt();
              });
              // anında filtre uygula
              _recomputeBaseFiltered();
            }
          },
        ),
      ],
    );
  }

  Widget _buildHourBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  /// Filtre panelindeki “Tesis İmkânları” bölümünü oluşturur.
  Widget _buildFacilitiesSelector(void Function(void Function()) setInner) {
    final facilities = [
      {
        'label': 'Otopark',
        'value': hasParking,
        'setter': (bool v) => hasParking = v
      },
      {
        'label': 'Duş',
        'value': hasShowers,
        'setter': (bool v) => hasShowers = v
      },
      {
        'label': 'Kiralık Krampon',
        'value': hasShoeRental,
        'setter': (bool v) => hasShoeRental = v
      },
      {
        'label': 'Kafeterya',
        'value': hasCafeteria,
        'setter': (bool v) => hasCafeteria = v
      },
      {
        'label': 'Gece Aydınlatma',
        'value': hasNightLighting,
        'setter': (bool v) => hasNightLighting = v
      },
      {
        'label': 'Erkek Tuvaleti',
        'value': hasMaleToilet,
        'setter': (bool v) => hasMaleToilet = v
      },
      {
        'label': 'Kadın Tuvaleti',
        'value': hasFemaleToilet,
        'setter': (bool v) => hasFemaleToilet = v
      },
      {
        'label': 'Yemek Servisi',
        'value': hasFoodService,
        'setter': (bool v) => hasFoodService = v
      },
      {
        'label': 'Kredi Kartı',
        'value': acceptsCreditCard,
        'setter': (bool v) => acceptsCreditCard = v
      },
      {
        'label': 'Langırt',
        'value': hasFoosball,
        'setter': (bool v) => hasFoosball = v
      },
      {
        'label': 'Kamera',
        'value': hasCameras,
        'setter': (bool v) => hasCameras = v
      },
      {
        'label': 'Kaleci Kiralama',
        'value': hasGoalkeeper,
        'setter': (bool v) => hasGoalkeeper = v
      },
      {
        'label': 'Oyun Alanı',
        'value': hasPlayground,
        'setter': (bool v) => hasPlayground = v
      },
      {
        'label': 'İbadet Alanı',
        'value': hasPrayerRoom,
        'setter': (bool v) => hasPrayerRoom = v
      },
      {
        'label': 'İnternet',
        'value': hasInternet,
        'setter': (bool v) => hasInternet = v
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tesis İmkânları',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: facilities.map((f) {
                  final sel = f['value'] as bool;
                  return ChoiceChip(
                    label: Text(f['label'] as String),
                    selected: sel,
                    onSelected: (v) => setInner(() {
                      (f['setter'] as void Function(bool))(v);
                    }),
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: sel
                        ? AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600)
                        : AppTextStyles.bodyMedium
                            .copyWith(color: Colors.black87),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSelector(void Function(VoidCallback) setInner) {
    String fmtPrice(num p) => '₺${p.toInt()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fiyat Aralığı',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fmtPrice(_selectedMinPrice)),
            Text(fmtPrice(_selectedMaxPrice)),
          ],
        ),
        RangeSlider(
          values: RangeValues(
              _selectedMinPrice.toDouble(), _selectedMaxPrice.toDouble()),
          min: _minPrice.toDouble(),
          max: _maxPrice.toDouble(),
          divisions: (_maxPrice - _minPrice).toInt(),
          labels: RangeLabels(
              fmtPrice(_selectedMinPrice), fmtPrice(_selectedMaxPrice)),
          activeColor: AppColors.primary,
          inactiveColor: Colors.grey.shade300,
          onChanged: (values) {
            if (values.end - values.start >= 50) {
              setInner(() {
                _selectedMinPrice = values.start;
                _selectedMaxPrice = values.end;
                _priceFilterActive = true; // <-- kullanıcı oynadı
              });
              _recomputeBaseFiltered();
            }
          },
        ),
      ],
    );
  }

  Widget _buildRatingSelector(void Function(VoidCallback) setInner) {
    // 0: tümü, 1..5: en az o yıldız
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Minimum Puan',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Wrap(
                spacing: 8,
                children: List.generate(6, (i) {
                  final label = i == 0
                      ? 'Tümü'
                      : List.generate(i, (_) => Icon(Icons.star, size: 16))
                          .fold<Widget>(SizedBox(), (row, star) {
                          if (row is SizedBox) return Row(children: [star]);
                          return Row(
                              children: [...(row as Row).children, star]);
                        });
                  final sel = _selectedRating == i;
                  return ChoiceChip(
                    label: i == 0
                        ? Text(label.toString())
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                                i,
                                (_) => Icon(Icons.star,
                                    size: 16,
                                    color: sel ? Colors.amber : Colors.grey))),
                    selected: sel,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    onSelected: (_) => setInner(() => _selectedRating = i),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: sel
                        ? AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600)
                        : AppTextStyles.bodyMedium
                            .copyWith(color: Colors.black87),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
