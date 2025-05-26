import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reviews.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/reservation_page.dart';
import 'package:toplansin/ui/user_views/subscribe_page.dart';
import 'package:url_launcher/url_launcher.dart';

enum ReviewSortOption {
  newest,
  oldest,
  bestRated,
  worstRated,
}

ReviewSortOption selectedSort = ReviewSortOption.newest;

class HaliSahaDetailPage extends StatefulWidget {
  final HaliSaha haliSaha;
  final Person currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  HaliSahaDetailPage({required this.haliSaha, required this.currentUser});

  @override
  _HaliSahaDetailPageState createState() => _HaliSahaDetailPageState();
}

class _HaliSahaDetailPageState extends State<HaliSahaDetailPage> {
  List<Reviews> reviewList = [];
  final TextEditingController _commentController = TextEditingController();
  double _currentRating = 0;

  bool showAllReviews = false;

  Future<void> addReview(
      String haliSahaId,
      String newComment,
      double newRating,
      String userName,
      ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    Reviews newReview = Reviews(
      comment: newComment,
      rating: newRating,
      datetime: TimeService.now(),
      userId: currentUser.uid,         // 🔐 Güvenli UID
      user_name: userName,
    );

    var collectionReviews = FirebaseFirestore.instance
        .collection("hali_sahalar")
        .doc(haliSahaId)
        .collection("reviews");

    await collectionReviews.add(newReview.toJson());

    setState(() {
      reviewList.add(newReview);
    });

    _commentController.clear();
    _currentRating = 0;

  }


  Future<void> readReview(String haliSahaId) async {
    var collectionReviews = FirebaseFirestore.instance
        .collection("hali_sahalar")
        .doc(haliSahaId)
        .collection("reviews");

    var querySnapshot = await collectionReviews.get();
    List<Reviews> tempList = [];

    for (var doc in querySnapshot.docs) {
      Reviews review = Reviews.fromDocument(doc);
      tempList.add(review);
    }

    // Burada sıralamayı yapıyoruz.
    // 1) Oturum açmış kullanıcının yorumları önce,
    // 2) Daha sonra diğer kullanıcıların yorumları,
    // 3) Kendi içlerinde tarihe göre (en yeni -> en eski)
    final currentUserId = widget._auth.currentUser!.uid;
    tempList.sort((a, b) {
      if (a.userId == currentUserId && b.userId != currentUserId) {
        return -1;
      } else if (b.userId == currentUserId && a.userId != currentUserId) {
        return 1;
      }

      return b.datetime.compareTo(a.datetime);
    });

    setState(() {
      reviewList = tempList;
    });
  }

  @override
  void initState() {
    super.initState();
    readReview(widget.haliSaha.id);
  }

