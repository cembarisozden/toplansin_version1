// auth_check_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/services/notification_service.dart';
import 'package:toplansin/ui/owner_views/owner_main_page.dart';
import 'package:toplansin/ui/user_views/main_page.dart';
import 'package:toplansin/ui/views/login_page.dart';

/// Uygulama açıldığında:
///  1. authStateChanges() > kullanıcı var mı?
///  2. varsa Firestore’da rolü çek.
///  3. rolüne göre ilgili ana sayfayı döndür.
///
/// Hata, boş veri, yükleniyor durumlarının hepsi tek yerde yönetilir.
class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        /* ── 1. Auth bekleniyor ── */
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }

        /* ── 2. Kullanıcı yoksa Login ── */
        if (!authSnap.hasData || authSnap.data == null || !authSnap.data!.emailVerified) {
          return  LoginPage();
        }

        final uid = authSnap.data!.uid;
        final user = authSnap.data!;
        if (!user.emailVerified) {
          return const _ErrorScreen("E-posta adresinizi doğrulamanız gerekiyor.");
        }

        // Token sadece doğrulanmış kullanıcılar için kaydedilir
        if (user.emailVerified) {
          NotificationService.I.saveTokenToFirestore();
        }

        /* ── 4. Rolü sunucudan çek ── */
        return FutureBuilder<Person?>(
          future: _fetchPersonWithRetry(uid),
          builder: (context, personSnap) {
            if (personSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }

            if (personSnap.hasError ||
                !personSnap.hasData ||
                personSnap.data == null) {
              return const _ErrorScreen('Kullanıcı bilgileri bulunamadı.');
            }

            final person = personSnap.data!;

            switch (person.role) {
              case 'owner':
                return OwnerMainPage(currentOwner: person);
              case 'user':
                return MainPage(currentUser: person);
              default:
                return const _ErrorScreen('Bilinmeyen kullanıcı rolü.');
            }
          },
        );
      },
    );
  }

  Future<Person?> _fetchPersonWithRetry(String uid) async {
    const retries = 10;
    const delay = Duration(milliseconds: 500);

    for (int i = 0; i < retries; i++) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      final data = snap.data();
      print('[RETRY $i] uid=$uid => data: $data');

      if (snap.exists && data != null && data['role'] != null) {
        return Person.fromMap(data);
      }

      await Future.delayed(delay);
    }

    print('Kullanıcı verisi 10 denemede de alınamadı');
    return null;
  }

}


/* ——————————————————————— yardımcı lightweight widget'lar ——————————————————————— */

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              SizedBox(height: 16),
              Text(
                "Bir hata oluştu",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LoginPage())); // ya da ana sayfa rotası
                },
                icon: Icon(Icons.logout),
                label: Text("Çıkış yap"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

