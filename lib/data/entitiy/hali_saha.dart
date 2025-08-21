
class HaliSaha {
  String ownerId;
  String name;
  String location;
  num price;
  num rating;
  List<String> imagesUrl;
  List<String> bookedSlots;
  String startHour;
  String endHour;
  String id;
  bool hasParking;
  bool hasShowers;
  bool hasShoeRental;
  bool hasCafeteria;
  bool hasNightLighting;
  String description;
  String size;
  String surface;
  int maxPlayers;
  String phone;
  double latitude;  // yeni alan
  double longitude;

  HaliSaha({
    required this.ownerId,
    required this.name,
    required this.location,
    required this.price,
    required this.rating,
    required this.imagesUrl,
    required this.bookedSlots,
    required this.startHour,
    required this.endHour,
    required this.id,
    required this.hasParking,
    required this.hasShowers,
    required this.hasShoeRental,
    required this.hasCafeteria,
    required this.hasNightLighting,
    required this.description,
    required this.size,
    required this.surface,
    required this.maxPlayers,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });

  // JSON formatına dönüştürmek için toJson metodu
  Map<String, dynamic> toJson() {
    return {
      'ownerId': ownerId,
      'name': name,
      'location': location,
      'price': price,
      'rating': rating,
      'imagesUrl': imagesUrl,
      'bookedSlots': bookedSlots,
      'startHour': startHour,
      'endHour': endHour,
      'id': id,
      'hasParking': hasParking,
      'hasShowers': hasShowers,
      'hasShoeRental': hasShoeRental,
      'hasCafeteria': hasCafeteria,
      'hasNightLighting': hasNightLighting,
      'description': description,
      'size': size,
      'surface': surface,
      'maxPlayers': maxPlayers,
      'phone':phone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // JSON'dan HaliSaha nesnesine dönüştürmek için fromJson metodu
  factory HaliSaha.fromJson(Map<String, dynamic> json, String key) {
    return HaliSaha(
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      price: json['price'] as num,
      rating: json['rating'] as num,
      imagesUrl: List<String>.from(json['imagesUrl']),
      bookedSlots: List<String>.from(json['bookedSlots']),
      startHour: json['startHour'].toString(),
      endHour: json['endHour'].toString(),
      id: key,
      hasParking: json['hasParking'] as bool,
      hasShowers: json['hasShowers'] as bool,
      hasShoeRental: json['hasShoeRental'] as bool,
      hasCafeteria: json['hasCafeteria'] as bool,
      hasNightLighting: json['hasNightLighting'] as bool,
      description: json['description'] as String,
      size: json['size'] as String,
      surface: json['surface'] as String,
      maxPlayers: json['maxPlayers'] as int,
      phone: json['phone'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }
}
