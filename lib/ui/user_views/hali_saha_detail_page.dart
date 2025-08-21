// ignore_for_file: constant_identifier_names
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reviews.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/reservation_page.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';
import 'package:toplansin/ui/user_views/shared/widgets/minimap/mini_map_preview.dart';
import 'package:toplansin/ui/user_views/shared/widgets/text/expandable_text.dart';
import 'package:toplansin/ui/user_views/subscribe_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

/// ───────────────────────── THEME CONSTANTS ─────────────────────────
const Color kPrimary = Color(0xFF2EAC5B); // canlı çim yeşili
const Color kPrimaryDark = Color(0xFF0E7E36);
const Color kScaffoldBg = Color(0xFFF5F7F6); // açık gri arka plan
const Color kCardShadow = Color(0x14000000); // 8% siyah gölge
const double kCardRadius = 16.0;

/// ----------------------------------------------------------------------------
///                             DETAIL PAGE
/// ----------------------------------------------------------------------------
enum ReviewSortOption { newest, oldest, bestRated, worstRated }

ReviewSortOption selectedSort = ReviewSortOption.newest;

class HaliSahaDetailPage extends StatefulWidget {
  final HaliSaha haliSaha;
  final Person currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  HaliSahaDetailPage({
    super.key,
    required this.haliSaha,
    required this.currentUser,
  });

  @override
  State<HaliSahaDetailPage> createState() => _HaliSahaDetailPageState();
}

class _HaliSahaDetailPageState extends State<HaliSahaDetailPage> {
  final List<Reviews> reviewList = [];
  final TextEditingController _comment = TextEditingController();
  double _currentRating = 0;
  bool showAllReviews = false;

  @override
  void initState() {
    super.initState();
    _readReviews(widget.haliSaha.id);
  }

  // ───────────────────────── FIRESTORE HELPERS ─────────────────────────
  Future<void> _readReviews(String id) async {
    final col = FirebaseFirestore.instance
        .collection("hali_sahalar")
        .doc(id)
        .collection("reviews");

    final snap = await col.get();
    final uid = widget._auth.currentUser!.uid;
    final tmp = snap.docs.map(Reviews.fromDocument).toList();

    tmp.sort((a, b) {
      if (a.userId == uid && b.userId != uid) return -1;
      if (b.userId == uid && a.userId != uid) return 1;
      return b.datetime.compareTo(a.datetime);
    });
    setState(() => reviewList
      ..clear()
      ..addAll(tmp));
  }

  Future<void> _addReview(
      String newComment, double newRating, String userName) async {
    final user = widget._auth.currentUser;
    if (user == null) return;

    final Reviews r = Reviews(
      comment: newComment,
      rating: newRating,
      datetime: TimeService.now(),
      userId: user.uid,
      user_name: userName,
    );

    final docRef = await FirebaseFirestore.instance
        .collection("hali_sahalar")
        .doc(widget.haliSaha.id)
        .collection("reviews")
        .add(r.toJson());
    FocusScope.of(context).unfocus();

    setState(() {
      reviewList.insert(0, r.copyWith(docId: docRef.id));
    });
    _comment.clear();
    _currentRating = 0;
    AppSnackBar.success(context,"Yorumunuz başarıyla gönderildi.");
  }

