import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/services/reservation_remote_service.dart';
import 'package:toplansin/ui/user_views/dialogs/edit_profile_dialog.dart';
import 'package:toplansin/ui/user_views/dialogs/phone_verify_dialog.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';



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
        decoration: BoxDecoration(gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary])),
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

        final info = snap.data!;
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
          BoxShadow( // yumuşak ışık gölgesi
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
        if ((_auth.currentUser?.phoneNumber ?? '').isEmpty)
          _buildOptionItem(
            Icons.phone_android,
            "Telefon Ekle & Doğrula",
            // Ayarlar sayfasında "Telefon Ekle" butonu:
                () =>
                openPhoneVerify(context, () {
                  // ✔️Doğrulama tamamlandı
                  setState(() =>
                  widget.currentUser =
                      widget.currentUser.copyWith(
                          phone: FirebaseAuth.instance.currentUser
                              ?.phoneNumber));
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
    if (Platform.isAndroid || Platform.isIOS) {
      openAppSettings(); // uygulamanın ayar ekranını açar
    }
  }


  Widget _buildOptionItem(IconData icon,
      String title,
      VoidCallback onPressed,) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      elevation: 0,
      // gölge yok → hafif görünüm
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300), // ince kenarlık
      ),
      color: Colors.grey.shade50,
      // çok açık zemin
      child: InkWell( // satırın tamamı tıklanabilir
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
              OutlinedButton( // hafif buton
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.green[50],
                  side: BorderSide(
                      color: AppColors.primaryDark.withOpacity(0.8),
                      width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Değiştir', style: TextStyle(color: AppColors.primaryDark),),
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
        color: Colors.white, // yumuşak zemin
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200), // ince çerçeve
        boxShadow: [
          BoxShadow(
            color: Colors.black12, // hafif gölge
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
              onPressed: () => showDeleteAccountDialog(),
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
            await sendResetAndLogout(context, emailController.text);
            AppSnackBar.show(context, "Şifre sıfırlama e-postası gönderildi!");
          } catch (e) {
            final msg = AppErrorHandler.getMessage(e);
            AppSnackBar.error(context,"İşlem başarısız: $msg");
          }
        } else {
          AppSnackBar.error(context, "E-posta uyuşmadı!");
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
          AppSnackBar.error(context, "E-posta güncellenemedi: $msg");
        }
      },
    );
  }
