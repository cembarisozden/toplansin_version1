import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/data/entitiy/reviews.dart';
import 'package:toplansin/ui/user_views/reservation_page.dart';

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

  Future<void> addReview(
      String haliSahaId,
      String newComment,
      double newRating,
      String userId,
      String userName,
      ) async {
    Reviews newReview = Reviews(
      comment: newComment,
      rating: newRating,
      datetime: DateTime.now(),
      user_id: userId,
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

    await _updateHaliSahaRating(haliSahaId);
  }

  Future<void> _updateHaliSahaRating(String haliSahaId) async {
    var collectionReviews = FirebaseFirestore.instance
        .collection("hali_sahalar")
        .doc(haliSahaId)
        .collection("reviews");

    var snapshot = await collectionReviews.get();
    if (snapshot.docs.isNotEmpty) {
      double totalRating = 0;
      int count = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data.containsKey('rating')) {
          double r = data['rating']?.toDouble() ?? 0.0;
          totalRating += r;
          count++;
        }
      }

      double averageRating = count > 0 ? totalRating / count : 0.0;

      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(haliSahaId)
          .update({'rating': averageRating});
    } else {
      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(haliSahaId)
          .update({'rating': 0});
    }
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
      if (a.user_id == currentUserId && b.user_id != currentUserId) {
        return -1;
      }
      else if (b.user_id == currentUserId && a.user_id != currentUserId) {
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
                          child: Image.asset(
                            "assets/halisaha_images/${widget.haliSaha.imagesUrl[index]}",
                            fit: BoxFit.contain,
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
                      SizedBox(height: 16),
                      Text(
                        haliSaha.description,
                        style: TextStyle(
                            color: Colors.grey[700], height: 1.4, fontSize: 14),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
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
                            padding: EdgeInsets.symmetric(vertical: 16),
                            elevation: 2,
                          ),
                          child: Text(
                            "Rezervasyon Yap",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildInfoAndFeaturesTabs(haliSaha),
                      SizedBox(height: 24),
                      _buildMapSection(),
                      SizedBox(height: 24),
                      _buildReviewsSectionContainer(),
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
                  child: Image.asset(
                    "assets/halisaha_images/${widget.haliSaha.imagesUrl[index]}",
                    width: MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.cover,
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
            _buildInfoColumn(Icons.monetization_on, "Ücret",
                "${haliSaha.price} TL"),
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
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Konum", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  Widget _buildReviewsSectionContainer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Yorumlar",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        _buildReviewsSection(),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (reviewList.isEmpty) {
      return Center(
        child: Text(
          "Henüz yorum yapılmamış.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: reviewList.length,
        itemBuilder: (context, index) {
          final review = reviewList[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ReviewItem(
              review: review,
              currentUserId: widget._auth.currentUser!.uid,
              onDelete: () =>_deleteReview(review),
            ),
          );
        },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Yorum silinirken hata oluştu: $e")),
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
                  String currentUserId = widget._auth.currentUser!.uid;
                  addReview(widget.haliSaha.id, _commentController.text,
                      _currentRating, currentUserId, currentUserName);
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
    bool isOwner = (review.user_id == currentUserId);

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
                                review.user_name,
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
                            children: _buildStarIcons(review.rating),
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

  String _formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(dateTime);
    } catch (e) {
      return "Geçersiz Tarih";
    }
  }

  /// Yıldızlı rating göstergesi
  List<Widget> _buildStarIcons(double rating) {
    List<Widget> stars = [];
    for (int i = 0; i < 5; i++) {
      final starPosition = i + 1.0;
      if (rating >= starPosition) {
        stars.add(Icon(Icons.star, color: Colors.yellow[700], size: 16));
      } else if (rating > i && rating < starPosition) {
        stars.add(Icon(Icons.star_half, color: Colors.yellow[700], size: 16));
      } else {
        stars.add(Icon(Icons.star_border, color: Colors.grey[300], size: 16));
      }
    }
    return stars;
  }
}

