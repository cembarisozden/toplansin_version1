import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/reviews.dart';

class OwnerReviewsPage extends StatelessWidget {
  final String haliSahaId; // Yorumların bağlı olduğu halı saha ID'si

  OwnerReviewsPage({required this.haliSahaId});

  @override
  Widget build(BuildContext context) {
    // Hali Sahalar koleksiyonunun altındaki reviews alt koleksiyonuna erişim
    CollectionReference reviewsCollection = FirebaseFirestore.instance
        .collection('hali_sahalar')
        .doc(haliSahaId)
        .collection('reviews');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Değerlendirmeler",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 4,
        // Geri Dönüş Okunu Beyaz Yapma
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: reviewsCollection
            .orderBy('datetime', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Hata durumu
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Yorumlar yüklenirken bir hata oluştu.",
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          // Yükleniyor durumu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          // Veri yoksa
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Henüz bir yorum yapılmamış.",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
              ),
            );
          }
          // Yorumları listele
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final docSnapshot = snapshot.data!.docs[index];
              Reviews review = Reviews.fromDocument(docSnapshot);

              return Card(
                color: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kullanıcı Bilgileri
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blue.shade700,
                            child: Text(
                              review.user_name.isNotEmpty ? review.user_name[0].toUpperCase() : 'U',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.user_name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                // Tarihi Türkçe formatta gösterme
                                DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR').format(review.datetime),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      // Rating ve Yorum
                      Row(
                        children: [
                          // Yıldızlar
                          Row(
                            children: List.generate(5, (starIndex) {
                              if (starIndex < review.rating.floor()) {
                                return Icon(Icons.star, color: Colors.amber, size: 20);
                              } else if (starIndex < review.rating && (review.rating - review.rating.floor()) >= 0.5) {
                                return Icon(Icons.star_half, color: Colors.amber, size: 20);
                              } else {
                                return Icon(Icons.star_border, color: Colors.amber, size: 20);
                              }
                            }),
                          ),
                          SizedBox(width: 8),
                          Text(
                            review.rating.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      // Yorum Metni
                      Text(
                        review.comment,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
