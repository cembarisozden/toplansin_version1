import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';

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
    _images = List.from(widget.images);
  }

  // Fotoğraf ekleme devre dışı
  void _addImage() {
    AppSnackBar.warning(context,
        "Fotoğraf ekleme yalnızca geliştirici tarafından yapılabilir. Geliştiriciyle iletişime geçiniz.");
  }

  // Fotoğraf silme
  void _deleteImage(int index) {
    String imageUrl = _images[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                Row(
                  children: [
                    Icon(Icons.delete_forever,
                        color: Colors.red.shade600, size: 28),
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
                Text(
                  "Bu fotoğrafı silmek istediğinize emin misiniz?",
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Vazgeç",
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 16)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
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
                          AppSnackBar.error(
                              context, "Fotoğraf silinirken hata oluştu");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text("Sil",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Fotoğraf Yönetimi",
            style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                return Card(
                  elevation: 4,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProgressiveImage(
                        imageUrl: _images[index],
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _deleteImage(index),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.delete,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          : Center(
              child: Text("Hiç fotoğraf eklenmemiş.",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 18)),
            ),
    );
  }
}
