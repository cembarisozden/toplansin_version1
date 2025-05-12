class Person {
  String id;
  String name;
  String email;
  String phone;
  String role; // Rol alanı eklendi
  String? fcmToken;

  Person({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role, // Yeni alan eklendi
  });

  // toMap fonksiyonu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role, // Rol alanı ekleniyor
    };
  }

  // fromMap fonksiyonu
  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] as String? ?? 'unknown', // Varsayılan rol 'user' olabilir
    );
  }
}
