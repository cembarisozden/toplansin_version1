import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/login_page.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';
import 'package:toplansin/ui/user_views/dialogs/phone_verify_dialog.dart';


class UserSettingsPage extends StatefulWidget {
  final Person currentUser;

  UserSettingsPage({required this.currentUser});

  @override
  _UserSettingsPageState createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[700],
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.green),
        ),
        backgroundColor: Colors.white,
        title: Text('Ayarlar', style: TextStyle(color: Colors.green)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileSection(),
            SizedBox(height: 20),
            _buildSettingsOptions(),
            SizedBox(height: 50),
            _buildDangerZone(),
            SizedBox(height: 30),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.green[800], size: 40),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.currentUser.name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                widget.currentUser.email,
                style: TextStyle(color: Colors.green[200]),
              ),
              Text(
                widget.currentUser.phone,
                style: TextStyle(color: Colors.green[200]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOptions() {
    return Column(
      children: [
        _buildOptionItem(
            Icons.lock, "Şifre Değiştir", _showChangePasswordDialog),
        _buildOptionItem(
            Icons.email, "E-posta Güncelle", _showUpdateEmailDialog),
       _buildOptionItem(
           Icons.phone, "Telefon Numarasını Güncelle", _showChangePhoneDialog),

       /* _buildOptionItem(
          Icons.verified_user,
          "Telefon Numarasını Doğrula",
              () => _showPhoneVerifyDialog(context, initialPhone: widget.currentUser.phone),
        ),*/
      ],
    );
  }

  /// Dialog fonksiyonu (transition + AnimatedSwitcher)
  _showPhoneVerifyDialog(BuildContext context, {String? initialPhone}) {
    showDialog(
      context: context,
      builder: (context) => PhoneVerifyDialog(initialPhone: initialPhone),
    );
  }





  Widget _buildOptionItem(IconData icon, String title, VoidCallback onPressed) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: TextStyle(color: Colors.white)),
      trailing: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.green[700],
        ),
        child: Text("Değiştir"),
      ),
    );
  }


  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tehlikeli Bölge",
          style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent[400],
            foregroundColor: Colors.red[900],
            minimumSize: Size(double.infinity, 48),
          ),
          onPressed: () => _showDeleteAccountDialog(context),
          icon:Icon(Icons.delete_forever,size: 25,color: Colors.white,),
          label: Text("Hesabı Sil",style:TextStyle(color: Colors.white,),)
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      onPressed: () {
        _auth.signOut();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => WelcomeScreen()));
      },
      icon: Icon(Icons.logout, color: Colors.red[900]),
      label: Text("Çıkış Yap", style: TextStyle(color: Colors.red[900])),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red[900],
        minimumSize: Size(double.infinity, 48),
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

  void _showChangePhoneDialog() {
    TextEditingController phoneController = TextEditingController();

    _showCustomDialog(
      "Telefon Numarası Değiştir",
      [
        {
          'label': "Yeni Telefon Numarası",
          'icon': Icons.phone,
          'controller': phoneController,
          'isPassword': false,
        },
      ],
          () async {
        Navigator.pop(context);

        try {
          await _updatePhoneNumber(phoneController.text);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Telefon numarası başarıyla güncellendi: ${phoneController.text}")),
          );
        } catch (e) {
          final msg = AppErrorHandler.getMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Telefon numarası güncellenemedi: $msg")),
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

  Future<void> _updatePhoneNumber(String newPhoneNumber) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("Kullanıcı oturum açmamış.");
    }

    try {
      // Firestore'daki kullanıcı verisini güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'phone': newPhoneNumber,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Telefon numarası başarıyla güncellendi!")),
      );
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'user');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Telefon numarası güncellenemedi: $msg"),
          backgroundColor: Colors.red,
        ),
      );
    }

  }



}
