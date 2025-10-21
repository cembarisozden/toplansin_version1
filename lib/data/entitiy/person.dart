import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/services/time_service.dart';

class Person {
  String id;
  String name;
  String email;
  String? phone;
  String role; // Rol alanı eklendi
  String? fcmToken;
  List<String>? fieldAccessCodes;
  DateTime? createdAt;

  Person({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role, // Yeni alan eklendi
    this.fieldAccessCodes,
    this.createdAt,
  });

  // toMap fonksiyonu
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role, // Rol alanı ekleniyor
      'fieldAccessCodes': fieldAccessCodes,
      // Eğer createdAt boşsa serverTimestamp koy (ilk kayıtta)
      'createdAt': createdAt != null ? createdAt : FieldValue.serverTimestamp(),
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
      fieldAccessCodes: List<String>.from(map['fieldAccessCodes'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Person copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    List<String>? fieldAccessCodes,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      fieldAccessCodes: fieldAccessCodes ?? this.fieldAccessCodes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

