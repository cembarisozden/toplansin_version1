import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/dialogs/edit_profile_dialog.dart';
import 'package:toplansin/ui/user_views/dialogs/phone_verify_dialog.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/login_page.dart';



class UserSettingsPage extends StatefulWidget {
   Person currentUser;

  UserSettingsPage({required this.currentUser});

  @override
  _UserSettingsPageState createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ayarlar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            )),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
          ),
        ),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(gradient: LinearGradient(colors:[AppColors.primaryDark,AppColors.primary])),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProfileSection(),
              SizedBox(height: 20),
              _buildSettingsOptions(),

              SizedBox(height: 50),
              _buildDangerZone(),
              _buildVersionCard(),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionCard() {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final info    = snap.data!;
        final version = "${info.version} (${info.buildNumber})";

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white70, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Sürüm $version",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildProfileSection() {
    final noPhone = (widget.currentUser.phone ?? '').isEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // hafif cam efekti
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(                    // yumuşak ışık gölgesi
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gradient halo avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.green[700], size: 40),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currentUser.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.mail, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.currentUser.email,
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    if(noPhone)
                      Expanded(
                        child: Text(
                          "+905XXXXXXXX",
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        widget.currentUser.phone ?? "",
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _onEditPressed(),
            icon: const Icon(Icons.edit, color: Colors.white70),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }


  void _onEditPressed() async {
    final updated = await openEditProfileDialog(context, widget.currentUser);
    if (updated != null && mounted) {
      setState(() => widget.currentUser = updated);
    }
  }

  Widget _buildSettingsOptions() {
    return Column(
      children: [
        if ((widget.currentUser.phone ?? '').isEmpty)
          _buildOptionItem(
            Icons.phone_android,
            "Telefon Ekle & Doğrula",
            // Ayarlar sayfasında "Telefon Ekle" butonu:
            () => openPhoneVerify(context, () {
              // ✔️Doğrulama tamamlandı
              setState(() => widget.currentUser =
                  widget.currentUser.copyWith(phone: FirebaseAuth.instance.currentUser?.phoneNumber));
            }),
          ),
        _buildOptionItem(
            Icons.lock_outline, "Şifre Değiştir", _showChangePasswordDialog),
        _buildOptionItem(
          Icons.notifications_active_outlined,
          "Bildirim Ayarları",
          _openNotificationSettings,
        ),

      ],
    );
  }

  void _openNotificationSettings() {
    if (Platform.isAndroid) {
      // Yalnızca Android’ de doğrudan bildirim sayfası
      AppSettings.openAppSettings(type: AppSettingsType.notification);
    } else {
      // iOS (veya eski Android) → genel uygulama ayarları
      AppSettings.openAppSettings();
    }
  }


  Widget _buildOptionItem(
      IconData icon,
      String title,
      VoidCallback onPressed,
      ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      elevation: 0,                             // gölge yok → hafif görünüm
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300), // ince kenarlık
      ),
      color: Colors.grey.shade50,               // çok açık zemin
      child: InkWell(                           // satırın tamamı tıklanabilir
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.green[700], size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              OutlinedButton(                   // hafif buton
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  backgroundColor:Colors.green[50] ,
                  side: BorderSide(color: AppColors.primaryDark.withOpacity(0.8),width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Değiştir',style: TextStyle(color:AppColors.primaryDark),),
              ),
            ],
          ),
        ),
      ),
    );
  }




  /// Uyarı kartı – ‘Hesabı Sil’
  /// Kırmızımsı arka plan + ince border + açıklama metni.
  Widget _buildDangerZone() {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 32, 2, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,                       // yumuşak zemin
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),  // ince çerçeve
        boxShadow: [
          BoxShadow(
            color: Colors.black12,                       // hafif gölge
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade400, size: 28),
              const SizedBox(width: 8),
              Text(
                'Tehlikeli Bölge',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hesabınızı sildiğinizde rezervasyon, abonelik ve profil '
                'verileriniz kalıcı olarak kaldırılır. Bu işlem geri alınamaz.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDeleteAccountDialog(context),
              icon: const Icon(Icons.delete_forever_outlined, size: 22),
              label: const Text('Hesabı Sil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    TextEditingController emailController = TextEditingController();

    _showCustomDialog(
      "Şifre Değiştir",
      [
        {
          'label': "E-posta Adresi",
          'icon': Icons.email,
          'controller': emailController,
          'isPassword': false
        }
      ],
          () async {
        if (emailController.text == widget.currentUser.email) {
          try {
            await sendResetAndLogout(context,emailController.text);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Şifre sıfırlama e-postası gönderildi!")),
            );
          } catch (e) {
            final msg = AppErrorHandler.getMessage(e);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("İşlem başarısız: $msg"),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("E-posta uyuşmadı!")),
          );
        }
        Navigator.pop(context);
      },
    );
  }

  void _showUpdateEmailDialog() {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    _showCustomDialog(
      "E-posta Güncelle",
      [
        {
          'label': "Yeni E-posta",
          'icon': Icons.email,
          'controller': emailController,
          'isPassword': false,
        },
        {
          'label': "Şifrenizi Girin",
          'icon': Icons.lock,
          'controller': passwordController,
          'isPassword': true,
        },
      ],
          () async {
        Navigator.pop(context);
        try {
          await _updateEmail(emailController.text, passwordController.text);
        } catch (e) {
          final msg = AppErrorHandler.getMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("E-posta güncellenemedi: $msg"),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<void> deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcı oturumu bulunamadı.")));
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Kullanıcı bulunamadı.")));
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hesap Başarıyla Silindi")));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hesap silinemedi: $msg"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Bir hata oluştu: $msg"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Hesabı Sil",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Bu işlem geri alınamaz.\nHesabınız ve tüm verileriniz kalıcı olarak silinecek.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("İptal", style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              deleteAccount(context);
            },
            icon: Icon(Icons.delete_forever),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            label: Text("Hesabı Sil"),
          ),
        ],
      ),
    );
  }

  void _showCustomDialog(
      String title, List<Map<String, dynamic>> fields, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700])),
              ...fields.map((field) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _buildTextField(
                  field['label'],
                  field['icon'],
                  field['controller'],
                  isPassword: field['isPassword'] ?? false,
                ),
              )),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDialogButton("İptal", Colors.grey[300]!, Colors.black87,
                          () => Navigator.of(context).pop()),
                  _buildDialogButton(
                      "Onayla", Colors.green[700]!, Colors.white, onConfirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, IconData icon, TextEditingController controller,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.green[700]),
          prefixIcon: Icon(icon, color: Colors.green[700]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildDialogButton(
      String text, Color bgColor, Color textColor, VoidCallback onPressed) {
    return ElevatedButton(
      child: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> sendResetAndLogout(BuildContext context, String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();

    // 1) Şifre sıfırlama linkini dene — Auth güvenlik gereği,
    //    user-not-found hatasını bile yakalarsak bile mesajımız aynı kalacak.
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (_) {
      // (user-not-found dahil) tüm hatalar sessizce yutulur
    }


    // 3) Oturumu kapat
    await FirebaseAuth.instance.signOut();

    // 4) Navigator işlemini bir sonraki frame’de yap (post-frame)
    //    Böylece auth state değişimiyle çakışmaz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthCheckScreen()),
            (_) => false,
      );
    });
  }


  Future<void> _updateEmail(String newEmail, String password) async {
    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kullanıcı oturum açmamış.")),
      );
      return;
    }

    try {
      // Kullanıcı kimlik doğrulaması
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Yeni e-posta için doğrulama bağlantısı gönder
      await user.verifyBeforeUpdateEmail(newEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "E-posta güncelleme bağlantısı gönderildi. Yeni e-postayı doğrulamanız gerekiyor."),
        ),
      );
      _auth.signOut();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => AuthCheckScreen()));
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'auth');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("E-posta güncelleme başarısız: $msg"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  


// Kullanıcının hesabına telefonu bağla + Firestore’u güncelle
  Future<void> _linkPhoneCredential(AuthCredential cred) async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      await user.linkWithCredential(cred);           // Auth tarafı
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        await FirebaseAuth.instance.signInWithCredential(cred);
      } else {
        rethrow;
      }
    }

    // Firestore'da 'phone' alanını güncelle
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'phone': user.phoneNumber});

    // Yerel state
    setState(() => widget.currentUser =
        widget.currentUser.copyWith(phone: user.phoneNumber));

    _showSnack("Telefon doğrulandı!");
  }

// Kısa Snack helper
  void _showSnack(String? msg) {
    if (msg == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }




}
