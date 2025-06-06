import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toplansin/services/time_service.dart';

class OwnerAddHaliSaha extends StatefulWidget {
  @override
  _OwnerAddHaliSahaState createState() => _OwnerAddHaliSahaState();
}

class _OwnerAddHaliSahaState extends State<OwnerAddHaliSaha> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController phoneController=TextEditingController(text: '+90');
  final TextEditingController priceController = TextEditingController();
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController surfaceController = TextEditingController();
  final TextEditingController maxPlayersController = TextEditingController();
  final TextEditingController startHourController = TextEditingController();
  final TextEditingController endHourController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController imagesController = TextEditingController();

  bool hasParking = false;
  bool hasShowers = false;
  bool hasShoeRental = false;
  bool hasCafeteria = false;
  bool hasNightLighting = false;

  bool isLoading = false;
  bool isOwner = false;

  @override
  void initState() {
    super.initState();
    checkIfUserIsOwner();
  }

  Future<void> checkIfUserIsOwner() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Firestore'dan kullanıcı belgesini al
        DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // Kullanıcının 'role' alanını kontrol et
          String? role = userDoc.data()?['role'];
          if (role == 'owner') {
            setState(() {
              isOwner = true;
            });
          }
        } else {
          print("Kullanıcı Firestore'da bulunamadı.");
        }
      } catch (e) {
        print("Kullanıcı rolü kontrol edilirken hata oluştu: $e");
      }
    }
  }

  Future<void> _kaydet() async {
    if (nameController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty ||
        sizeController.text.trim().isEmpty ||
        surfaceController.text.trim().isEmpty ||
        maxPlayersController.text.trim().isEmpty ||
        startHourController.text.trim().isEmpty ||
        endHourController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen tüm alanları doldurun.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw ('Kullanıcı doğrulanmamış.');
      }

      HaliSaha yeniSaha = HaliSaha(
        ownerId: FirebaseAuth.instance.currentUser!.uid,
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        phone: '+${toNumericString(phoneController.text.trim())}',
        price: double.parse(priceController.text.trim()),
        rating: 0.0,
        imagesUrl: imagesController.text
            .trim()
            .split(',')
            .map((url) => url.trim())
            .toList(),
        bookedSlots: [" "],
        startHour: startHourController.text.trim(),
        endHour: endHourController.text.trim(),
        id: TimeService.now().millisecondsSinceEpoch.toString(),
        hasParking: hasParking,
        hasShowers: hasShowers,
        hasShoeRental: hasShoeRental,
        hasCafeteria: hasCafeteria,
        hasNightLighting: hasNightLighting,
        description: descriptionController.text.trim(),
        size: sizeController.text.trim(),
        surface: surfaceController.text.trim(),
        maxPlayers: int.parse(maxPlayersController.text.trim()),
      );

      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(yeniSaha.id)
          .set(yeniSaha.toJson());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Halı Saha başarıyla eklendi.'),
          backgroundColor: Colors.green,
        ),
      );

      _formTemizle();
      Navigator.pop(context, yeniSaha);
    } catch (e, stacktrace) {
      print("Hata: $e");
      print("Stacktrace: $stacktrace");
      final msg = AppErrorHandler.getMessage(e, context: 'field');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Halı Saha eklenirken hata oluştu: $msg'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _formTemizle() {
    nameController.clear();
    locationController.clear();
    priceController.clear();
    phoneController.clear();
    sizeController.clear();
    surfaceController.clear();
    maxPlayersController.clear();
    startHourController.clear();
    endHourController.clear();
    descriptionController.clear();
    imagesController.clear();
    setState(() {
      hasParking = false;
      hasShowers = false;
      hasShoeRental = false;
      hasCafeteria = false;
      hasNightLighting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Halı Saha Ekle"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Yeni Halı Saha Ekle",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildTextField("Halı Saha Adı", nameController,
                      maxLength: 10),
                  _buildTextField("Konum", locationController, maxLength: 100),
                  _buildTextField("Saatlik Ücret (TL)", priceController,
                      isNumber: true, maxLength: 20),
                  _buildTextField("Saha Boyutu (örn. 25x40)", sizeController,
                      maxLength: 20),
                  buildPhoneNumberField(phoneController),
                  _buildTextField(
                      "Zemin Tipi (örn. Sentetik Çim)", surfaceController,
                      maxLength: 40),
                  _buildTextField(
                      "Maksimum Oyuncu Sayısı", maxPlayersController,
                      isNumber: true, maxLength: 20),
                  _buildTextField("Fotoğraf Url", imagesController),
                  Row(
                    children: [
                      Expanded(
                          child: _buildTextField(
                              "Açılış Saati (örn. 09:00)", startHourController,
                              maxLength: 5)),
                      SizedBox(width: 16),
                      Expanded(
                          child: _buildTextField(
                              "Kapanış Saati (örn. 23:00)", endHourController,
                              maxLength: 5)),
                    ],
                  ),
                  _buildTextField("Açıklama", descriptionController,
                      isMultiline: true, maxLength: 300),
                  SizedBox(height: 16),
                  Text(
                    "Özellikler",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SwitchListTile(
                    title: Text("Otopark"),
                    value: hasParking,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        hasParking = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text("Duş"),
                    value: hasShowers,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        hasShowers = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text("Ayakkabı Kiralama"),
                    value: hasShoeRental,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        hasShoeRental = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text("Kafeterya"),
                    value: hasCafeteria,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        hasCafeteria = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text("Gece Aydınlatması"),
                    value: hasNightLighting,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        hasNightLighting = val;
                      });
                    },
                  ),
                  SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: _kaydet,
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text(
                          "Kaydet",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }


  Widget buildPhoneNumberField(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          PhoneInputFormatter(
            defaultCountryCode: 'TR',
            allowEndlessPhone: false,
          ),
        ],
        maxLength: 17,
        maxLines: 1,
        buildCounter: (
            BuildContext context, {
              required int currentLength,
              required bool isFocused,
              required int? maxLength,
            }) {
          if (maxLength == null) return null;
          return Text(
            "$currentLength / $maxLength",
            style: TextStyle(
              fontSize: 11,
              color:
              currentLength > maxLength ? Colors.red : Colors.grey.shade600,
            ),
          );
        },
        decoration: InputDecoration(
          labelText: "İletişim Telefon Numarası",
          hintText: "+90 5XX XXX XX XX",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }


  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    bool isMultiline = false,
    int maxLength = 300, // ⚠️ Karakter sınırı opsiyonel
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? TextInputType.number
            : (isMultiline ? TextInputType.multiline : TextInputType.text),
        maxLines: isMultiline ? 4 : 1,
        maxLength: maxLength,
        buildCounter: (
          BuildContext context, {
          required int currentLength,
          required bool isFocused,
          required int? maxLength,
        }) {
          if (maxLength == null) return null;
          return Text(
            "$currentLength / $maxLength",
            style: TextStyle(
              fontSize: 11,
              color:
                  currentLength > maxLength ? Colors.red : Colors.grey.shade600,
            ),
          );
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
