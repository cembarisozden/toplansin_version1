import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  String id;
  final String userId;
  final String haliSahaId;
  final String haliSahaName;
  final String haliSahaLocation;
  final num haliSahaPrice;
  final String reservationDateTime;
  final DateTime? startTime;
  final DateTime? endTime; // ✅ eklendi
  String status;
  final DateTime createdAt;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? lastUpdatedBy;
  final String? cancelReason;
  final String? type;
  final String? subscriptionId;

  Reservation({
    required this.id,
    required this.userId,
    required this.haliSahaId,
    required this.haliSahaName,
    required this.haliSahaLocation,
    required this.haliSahaPrice,
    required this.reservationDateTime,
    this.startTime,
    this.endTime, // ✅
    required this.status,
    required this.createdAt,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.lastUpdatedBy,
    this.cancelReason,
    this.type,
    this.subscriptionId,
  });

  factory Reservation.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final start = data['startTime'] != null
        ? (data['startTime'] as Timestamp).toDate()
        : null;

    // Eğer endTime yoksa, startTime + 1 saat olarak ayarla
    final end = data['endTime'] != null
        ? (data['endTime'] as Timestamp).toDate()
        : (start != null ? start.add(const Duration(hours: 1)) : null);

    return Reservation(
      id: doc.id,
      userId: data['userId'] ?? '',
      haliSahaId: data['haliSahaId'] ?? '',
      haliSahaName: data['haliSahaName'] ?? '',
      haliSahaLocation: data['haliSahaLocation'] ?? '',
      haliSahaPrice: data['haliSahaPrice'] ?? 0,
      reservationDateTime: data['reservationDateTime'] ?? '',
      status: data['status'] ?? data['newStatus'] ?? 'Beklemede',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userName: data['userName'] ?? 'Kullanıcı Adı Yok',
      userEmail: data['userEmail'] ?? 'E-posta Yok',
      userPhone: data['userPhone'] ?? 'Telefon Yok',
      lastUpdatedBy: data['lastUpdatedBy'] ?? '',
      cancelReason: data['cancelReason'] ?? '',
      type: data['type'] ?? 'manual',
      subscriptionId: data['subscriptionId'],
      startTime: start,
      endTime: end,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'cancelReason': cancelReason,
      'subscriptionId':subscriptionId,
      'type': type,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': startTime != null
          ? Timestamp.fromDate(startTime!.add(const Duration(hours: 1)))
          : null, // ✅ hep 1 saat sonrası
    };
  }
}