  Future<void> _deleteReview(Reviews r) async {
    try {
      if (r.docId == null) return;
      await FirebaseFirestore.instance
          .collection("hali_sahalar")
          .doc(widget.haliSaha.id)
          .collection("reviews")
          .doc(r.docId)
          .delete();
      setState(() => reviewList.removeWhere((e) => e.docId == r.docId));
      AppSnackBar.show(context,"Yorum silindi.");
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'review');
      AppSnackBar.error(context,"Yorum silinemedi: $msg");
    }
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Arama başlatılamadı: $phone");
    }
  }

  // ────────────────────────────── UI ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    bool isPhone= widget._auth.currentUser?.phoneNumber?.isNotEmpty ?? false;

    final s = widget.haliSaha;
    return Scaffold(
      backgroundColor: kScaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP IMAGE GALLERY + BACK BUTTON ───
            _HeaderGallery(
              images: s.imagesUrl,
              onBack: () => Navigator.pop(context),
              onTapImage: _openImageViewer,
            ),

            // ─── MAIN CONTENT ───
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(kCardRadius)),
                ),
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopInfoCard(
                            s: s,
                            reviewCount: reviewList.length,
                            onCall: () => _callNumber(s.phone),
                          ),
                          const SizedBox(height: 20),
                          MiniMapPreview(
                            title: widget.haliSaha.name,
                              lat: widget.haliSaha.latitude,
                              lng: widget.haliSaha.longitude),
                          const SizedBox(height: 20),
                          _InfoTabs(s),
                          const SizedBox(height: 28),
                          _ReviewSummary(
                            ratingCounts: _calcRatingCounts(reviewList),
                            totalReviews: reviewList.length,
                            avg: s.rating.toDouble(),
                          ),
                          const SizedBox(height: 28),
                          _ReviewsSection(
                            reviews: reviewList,
                            showAll: showAllReviews,
                            onToggleShow: () => setState(
                                () => showAllReviews = !showAllReviews),
                            onSortChanged: (v) {
                              if (v != null) setState(() => selectedSort = v);
                            },
                            onDelete: _deleteReview,
                          ),
                          const SizedBox(height: 28),
                          _AddReviewSection(
                            controller: _comment,
                            currentRate: _currentRating,
                            onRate: (v) => setState(() => _currentRating = v),
                            onSubmit: () {
                              if (_currentRating == 0) {
                               AppSnackBar.warning(context,"Lütfen bir puanlama yapınız!");
                              } else {
                                _addReview(_comment.text, _currentRating,
                                    widget.currentUser.name);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                color: Colors.white,
                child: Column(
                  children: [
                    if (!isPhone)                     // sadece telefon onaysızsa
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade500, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Rezervasyon veya abonelik yapabilmek için '
                                    'telefon numaranı doğrulaman gerekiyor.',
                                style: AppTextStyles.bodyMedium.copyWith(color: Colors.orange.shade800,fontWeight: FontWeight.w600)
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 2,),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Fiyat Bölümü
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Saatlik fiyatı",
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 11
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.haliSaha.price} ₺",
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Abone Ol Butonu
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: isPhone ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubscribePage(halisaha: s,user:widget.currentUser,),
                                ),
                              );
                            }:null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:isPhone ? Colors.indigo.shade600 : Colors.indigo.shade200,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Abone Ol",
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Rezervasyon Butonu
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed:isPhone ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReservationPage(
                                      haliSaha: s,
                                      currentUser: widget.currentUser),
                                ),
                              );
                            }:null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:isPhone ? Colors.green.shade600 : Colors.grey.shade200,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Rezervasyon Yap",
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }






  // ────────────────────────── HELPERS ──────────────────────────
  void _openImageViewer(int initIndex) => showDialog(
        context: context,
        builder: (_) => _ImageViewer(
          images: widget.haliSaha.imagesUrl,
          initial: initIndex,
        ),
      );

  Map<int, int> _calcRatingCounts(List<Reviews> list) {
    final map = <int, int>{};
    for (final r in list) {
      final k = r.rating.toInt();
      map[k] = (map[k] ?? 0) + 1;
    }
    return map;
  }
}

/// ───────────────────────── COMPONENTS ─────────────────────────
class _HeaderGallery extends StatefulWidget {
  const _HeaderGallery({
    required this.images,
    required this.onBack,
    required this.onTapImage,
  });

  final List<String> images;
  final VoidCallback onBack;
  final void Function(int) onTapImage;

  @override
  State<_HeaderGallery> createState() => _HeaderGalleryState();
}