  /// Dialog ile tam ekran resim gösteren fonksiyon.
  /// Hero tag'ini "imageViewer_$initialIndex" yapıyoruz.
  void _openImageViewer(int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black54),
            ),
            Center(
              child: Hero(
                tag: "imageViewer_$initialIndex", // DİNAMİK TAG
                child: Material(
                  color: Colors.transparent,
                  child: PageView.builder(
                    controller: PageController(initialPage: initialIndex),
                    itemCount: widget.haliSaha.imagesUrl.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {},
                        child: InteractiveViewer(
                          child: Image.network(
                            widget.haliSaha.imagesUrl[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade300,
                                alignment: Alignment.center,
                                child: Icon(Icons.broken_image,
                                    color: Colors.grey.shade600, size: 40),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final haliSaha = widget.haliSaha;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Üstte resim galerisi ve geri tuşu
            Stack(
              children: [
                _buildImageGallery(),
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(haliSaha),
                      if (haliSaha.phone.isNotEmpty)
                        GestureDetector(
                          onTap: () => _callNumber(haliSaha.phone),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                SizedBox(width: 4),
                                Icon(Icons.phone, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  haliSaha.phone,
                                  style: TextStyle(
                                      color: Colors.grey[700],
                                      height: 1.4,
                                      fontSize: 14,
                                      letterSpacing: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: 16),
                      Text(
                        haliSaha.description,
                        style: TextStyle(
                            color: Colors.grey[700], height: 1.4, fontSize: 14),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReservationPage(
                                        haliSaha: haliSaha,
                                        currentUser: widget.currentUser,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  elevation: 2,
                                ),
                                child: Text(
                                  "Rezervasyon Yap",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                            SizedBox(height: 12), // Düğmeler arası boşluk

                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.9,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SubscribePage(
                                        halisaha: haliSaha,
                                        user: widget.currentUser,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  elevation: 2,
                                ),
                                child: Text(
                                  "Abone Ol",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildInfoAndFeaturesTabs(haliSaha),
                      SizedBox(height: 24),
                      _buildReviewSummary(
                        context: context,
                        ratingCounts: _calculateRatingCounts(reviewList),
                        totalReviews: reviewList.length,
                        averageRating: widget.haliSaha.rating.toDouble(),
                      ),
                      SizedBox(height: 24),
                      _buildReviewsSection(),
                      SizedBox(height: 24),
                      _buildAddReviewSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSummary({
    required BuildContext context,
    required Map<int, int> ratingCounts,
    required int totalReviews,
    required double averageRating,
  }) {
    // Tema renkleri
    const primary = Color(0xFF2EAC5B); // canlı yeşil (futbol sahası rengi)
    const secondary = Color(0xFFFFC107); // sarı-altın (yıldızlar için)
    const surface = Colors.white; // kart arka planı
    const onSurface = Colors.black; // yazılar
    final mutedGrey = onSurface.withOpacity(0.6); // gri yazı

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Kullanıcı Değerlendirmesi",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), // araya boşluk koyar

      // Asıl container burada
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────────── Ortalama Puan ─────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rakam + yıldızlar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Büyük puan
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Yıldız ikonları
                    Row(
                      children: List.generate(
                        5,
                        (i) {
                          final diff = averageRating - i;
                          IconData icon;
                          if (diff >= 1) {
                            icon = Icons.star_rounded;
                          } else if (diff >= 0.5) {
                            icon = Icons.star_half_rounded;
                          } else {
                            icon = Icons.star_border_rounded;
                          }
                          return Icon(icon, size: 20, color: secondary);
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Toplam yorum
                    Text(
                      "$totalReviews yorum",
                      style: TextStyle(fontSize: 13, color: mutedGrey),
                    ),
                  ],
                ),

                const Spacer(),

                // Şık review ikonu
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surface,
                  ),
                  child: Icon(Icons.reviews, size: 45, color: primary),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ───────────── Dağılım Çubukları ─────────────
            ...List.generate(5, (index) {
              final star = 5 - index;
              final count = ratingCounts[star] ?? 0;
              final ratio = totalReviews == 0 ? 0.0 : count / totalReviews;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        "$star★",
                        style: TextStyle(fontSize: 13, color: mutedGrey),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Gradient bar
                    Expanded(
                      child: Stack(
                        children: [
                          // Arka plan
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: onSurface.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          // Dolgu
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    primary,
                                    primary.withOpacity(0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),
                    Text(
                      "$count",
                      style: TextStyle(fontSize: 13, color: mutedGrey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      )
    ]);
  }

  Map<int, int> _calculateRatingCounts(List<Reviews> reviews) {
    final Map<int, int> counts = {};
    for (var review in reviews) {
      counts[review.rating.toInt()] = (counts[review.rating] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Arama başlatılamadı: $phone");
    }
  }

  /// Galeri kısmını inşa ediyoruz.
  /// Her görsele "imageViewer_$index" gibi benzersiz bir Hero tag veriyoruz.
  Widget _buildImageGallery() {
    return Container(
      height: 200,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        itemCount: widget.haliSaha.imagesUrl.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openImageViewer(index),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              child: Hero(
                tag: "imageViewer_$index", // DİNAMİK TAG
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.haliSaha.imagesUrl[index],
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image,
                            color: Colors.grey.shade600, size: 40),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderInfo(HaliSaha haliSaha) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          haliSaha.name,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.star, color: Colors.yellow[700], size: 20),
            SizedBox(width: 4),
            Text(haliSaha.rating.toStringAsFixed(1),
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text(
              "(${reviewList.length} değerlendirme)",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                haliSaha.location,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoAndFeaturesTabs(HaliSaha haliSaha) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Bilgiler"),
              Tab(text: "Özellikler"),
            ],
          ),
          SizedBox(
            height: 200,
            child: TabBarView(
              children: [
                _buildInfoTab(haliSaha),
                _buildFeaturesTab(haliSaha),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(HaliSaha haliSaha) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildInfoColumn(Icons.grass, "Zemin", haliSaha.surface),
            _buildInfoColumn(Icons.straighten, "Boyut", haliSaha.size),
            _buildInfoColumn(
                Icons.group, "Max Oyuncu", haliSaha.maxPlayers.toString()),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildInfoColumn(Icons.access_time, "Saatler",
                "${haliSaha.startHour}-${haliSaha.endHour}"),
            _buildInfoColumn(
                Icons.monetization_on, "Ücret", "${haliSaha.price} TL"),
          ]),
        ],
      ),
    );
  }

  Widget _buildFeaturesTab(HaliSaha haliSaha) {
    List<Widget> featureIcons = [];

    if (haliSaha.hasParking) {
      featureIcons.add(_featureIcon(Icons.local_parking, "Otopark"));
    }
    if (haliSaha.hasShowers) {
      featureIcons.add(_featureIcon(Icons.shower, "Duş"));
    }
    if (haliSaha.hasShoeRental) {
      featureIcons.add(_featureIcon(Icons.directions_run, "Ayakkabı Kiralama"));
    }
    if (haliSaha.hasCafeteria) {
      featureIcons.add(_featureIcon(Icons.local_cafe, "Kafeterya"));
    }
    if (haliSaha.hasNightLighting) {
      featureIcons.add(_featureIcon(Icons.nightlight_round, "Aydınlatma"));
    }

    if (featureIcons.isEmpty) {
      return Center(
        child: Text(
          "Ek özellik bulunmuyor.",
          style: TextStyle(color: Colors.grey[700]),
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: featureIcons,
        ),
      );
    }
  }

  Widget _buildInfoColumn(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.green),
        SizedBox(height: 4),
        Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  /*
  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Konum",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text("Harita Görünümü",
                style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ),
        ),
      ],
    );
  }
  */

  Widget _buildReviewsSection() {
    if (reviewList.isEmpty) {
      return Center(
        child: Text(
          "Henüz yorum yapılmamış.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    } else {
      List<Reviews> sortedList = [...reviewList];

      switch (selectedSort) {
        case ReviewSortOption.newest:
          sortedList.sort((a, b) => b.datetime.compareTo(a.datetime));
          break;
        case ReviewSortOption.oldest:
          sortedList.sort((a, b) => a.datetime.compareTo(b.datetime));
          break;
        case ReviewSortOption.bestRated:
          sortedList.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case ReviewSortOption.worstRated:
          sortedList.sort((a, b) => a.rating.compareTo(b.rating));
          break;
      }

      final visibleReviews =
          showAllReviews ? sortedList : sortedList.take(3).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Yorumlar",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {},
                icon: Icon(Icons.sort, size: 18, color: Colors.black),
                label: DropdownButtonHideUnderline(
                  child: DropdownButton<ReviewSortOption>(
                    value: selectedSort,
                    icon:
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (ReviewSortOption? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedSort = newValue;
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                          value: ReviewSortOption.newest,
                          child: Text("En yeni")),
                      DropdownMenuItem(
                          value: ReviewSortOption.oldest,
                          child: Text("En eski")),
                      DropdownMenuItem(
                          value: ReviewSortOption.bestRated,
                          child: Text("En iyi")),
                      DropdownMenuItem(
                          value: ReviewSortOption.worstRated,
                          child: Text("En kötü")),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: visibleReviews.length,
            itemBuilder: (context, index) {
              final review = visibleReviews[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ReviewItem(
                  review: review,
                  currentUserId: widget._auth.currentUser!.uid,
                  onDelete: () => _deleteReview(review),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (reviewList.length > 3)
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    showAllReviews = !showAllReviews;
                  });
                },
                child: Text(
                  showAllReviews
                      ? "Yorumları gizle"
                      : "Tüm yorumları görüntüle (${reviewList.length})",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }

  Future<void> _deleteReview(Reviews review) async {
    try {
      if (review.docId == null) return; // Emniyet amaçlı

      await FirebaseFirestore.instance
          .collection("hali_sahalar")
          .doc(widget.haliSaha.id)
          .collection("reviews")
          .doc(review.docId)
          .delete();

      setState(() {
        reviewList.removeWhere((r) => r.docId == review.docId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Yorum silindi.")),
      );
    } catch (e) {
      print("Yorum silinirken hata: $e");

      final errorMsg = AppErrorHandler.getMessage(e, context: 'review');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Yorum silinemedi: $errorMsg"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAddReviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Yorum Yaz",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: EdgeInsets.all(8),
          child: TextField(
            textCapitalization: TextCapitalization.sentences,
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Deneyiminizi paylaşın...",
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RatingBar.builder(
              initialRating: _currentRating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemSize: 28,
              itemCount: 5,
              itemBuilder: (context, _) =>
                  Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                setState(() {
                  _currentRating = rating;
                });
              },
            ),
            ElevatedButton(
              onPressed: () {
                if (_currentRating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Lütfen bir puanlama yapınız!"),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  String currentUserName = widget.currentUser.name;
                  addReview(widget.haliSaha.id, _commentController.text,
                      _currentRating,currentUserName);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text("Gönder", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _featureIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 30, color: Colors.green),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }
}

class ReviewItem extends StatelessWidget {
  final Reviews review;
  final String currentUserId;
  final VoidCallback onDelete;

  const ReviewItem({
    Key? key,
    required this.review,
    required this.currentUserId,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isOwner = (review.userId == currentUserId);
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Üst kısım: Avatar, Kullanıcı Adı, Tarih, (Rating)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Profil resmi (basit hali)
                    CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      radius: 22,
                      child: Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 10),

                    /// Kullanıcı Adı + Tarih + Rating
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Kullanıcı adı ve tarih
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOwner ? review.user_name : maskName(review.user_name ?? ''),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatDateTime(review.datetime),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              if (isOwner)
                                InkWell(
                                  onTap: onDelete,
                                  child: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 22,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 6),

                          /// Yıldız Rating (örn. 5 üzerinden)
                          Row(
                            children: _buildStarIcons(review.rating ?? 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),

                /// Yorum Metni
                Text(
                  review.comment,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String maskName(String fullName) {
    if (fullName.trim().isEmpty) return '??';

    List<String> parts = fullName.trim().split(' ');

    return parts.map((part) {
      if (part.length == 0) return '**';
      if (part.length == 1) return part[0] + '*';
      if (part.length == 2) return part[0] + part[1] + '*';
      return part.substring(0, 2) + '*' * (part.length - 2);
    }).join(' ');
  }


  String _formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(dateTime);
    } catch (e) {
      return "Geçersiz Tarih";
    }
  }

  /// Yıldızlı rating göstergesi
  List<Widget> _buildStarIcons(double? rating) {
    // Null, negatif veya çok yüksek değerler için koruma
    double safeRating = (rating ?? 0).clamp(0, 5);

    List<Widget> stars = [];
    for (int i = 0; i < 5; i++) {
      final starPosition = i + 1.0;
      if (safeRating >= starPosition) {
        stars.add(Icon(Icons.star, color: Colors.yellow[700], size: 16));
      } else if (safeRating > i && safeRating < starPosition) {
        stars.add(Icon(Icons.star_half, color: Colors.yellow[700], size: 16));
      } else {
        stars.add(Icon(Icons.star_border, color: Colors.grey[300], size: 16));
      }
    }
    return stars;
  }
}
