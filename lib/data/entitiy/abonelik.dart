class Abonelik {
  final String halisahaId;
  final String userId;
  final String halisahaName;
  final String location;
  final String day;
  final String time;
  final num price;
  final String state;

  Abonelik(
      {required this.halisahaId,
      required this.userId,
      required this.halisahaName,
      required this.location,
      required this.day,
      required this.time,
      required this.price,
      required this.state});

  factory Abonelik.fromMap(Map<String, dynamic> map) {
    return Abonelik(
      halisahaId: map['halisahaId'],
      userId: map['userId'],
      halisahaName: map['halisahaName'],
      location: map['location'],
      day: map['day'],
      price: map['price'],
      time: map['time'],
      state: map['state'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'halisahaId': halisahaId,
      'userId': userId,
      'halisahaName': halisahaName,
      'location': location,
      'day': day,
      'time': time,
      'price': price,
      'state': state,
    };
  }
}
