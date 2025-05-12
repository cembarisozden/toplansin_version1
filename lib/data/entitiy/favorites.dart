class Favorites {
  String userId;
  List<String> favorites;

  Favorites({required this.userId, required this.favorites});

  // Firestore'dan alınan veriyi modele çeviren factory constructor
  factory Favorites.fromMap(Map<String, dynamic> map) {
    return Favorites(
      userId: map['userId'],
      favorites: List<String>.from(map['favorites'] ?? []),
    );
  }

  // Veriyi Firestore'a yazmak için Map'e çevirme
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'favorites': favorites,
    };
  }
}
