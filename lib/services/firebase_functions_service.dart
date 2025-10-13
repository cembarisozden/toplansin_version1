import 'package:cloud_functions/cloud_functions.dart';

/// 🌍 Tüm callable fonksiyonlar için tek global instance.
/// Artık her çağrıda otomatik olarak `europe-west1` bölgesi kullanılır.
final FirebaseFunctions functions =
FirebaseFunctions.instanceFor(region: 'europe-west1');