class _HeaderGalleryState extends State<_HeaderGallery> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final p = _ctrl.page?.round() ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ─── IMAGES ───
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.images.length,
            itemBuilder: (_, i) => GestureDetector(
                onTap: () => widget.onTapImage(i),
                child: /*──────────────── Kart Görseli (Progressive + Gradient) ───────────────*/
                    Stack(
                  fit: StackFit.expand,
                  children: [
                    /// Ana görsel – Progressive yükleyici
                    ProgressiveImage(
                      imageUrl: widget.images[i], // Firestore / Storage URL
                      fit: BoxFit.cover,
                      borderRadius: 0, // Köşe yuvarlama yoksa sıfır bırak
                      debugLog: false, // Log ihtiyacına göre aç/kapat
                    ),

                    /// Hafif alt‑geçiş gradyanı ( okunabilirliği artırır )
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black26],
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
          ),
        ),

        // ─── BLUR BACK BUTTON ───
        Positioned(
          top: 12,
          left: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: InkWell(
                onTap: widget.onBack,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ),

        // ─── PAGE INDICATOR ───
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── ACTION BUTTONS ─────────────────────────
/*class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onReserve, required this.onSubscribe});

  final VoidCallback onReserve, onSubscribe;

  ButtonStyle _style(Color c) => ElevatedButton.styleFrom(
        elevation: 3,
        backgroundColor: c,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
              style: _style(kPrimary),
              onPressed: onReserve,
              child: Text("Rezervasyon Yap")),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
              style: _style(Colors.blue.shade700),
              onPressed: onSubscribe,
              child: Text("Abone Ol")),
        ),
      ]);
}*/

// ───────────────────────── INFO TABS ─────────────────────────
class _InfoTabs extends StatelessWidget {
  const _InfoTabs(this.s);

  final HaliSaha s;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(
            labelColor: kPrimaryDark,
            unselectedLabelColor: Colors.grey,
            indicator: UnderlineTabIndicator(
              borderSide: const BorderSide(width: 3, color: kPrimaryDark),
              insets: const EdgeInsets.symmetric(horizontal: 16),
            ),
            tabs: const [Tab(text: "Bilgiler"), Tab(text: "Özellikler")],
          ),
          SizedBox(
            height: 210,
            child: TabBarView(children: [
              _InfoTab(s),
              _FeaturesTab(s),
            ]),
          ),
        ]),
      );
}

// ───────────────────────── INFO TAB ─────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab(this.s);

  final HaliSaha s;

  Widget _info(IconData ic, String title, String val) => Column(children: [
        Icon(ic, color: kPrimary, size: 26),
        const SizedBox(height: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: Colors.grey.shade700)),
      ]);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _info(Icons.grass, "Zemin", s.surface),
            _info(Icons.straighten, "Boyut", s.size),
            _info(Icons.group, "Max Oyuncu", "${s.maxPlayers}"),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _info(Icons.access_time, "Saatler", "${s.startHour}-${s.endHour}"),
            _info(Icons.monetization_on, "Ücret", "${s.price} ₺"),
          ]),
        ]),
      );
}

// ───────────────────────── FEATURES TAB ─────────────────────────
class _FeaturesTab extends StatelessWidget {
  const _FeaturesTab(this.s);

  final HaliSaha s;

  Widget _feat(IconData ic, String lbl) => Column(children: [
        Icon(ic, color: kPrimary, size: 30),
        const SizedBox(height: 4),
        Text(lbl, style: TextStyle(color: Colors.grey.shade700)),
      ]);

  @override
  Widget build(BuildContext context) {
    final feats = <Widget>[
      if (s.hasParking) _feat(Icons.local_parking, "Otopark"),
      if (s.hasShowers) _feat(Icons.shower, "Duş"),
      if (s.hasShoeRental) _feat(Icons.directions_run, "Ayakkabı"),
      if (s.hasCafeteria) _feat(Icons.local_cafe, "Kafeterya"),
      if (s.hasNightLighting) _feat(Icons.nightlight, "Aydınlatma"),
    ];
    if (feats.isEmpty) {
      return Center(
          child: Text("Ek özellik bulunmuyor.",
              style: TextStyle(color: Colors.grey.shade600)));
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        alignment: WrapAlignment.center,
        children: feats,
      ),
    );
  }
}

