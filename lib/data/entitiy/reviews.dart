import 'package:cloud_firestore/cloud_firestore.dart';

class Reviews {
  String? docId;             // <-- Firestore doküman ID
  String comment;
  double rating;
  DateTime datetime;
  String user_id;
  String user_name;

  Reviews({
    this.docId,
    required this.comment,
    required this.rating,
    required this.datetime,
    required this.user_id,
    required this.user_name,
  });

  Map<String, dynamic> toJson() {
    return {
      'comment': comment,
      'rating': rating,
      'datetime': Timestamp.fromDate(datetime),
      'user_id': user_id,
      'user_name': user_name,
    };
  }

  // Doküman + verisini modele çeviren named constructor
  factory Reviews.fromDocument(DocumentSnapshot doc) {
    final json = doc.data() as Map<String, dynamic>;
    return Reviews(
      docId: doc.id, // dokümanın benzersiz Firestore ID'si
      comment: json['comment'] as String,
      rating: (json['rating'] as num).toDouble(),
      datetime: (json['datetime'] as Timestamp).toDate(),
      user_id: json['user_id'] as String,
      user_name: json['user_name'] as String,
    );
  }
}
