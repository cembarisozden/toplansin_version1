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

  // Özellikler (Amenities)
  bool hasParking;         // Otopark
  bool hasShowers;         // Duş
  bool hasShoeRental;      // Ayakkabı kiralama
  bool hasCafeteria;       // Cafe / kafeterya
  bool hasNightLighting;   // Gece aydınlatması
  bool hasMaleToilet;      // Erkek tuvaleti
  bool hasFemaleToilet;    // Kadın tuvaleti
  bool hasFoodService;     // Yemek
  bool acceptsCreditCard;  // Kredi kartı
  bool hasFoosball;        // Langırt
  bool hasCameras;         // Kamera
  bool hasGoalkeeper;      // Kiralık kaleci
  bool hasPlayground;      // Çocuk oyun alanı
  bool hasPrayerRoom;      // İbadet alanı
  bool hasInternet;        // İnternet

  String description;
  String size;
  String surface;
  int maxPlayers;
  String phone;
  double latitude;
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
    required this.hasMaleToilet,
    required this.hasFemaleToilet,
    required this.hasFoodService,
    required this.acceptsCreditCard,
    required this.hasFoosball,
    required this.hasCameras,
    required this.hasGoalkeeper,
    required this.hasPlayground,
    required this.hasPrayerRoom,
    required this.hasInternet,
    required this.description,
    required this.size,
    required this.surface,
    required this.maxPlayers,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });

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
      'hasMaleToilet': hasMaleToilet,
      'hasFemaleToilet': hasFemaleToilet,
      'hasFoodService': hasFoodService,
      'acceptsCreditCard': acceptsCreditCard,
      'hasFoosball': hasFoosball,
      'hasCameras': hasCameras,
      'hasGoalkeeper': hasGoalkeeper,
      'hasPlayground': hasPlayground,
      'hasPrayerRoom': hasPrayerRoom,
      'hasInternet': hasInternet,
      'description': description,
      'size': size,
      'surface': surface,
      'maxPlayers': maxPlayers,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory HaliSaha.fromJson(Map<String, dynamic> json, String key) {
    return HaliSaha(
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      price: json['price'] as num,
      rating: json['rating'] as num,
      imagesUrl: List<String>.from(json['imagesUrl'] ?? const []),
      bookedSlots: List<String>.from(json['bookedSlots'] ?? const []),
      startHour: json['startHour'].toString(),
      endHour: json['endHour'].toString(),
      id: key,
      hasParking: json['hasParking'] as bool,
      hasShowers: json['hasShowers'] as bool,
      hasShoeRental: json['hasShoeRental'] as bool,
      hasCafeteria: json['hasCafeteria'] as bool,
      hasNightLighting: json['hasNightLighting'] as bool,
      hasMaleToilet: json['hasMaleToilet'] as bool,
      hasFemaleToilet: json['hasFemaleToilet'] as bool,
      hasFoodService: json['hasFoodService'] as bool,
      acceptsCreditCard: json['acceptsCreditCard'] as bool,
      hasFoosball: json['hasFoosball'] as bool,
      hasCameras: json['hasCameras'] as bool,
      hasGoalkeeper: json['hasGoalkeeper'] as bool,
      hasPlayground: json['hasPlayground'] as bool,
      hasPrayerRoom: json['hasPrayerRoom'] as bool,
      hasInternet: json['hasInternet'] as bool,
      description: json['description'] as String,
      size: json['size'] as String,
      surface: json['surface'] as String,
      maxPlayers: json['maxPlayers'] as int,
      phone: json['phone'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