// ───────────────────────── REVIEW SUMMARY ─────────────────────────
class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.ratingCounts,
    required this.totalReviews,
    required this.avg,
  });

  final Map<int, int> ratingCounts;
  final int totalReviews;
  final double avg;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kullanıcı Değerlendirmesi",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kCardRadius),
              boxShadow: [
                BoxShadow(
                    color: kCardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 6))
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Row(children: [
              // ─── AVERAGE SCORE ───
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(avg.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDark,
                        height: 1)),
                const SizedBox(height: 6),
                RatingBarIndicator(
                  rating: avg,
                  itemBuilder: (_, __) =>
                      const Icon(Icons.star_rounded, color: Colors.amber),
                  itemSize: 20,
                ),
                const SizedBox(height: 4),
                Text("$totalReviews yorum",
                    style: TextStyle(color: Colors.grey.shade600)),
              ]),
              const Spacer(),
              // ─── DISTRIBUTION ───
              Column(
                children: List.generate(5, (i) {
                  final star = 5 - i;
                  final count = ratingCounts[star] ?? 0;
                  final ratio = totalReviews == 0 ? 0.0 : count / totalReviews;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 28,
                          child: Text("$star★",
                              style: TextStyle(color: Colors.grey.shade600))),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.grey.shade300,
                          color: kPrimaryDark,
                          minHeight: 8,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("$count",
                          style: TextStyle(color: Colors.grey.shade600)),
                    ]),
                  );
                }),
              ),
            ]),
          ),
        ],
      );
}

// ───────────────────────── REVIEWS SECTION ─────────────────────────
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.showAll,
    required this.onToggleShow,
    required this.onSortChanged,
    required this.onDelete,
  });

  final List<Reviews> reviews;
  final bool showAll;
  final VoidCallback onToggleShow;
  final ValueChanged<ReviewSortOption?> onSortChanged;
  final void Function(Reviews) onDelete;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (reviews.isEmpty) {
      return Center(
        child: Text("Henüz yorum yapılmamış.",
            style: TextStyle(color: Colors.grey.shade600)),
      );
    }

    /* ── 1. Kullanıcı yorumunu ayır ───────────────────────── */
    final userReviews = uid == null
        ? <Reviews>[]
        : reviews.where((r) => r.userId == uid).toList();
    final otherReviews = reviews.where((r) => r.userId != uid).toList();

    /* ── 2. Diğer yorumları seçilen sıralamaya göre sırala ── */
    switch (selectedSort) {
      case ReviewSortOption.newest:
        otherReviews.sort((a, b) => b.datetime.compareTo(a.datetime));
        break;
      case ReviewSortOption.oldest:
        otherReviews.sort((a, b) => a.datetime.compareTo(b.datetime));
        break;
      case ReviewSortOption.bestRated:
        otherReviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case ReviewSortOption.worstRated:
        otherReviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
    }

    /* ── 3. İki listeyi birleştir: önce kullanıcı, sonra diğerleri ── */
    final List<Reviews> sorted = [...userReviews, ...otherReviews];

    /* ── 4. Görüntülenecek kısmı belirle (ilk 3 veya tümü) ── */
    final visible = showAll ? sorted : sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /* ── Başlık + Sıralama menüsü ── */
        Row(
          children: [
            const Text("Yorumlar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            DropdownButtonHideUnderline(
              child: DropdownButton<ReviewSortOption>(
                value: selectedSort,
                icon: const Icon(Icons.sort, color: kPrimaryDark),
                onChanged: onSortChanged,
                items: [
                  DropdownMenuItem(
                      value: ReviewSortOption.newest,
                      child: Text("En yeni",
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w700))),
                  DropdownMenuItem(
                      value: ReviewSortOption.oldest,
                      child: Text("En eski",
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w700))),
                  DropdownMenuItem(
                      value: ReviewSortOption.bestRated,
                      child: Text("En iyi",
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w700))),
                  DropdownMenuItem(
                      value: ReviewSortOption.worstRated,
                      child: Text("En kötü", style: AppTextStyles.bodyLarge)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        /* ── Liste ── */
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          itemBuilder: (_, i) => _ReviewCard(
            review: visible[i],
            isOwner: visible[i].userId == uid,
            onDelete: () => onDelete(visible[i]),
          ),
        ),

        /* ── “Tümünü göster / gizle” butonu ── */
        if (reviews.length > 3)
          Center(
            child: TextButton(
              onPressed: onToggleShow,
              child: Text(
                showAll
                    ? "Yorumları gizle"
                    : "Tüm yorumları görüntüle (${reviews.length})",
                style: const TextStyle(color: kPrimaryDark),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── REVIEW CARD ─────────────────────────
class _ReviewCard extends StatelessWidget {
  const _ReviewCard(
      {required this.review, required this.isOwner, required this.onDelete});

  final Reviews review;
  final bool isOwner;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kCardRadius),
          border: isOwner
              ? Border(left: BorderSide(color: kPrimary, width: 4))
              : null,
          boxShadow: [
            BoxShadow(
                color: kCardShadow, blurRadius: 6, offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: kPrimary.withOpacity(.2),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _maskName(review.user_name ?? ''),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm', 'tr_TR')
                          .format(review.datetime),
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ]),
            ),
            if (isOwner)
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Ionicons.trash_outline,
                      color: Colors.red, size: 22))
          ]),
          const SizedBox(height: 8),
          RatingBarIndicator(
            rating: review.rating ?? 0,
            itemBuilder: (_, __) =>
                const Icon(Icons.star_rounded, color: Colors.amber),
            itemSize: 18,
          ),
          const SizedBox(height: 8),
          Text(review.comment,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
        ]),
      );

  static String _maskName(String n) {
    final parts = n.trim().split(' ');
    return parts
        .map((p) => p.length <= 2
            ? p[0] + '*'
            : p.substring(0, 2) + '*' * (p.length - 2))
        .join(' ');
  }
}

