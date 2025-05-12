import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  String id;
  final String userId;
  final String haliSahaId;
  final String haliSahaName;
  final String haliSahaLocation;
  final num haliSahaPrice;
  final String reservationDateTime;
  String status;
  final DateTime createdAt;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? lastUpdatedBy;

  Reservation({
    required this.id,
    required this.userId,
    required this.haliSahaId,
    required this.haliSahaName,
    required this.haliSahaLocation,
    required this.haliSahaPrice,
    required this.reservationDateTime,
    required this.status,
    required this.createdAt,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.lastUpdatedBy,
  });

  /// Firestore'dan alınan bir belgeden `Reservation` nesnesi oluşturur.
  factory Reservation.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reservation(
      id: doc.id, // Firestore'dan alınan ID
      userId: data['userId'] ?? '',
      haliSahaId: data['haliSahaId'] ?? '',
      haliSahaName: data['haliSahaName'] ?? '',
      haliSahaLocation: data['haliSahaLocation'] ?? '',
      haliSahaPrice: data['haliSahaPrice'] ?? 0,
      reservationDateTime: data['reservationDateTime'] ?? '',
      status: data['status'] ?? 'Beklemede',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userName: data['userName'] ?? 'Kullanıcı Adı Yok',
      userEmail: data['userEmail'] ?? 'E-posta Yok',
      userPhone: data['userPhone'] ?? 'Telefon Yok',
      lastUpdatedBy: data['lastUpdatedBy'] ?? "",
    );
  }


  /// `Reservation` nesnesini bir `Map<String, dynamic>`'e dönüştürür.
  Map<String, dynamic> toMap() {
    return {
      'id':id,
      'userId': userId,
      'haliSahaId': haliSahaId,
      'haliSahaName': haliSahaName,
      'haliSahaLocation': haliSahaLocation,
      'haliSahaPrice': haliSahaPrice,
      'reservationDateTime': reservationDateTime,
      'status': status,
      'createdAt': createdAt,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'lastUpdatedBy': lastUpdatedBy,
    };
  }
}