// 1) Hesap silme dialogu
  // 1) Hesap silme dialogu
  Future<void> showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      AppSnackBar.error(context, "Kullanıcı oturumu bulunamadı.");
      return;
    }

    String? authError; // Şifre hatası mesajı

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    "Hesabı silmek üzeresiniz",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Lütfen şifrenizi girerek onaylayın.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Şifre",
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      errorText: authError,
                    ),
                    validator: (v) =>
                    v == null || v.isEmpty ? "Şifre gerekli" : null,
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text("İptal"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          Navigator.of(dialogContext).pop();
                          // Aşağıdaki helper fonksiyon silme + yönlendirmeyi yapacak
                          await _deleteAccountWithPassword(
                            user.email!,
                            passwordController.text,
                          );
                        },
                        child: Text("Sil", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

// ————————————————————————————————————————————————

  Future<void> _deleteAccountWithPassword(String email, String password) async {
    showLoader(context);
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final user = auth.currentUser;
    final cred = EmailAuthProvider.credential(email: email, password: password);

    try {
      // 1) Re-auth
      await user!.reauthenticateWithCredential(cred);

      // 2) Açık REZERVASYONLARI iptal et (PENDING/APPROVED → CANCELLED)
      await _cancelAllUserReservations(db, user.uid);

      // 3) Açık ABONELİKLERİ iptal et (Beklemede/Aktif → İptal Edildi)
      await _cancelAllUserSubscriptions(db, user.uid);

      // 4) (Opsiyonel) arşiv callable – silmeden ÖNCE
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('userDeletionServiceArchive');
      final userDoc = await db.collection('users').doc(user.uid).get();
      final data = userDoc.data();

      await callable.call({
        'user': {
          'id': user.uid,
          'name': data?['name'] ?? '',
          'email': data?['email'] ?? user.email ?? '',
          'phone': data?['phone'],
          'role': data?['role'] ?? 'user',
          'fieldAccessCodes': data?['fieldAccessCodes'],
        }
      });

      // 5) users/{uid} sil
      await db.collection('users').doc(user.uid).delete();

      // 6) Auth hesabını sil
      await user.delete();

      AppSnackBar.show(context, "Hesabınız başarıyla silindi.");

      // 7) Yönlendirme
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen()),
            (route) => false,
      );
    } on FirebaseFunctionsException {
      AppSnackBar.error(context, "Arşivleme başarısız olduğu için silme durduruldu.");
    } on FirebaseAuthException catch (_) {
      AppSnackBar.error(context, "Silme başarısız.");
    } catch (e) {
      AppSnackBar.error(context, "Bir hata oluştu: $e");
    } finally {
      hideLoader();
    }
  }

  /// Beklemede/Onaylandı durumundaki tüm rezervasyonları,
  /// slot'u da boşaltarak "İptal Edildi" yapar.
  Future<void> _cancelAllUserReservations(
      FirebaseFirestore db,
      String uid,
      ) async {
    const pendingStatuses = ['Beklemede', 'Onaylandı'];

    final resSnap = await db
        .collection('reservations')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: pendingStatuses)
        .get();

    if (resSnap.docs.isEmpty) return;

    final batch = db.batch();

    for (final d in resSnap.docs) {
      final data = d.data();

      // Şema alanları: projene göre isimler doğruysa aynen bırak
      final String? haliSahaId = data['haliSahaId'] as String?;
      final String? reservationDateTime = data['reservationDateTime'] as String?;

      if (haliSahaId == null || reservationDateTime == null) {
        debugPrint('⚠️ Eksik alanlar: ${d.id} (haliSahaId/reservationDateTime)');
        continue;
      }

      // 1) Slot'u bookedSlots'tan sil (callable)
      final ok = await ReservationRemoteService().cancelSlot(
        haliSahaId: haliSahaId,
        bookingString: reservationDateTime, // ← alan adı güncellendi
      );

      // 2) Slot başarıyla boşaltıldıysa statüyü iptal et
      if (ok) {
        batch.update(d.reference, {
          'status': 'İptal Edildi',
          'lastUpdateBy': 'user',
          'cancelReason': 'Hesap Silindi',
        });
      } else {
        debugPrint('❌ Slot boşaltılamadı, status güncellenmedi: ${d.id}');
      }
    }

    await batch.commit();
  }


  Future<void> _cancelAllUserSubscriptions(FirebaseFirestore db, String uid) async {
    // Türkçe statülerini uygula
    const openSubs = ['Beklemede', 'Aktif'];
    final subSnap = await db
        .collection('subscriptions')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: openSubs)
        .get();

    if (subSnap.docs.isEmpty) return;

    final batch = db.batch();
    for (final d in subSnap.docs) {
      batch.update(d.reference, {
        'status': 'İptal Edildi',
        'lastUpdateBy' : 'user',
      });
    }
    await batch.commit();
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
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.primaryDark)),
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
      await sendPasswordResetEmail(email);
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
  Future<void> sendPasswordResetEmail(String email) async {
    // Bölgeyi mutlaka seninkiyle aynı ver: "europe-west1"
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable('sendPasswordResetEmail');

    try {
      final res = await callable.call<Map<String, dynamic>>({'email': email});
      // res.data => {"ok": true} bekleniyor
      // burada kullanıcıya başarı mesajı gösterebilirsin.
      // AppSnackBar.show(context, "Şifre sıfırlama maili gönderildi.");
    } on FirebaseFunctionsException catch (e) {
      final msg = switch (e.code) {
        'invalid-argument' => 'E-posta adresi geçersiz.',
        'failed-precondition' => 'Sunucu yapılandırması eksik (RESEND_API_KEY vb.).',
        _ => e.message ?? 'Beklenmeyen bir hata oluştu.'
      };
      rethrow; // ya da kullanıcıya göster
    } catch (e) {
      AppSnackBar.error(context, "Bağlantı hatası. Lütfen tekrar deneyin.");
      rethrow;
    }
  }



  Future<void> _updateEmail(String newEmail, String password) async {
    User? user = _auth.currentUser;
    if (user == null) {
     AppSnackBar.error(context,"Kullanıcı oturum açmamış.");
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

      AppSnackBar.show(context, "E-posta güncelleme bağlantısı gönderildi. Yeni e-postayı doğrulamanız gerekiyor.");
      _auth.signOut();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => AuthCheckScreen()));
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e, context: 'auth');

      AppSnackBar.error(context, "E-posta güncelleme başarısız: $msg");
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

    AppSnackBar.success(context,"Telefon doğrulandı!");
  }

// Kısa Snack helper




}
