import 'dart:io';
import 'package:flutter/material.dart';
import 'package:toplansin/ui/views/welcome_screen.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({Key? key}) : super(key: key);

  // İnternet bağlantısını kontrol eden bir fonksiyon
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true; // İnternet bağlantısı var
      }
    } catch (_) {
      return false; // İnternet bağlantısı yok
    }
    return false;
  }

  // Yeniden dene işlevi
  void _retryConnection(BuildContext context) async {
    bool hasInternet = await _checkInternetConnection();
    if (hasInternet) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => WelcomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'İnternet bağlantısı bulunamadı. Lütfen tekrar deneyin.',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Uygulamadan çıkış yapma
  void _exitApp() {
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Geri tuşunu devre dışı bırakmak için
      onWillPop: () async => false,
      child: Scaffold(
        // Durum çubuğunu gizlemek için
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Arka Plan Gradient
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Ana İçerik
            Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 350,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Üst Kısım: İkon Arkaplan
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.wifi_off,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Başlık
                      Text(
                        'Bağlantı Hatası',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Açıklama
                      Text(
                        'İnternet bağlantınız kesildi. Lütfen kontrol edip tekrar deneyin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Butonlar
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _retryConnection(context),
                              icon: const Icon(
                                Icons.refresh,
                                size: 24,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Yeniden Dene',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _exitApp,
                              icon: const Icon(
                                Icons.exit_to_app,
                                size: 24,
                                color: Colors.green,
                              ),
                              label: const Text(
                                'Uygulamadan Çık',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.green.shade600,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Logoyu Arka Planın Altına Yerleştirme
            Positioned(
              bottom: 20, // Ekranın altından 20 piksel yukarıda
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.3,
                  // Şeffaflık oranını buradan ayarlayın (0.0 - 1.0)
                  child: Image.asset(
                    'assets/logo2.png', // Logonuzun dosya yolunu doğrulayın
                    width: 150, // Logonuzun genişliğini ayarlayın
                    height: 150, // Logonuzun yüksekliğini ayarlayın
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
