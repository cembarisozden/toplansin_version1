import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerPhotoManagementPage extends StatefulWidget {
  final String haliSahaId; // Firestore doküman ID'si
  final List<String> images;

  OwnerPhotoManagementPage({required this.haliSahaId, required this.images});

  @override
  _OwnerPhotoManagementPageState createState() =>
      _OwnerPhotoManagementPageState();
}

class _OwnerPhotoManagementPageState extends State<OwnerPhotoManagementPage> {
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    // Başlangıçta gelen fotoğrafları yerel bir listeye atıyoruz
    _images = List.from(widget.images);
  }

  // Fotoğraf ekleme işlevi
  void _addImage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newImageUrl = '';
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık ve İkon
                Row(
                  children: [
                    Icon(Icons.add_a_photo, color: Colors.green.shade700, size: 28),
                    SizedBox(width: 10),
                    Text(
                      "Fotoğraf Ekle",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // URL Girişi
                TextField(
                  decoration: InputDecoration(
                    hintText: "Fotoğraf URL'si",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.link, color: Colors.green.shade700),
                  ),
                  onChanged: (value) {
                    newImageUrl = value;
                  },
                ),
                SizedBox(height: 20),
                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "İptal",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (newImageUrl.isNotEmpty) {
                          try {
                            // Firestore'da imagesUrl listesine yeni URL'yi ekle
                            await FirebaseFirestore.instance
                                .collection('hali_sahalar')
                                .doc(widget.haliSahaId)
                                .update({
                              'imagesUrl': FieldValue.arrayUnion([newImageUrl]),
                            });

                            setState(() {
                              _images.add(newImageUrl);
                            });
                            Navigator.pop(context);
                          } catch (e) {
                            // Hata durumunda kullanıcıya mesaj göster
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Fotoğraf eklenirken hata oluştu."),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        "Ekle",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fotoğraf silme işlevi
  void _deleteImage(int index) {
    String imageUrl = _images[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık ve İkon
                Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red.shade600, size: 28),
                    SizedBox(width: 10),
                    Text(
                      "Fotoğrafı Sil",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Silme Mesajı
                Text(
                  "Bu fotoğrafı silmek istediğinize emin misiniz?",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Vazgeç",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // Firestore'da imagesUrl listesinden URL'yi kaldır
                          await FirebaseFirestore.instance
                              .collection('hali_sahalar')
                              .doc(widget.haliSahaId)
                              .update({
                            'imagesUrl': FieldValue.arrayRemove([imageUrl]),
                          });

                          setState(() {
                            _images.removeAt(index);
                          });
                          Navigator.pop(context);
                        } catch (e) {
                          // Hata durumunda kullanıcıya mesaj göster
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Fotoğraf silinirken hata oluştu."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        "Sil",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar Tasarımı
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Fotoğraf Yönetimi",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: (){
            Navigator.pop(context);
          }
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_a_photo, color: Colors.white),
            onPressed: _addImage,
            tooltip: "Fotoğraf Ekle",
          ),
        ],
      ),
      body: _images.isNotEmpty
          ? GridView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _images.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Daha iyi uyum için ekran genişliğine göre ayarlayabilirsiniz
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, index) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Fotoğraf
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/halisaha_images/${_images[index]}',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade300,
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey.shade700,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
                // Silme Butonu
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _deleteImage(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      )
          : Center(
        child: Text(
          "Hiç fotoğraf eklenmemiş.",
          style: TextStyle(color: Colors.grey.shade700, fontSize: 18),
        ),
      ),
    );
  }
}