// ───────────────────────── ADD REVIEW ─────────────────────────
class _AddReviewSection extends StatelessWidget {
  const _AddReviewSection({
    required this.controller,
    required this.currentRate,
    required this.onRate,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final double currentRate;
  final ValueChanged<double> onRate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Yorum Yaz",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: "Deneyiminizi paylaşın...",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kCardRadius / 2),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            RatingBar.builder(
              initialRating: currentRate,
              minRating: 1,
              allowHalfRating: true,
              itemSize: 28,
              unratedColor: Colors.grey.shade300,
              itemBuilder: (_, __) =>
                  const Icon(Icons.star_rounded, color: Colors.amber),
              onRatingUpdate: onRate,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kCardRadius / 2)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text("Gönder",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      );
}

// ───────────────────────── FULLSCREEN IMAGE VIEWER ─────────────────────────
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.images, required this.initial, super.key});

  final List<String> images;
  final int initial;

  @override
  Widget build(BuildContext context) => Stack(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.black.withOpacity(0.7)),
        ),
        Center(
          child: PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Hero(
                tag: 'imageViewer_${images[i]}',
                // listede de aynı tag’i kullan
                child: ProgressiveImage(
                  imageUrl: images[i], // zorunlu
                  fit: BoxFit.contain, // çerçeveyi doldurmak yerine sığdır
                  borderRadius: 0, // tam ekran, yuvarlama yok
                  debugLog: false, // profil ederken true yap
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            iconSize: 32,
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        )
      ]);
}

// ───────────────────────── TOP INFO CARD v6 ─────────────────────────
class _TopInfoCard extends StatelessWidget {
  const _TopInfoCard({
    required this.s,
    required this.reviewCount,
    required this.onCall,
    Key? key,
  }) : super(key: key);

  final HaliSaha s;
  final int reviewCount;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    const double radius = 20;
    final muted = Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kPrimary.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── İsim: 2 satıra kadar sığ, taşarsa '...' ──
          Text(
            s.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleLarge,
          ),

          const SizedBox(height: 10),

          // ── Rating satırı: chip + ince gri yazı ──
          Row(children: [
            _RatingChip(rating: s.rating.toDouble(), count: reviewCount),
            const SizedBox(width: 8),
          ]),

          const SizedBox(height: 18),

          // ── Konum ──
          _InfoRow(icon: Icons.location_pin, text: s.location),

          if (s.phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onCall,
              child: _InfoRow(
                icon: Icons.phone,
                text: s.phone,
                linkStyle: true,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // ── İnce ayraç ──
          Container(height: 1, color: Colors.grey.withOpacity(.12)),

          const SizedBox(height: 16),

          // ── Açıklama ──
          ExpandableText(
            text: s.description,
            trimLength: 200,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w200),
            moreLabel: '...Devamını Oku',
            lessLabel: 'Daha Az Göster',
          ),
        ],
      ),
    );
  }
}

/// Rating chip’i - daha kompakt
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text("($count)",
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        ]),
      );
}

/// İkon + metin satırı
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.linkStyle = false,
  });

  final IconData icon;
  final String text;
  final bool linkStyle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryDark, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: linkStyle ? FontWeight.w600 : FontWeight.w500,
                color: linkStyle ? kPrimaryDark : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      );
}
