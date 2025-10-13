import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerAddHaliSaha extends StatefulWidget {
  @override
  _OwnerAddHaliSahaState createState() => _OwnerAddHaliSahaState();
}

class _OwnerAddHaliSahaState extends State<OwnerAddHaliSaha> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
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
  bool hasMaleToilet = false;
  bool hasFoodService = false;
  bool acceptsCreditCard = false;
  bool hasFoosball = false;
  bool hasCameras = false;
  bool hasGoalkeeper = false;
  bool hasPlayground = false;
  bool hasPrayerRoom = false;
  bool hasInternet = false;
  bool hasFemaleToilet = false;

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
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()?['role'] == 'owner') {
          setState(() => isOwner = true);
        }
      } catch (e) {
        print("Owner check error: $e");
      }
    }
  }

  Future<void> _kaydet() async {
    showLoader(context);
    // Gerekli alan kontrolü: Boş olmayan tüm alanlar
    if ([
      nameController,
      locationController,
      latController,
      lngController,
      phoneController,
      priceController,
      sizeController,
      surfaceController,
      maxPlayersController,
      startHourController,
      endHourController,
      descriptionController
    ].any((c) => c.text.trim().isEmpty)) {
      AppSnackBar.error(context, 'Lütfen tüm alanları doldurun.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Kullanıcı doğrulanmamış.';

      // Enlem / Boylam parse
      final lat = double.tryParse(latController.text.replaceAll(',', '.'));
      final lng = double.tryParse(lngController.text.replaceAll(',', '.'));
      if (lat == null || lng == null) {
        throw 'Geçerli koordinat girin.';
      }
      final rawInput = phoneController.text.trim();
      final newPhone = '+90${toNumericString(rawInput)}';


      final yeniSaha = HaliSaha(
        ownerId: user.uid,
        name: nameController.text.trim(),
        location: locationController.text.trim(),
        latitude: lat,
        longitude: lng,
        phone: newPhone,
        price: double.parse(priceController.text.trim()),
        rating: 0.0,
        imagesUrl: imagesController.text
            .trim()
            .split(',')
            .map((url) => url.trim())
            .toList(),
        bookedSlots: const [],
        startHour: startHourController.text.trim(),
        endHour: endHourController.text.trim(),
        id: TimeService.now().millisecondsSinceEpoch.toString(),

        // Özellikler
        hasParking: hasParking,
        hasShowers: hasShowers,
        hasShoeRental: hasShoeRental,
        hasCafeteria: hasCafeteria,
        hasNightLighting: hasNightLighting,
        hasCameras: hasCameras,
        hasFoodService: hasFoodService,
        hasFoosball: hasFoosball,
        hasMaleToilet: hasMaleToilet,
        hasFemaleToilet: hasFemaleToilet,
        acceptsCreditCard: acceptsCreditCard,
        hasGoalkeeper: hasGoalkeeper,
        hasPlayground: hasPlayground,
        hasPrayerRoom: hasPrayerRoom,
        hasInternet: hasInternet,

        description: descriptionController.text.trim(),
        size: sizeController.text.trim(),
        surface: surfaceController.text.trim(),
        maxPlayers: int.parse(maxPlayersController.text.trim()),
      );


      await FirebaseFirestore.instance
          .collection('hali_sahalar')
          .doc(yeniSaha.id)
          .set(yeniSaha.toJson());

      AppSnackBar.success(context, 'Halı saha başarıyla eklendi.');

      _formTemizle();
      Navigator.pop(context, yeniSaha);
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'field');
      AppSnackBar.error(context, 'Hata: $msg');
    } finally {
      hideLoader();
      setState(() => isLoading = false);
    }
  }

  void _formTemizle() {
    [
      nameController,
      locationController,
      latController,
      lngController,
      phoneController,
      priceController,
      sizeController,
      surfaceController,
      maxPlayersController,
      startHourController,
      endHourController,
      descriptionController,
      imagesController
    ].forEach((c) => c.clear());
    setState(() {
       hasParking = false;
       hasShowers = false;
       hasShoeRental = false;
       hasCafeteria = false;
       hasNightLighting = false;
       hasMaleToilet = false;
       hasFoodService = false;
       acceptsCreditCard = false;
       hasFoosball = false;
       hasCameras = false;
       hasGoalkeeper = false;
       hasPlayground = false;
       hasPrayerRoom = false;
       hasInternet = false;
       hasFemaleToilet = false;
    });
  }

  Future<void> openMaps(double lat, double lng) async {
    final url = Platform.isIOS
        ? 'http://maps.apple.com/?daddr=$lat,$lng'
        : 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunch(url)) await launch(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Halı Saha Ekle')),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yeni Halı Saha Ekle', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _buildTextField('Halı Saha Adı', nameController, maxLength: 100),
            _buildTextField('Konum (Adres)', locationController, maxLength: 100),
            _buildTextField('Enlem (Latitude)', latController, isNumber: true, maxLength: 20),
            _buildTextField('Boylam (Longitude)', lngController, isNumber: true, maxLength: 20),
            _buildTextField('Saatlik Ücret (TL)', priceController, isNumber: true, maxLength: 20),
            _buildTextField('Saha Boyutu (örn. 25x40)', sizeController, maxLength: 20),
            buildPhoneNumberField(phoneController),
            _buildTextField('Zemin Tipi (örn. Sentetik Çim)', surfaceController, maxLength: 40),
            _buildTextField('Maksimum Oyuncu Sayısı', maxPlayersController, isNumber: true, maxLength: 20),
            _buildTextField('Fotoğraf URL (virgülle ayrılmış)', imagesController),
            Row(
              children: [
                Expanded(child: _buildTextField('Açılış Saati (örn. 09:00)', startHourController, maxLength: 5)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Kapanış Saati (örn. 23:00)', endHourController, maxLength: 5)),
              ],
            ),
            _buildTextField('Açıklama', descriptionController, isMultiline: true, maxLength: 800),
            SizedBox(height: 16),
            Text('Özellikler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SwitchListTile(
              title: Text('Otopark'),
              value: hasParking,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasParking = v),
            ),
            SwitchListTile(
              title: Text('Duş'),
              value: hasShowers,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasShowers = v),
            ),
            SwitchListTile(
              title: Text('Ayakkabı Kiralama'),
              value: hasShoeRental,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasShoeRental = v),
            ),
            SwitchListTile(
              title: Text('Kafeterya'),
              value: hasCafeteria,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasCafeteria = v),
            ),
            SwitchListTile(
              title: Text('Gece Aydınlatması'),
              value: hasNightLighting,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasNightLighting = v),
            ),
            SwitchListTile(
              title: Text('Kamera'),
              value: hasCameras,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasCameras = v),
            ),
            SwitchListTile(
              title: Text('Yemek'),
              value: hasFoodService,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasFoodService = v),
            ),
            SwitchListTile(
              title: Text('Langırt'),
              value: hasFoosball,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasFoosball = v),
            ),
            SwitchListTile(
              title: Text('Erkek Tuvaleti'),
              value: hasMaleToilet,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasMaleToilet = v),
            ),
            SwitchListTile(
              title: Text('Kadın Tuvaleti'),
              value: hasFemaleToilet,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasFemaleToilet = v),
            ),
            SwitchListTile(
              title: Text('Kredi Kartı Geçerli'),
              value: acceptsCreditCard,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => acceptsCreditCard = v),
            ),
            SwitchListTile(
              title: Text('Kiralık Kaleci'),
              value: hasGoalkeeper,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasGoalkeeper = v),
            ),
            SwitchListTile(
              title: Text('Çocuk Oyun Alanı'),
              value: hasPlayground,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasPlayground = v),
            ),
            SwitchListTile(
              title: Text('Mescit'),
              value: hasPrayerRoom,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasPrayerRoom = v),
            ),
            SwitchListTile(
              title: Text('İnternet'),
              value: hasInternet,
              activeThumbColor: Colors.green,
              onChanged: (v) => setState(() => hasInternet = v),
            ),
            SizedBox(height: 24),

            Center(
              child: ElevatedButton(
                onPressed: _kaydet,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Kaydet', style: TextStyle(fontSize: 16, color: Colors.white)),
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
          // Eskiden kullandığın formatter aynen kalsın
          PhoneInputFormatter(defaultCountryCode: 'TR', allowEndlessPhone: false),
        ],
        maxLength: 12,
        buildCounter: (context, { required currentLength, required isFocused, required maxLength }) {
          if (maxLength == null) return null;
          return Text(
            '$currentLength / $maxLength',
            style: TextStyle(
              fontSize: 11,
              color: currentLength > maxLength ? Colors.red : Colors.grey.shade600,
            ),
          );
        },
        decoration: InputDecoration(
          // +90 kısmı artık silinemez, hep orada sabit durur
          prefixText: '+90 ',
          prefixStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),

          labelText: 'İletişim Telefon Numarası',
          hintText: '5XX XXX XX XX',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        int maxLength = 300,
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
        buildCounter: (context, {required currentLength, required isFocused, required maxLength}) {
          if (maxLength == null) return null;
          return Text('$currentLength / $maxLength', style: TextStyle(fontSize: 11, color: currentLength > maxLength ? Colors.red : Colors.grey.shade600));
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
