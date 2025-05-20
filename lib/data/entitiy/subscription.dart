class Subscription {
  final String docId;
  final String haliSahaId;
  final String userId;
  final String haliSahaName;
  final String location;
  final int dayOfWeek;
  final String time;
  final num price;
  final String startDate;
  final String endDate;
  final String visibleSession;
  final String nextSession;
  final String lastUpdatedBy;
  final String status;
  final String userName;
  final String userPhone;
  final String userEmail;

  Subscription({
    required this.docId,
    required this.haliSahaId,
    required this.userId,
    required this.haliSahaName,
    required this.location,
    required this.dayOfWeek,
    required this.time,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.visibleSession,
    required this.nextSession,
    required this.lastUpdatedBy,
    required this.status,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
  });

  factory Subscription.fromMap(Map<String, dynamic> map, String docId) {
    return Subscription(
      docId: docId,
      haliSahaId: map['haliSahaId'] ?? '',
      userId: map['userId'] ?? '',
      haliSahaName: map['haliSahaName'] ?? 'Bilinmiyor',
      location: map['location'] ?? 'Bilinmiyor',
      dayOfWeek: map['dayOfWeek'] ?? 1,
      price: map['price'] ?? 0,
      time: map['time'] ?? '00:00-01:00',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      visibleSession: map['visibleSession'] ?? 'Bekleniyor',
      nextSession: map['nextSession'] ?? 'Bekleniyor',
      lastUpdatedBy: map['lastUpdatedBy'] ?? '',
      status: map['status'] ?? map['newStatus'] ?? 'Bilinmiyor',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      userEmail: map['userEmail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'docId': docId,
      'haliSahaId': haliSahaId,
      'userId': userId,
      'haliSahaName': haliSahaName,
      'location': location,
      'dayOfWeek': dayOfWeek,
      'time': time,
      'price': price,
      'startDate': startDate,
      'endDate': endDate,
      'nextSession': visibleSession,
      'lastUpdatedBy': lastUpdatedBy,
      'status': status,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
    };
  }
}
