import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityService {
  ConnectivityService._() {
    _init();
  }

  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();

  // 🔑 Özel ayarlanmış InternetConnectionChecker
  late final InternetConnectionChecker _checker =
  InternetConnectionChecker.createInstance(
    checkTimeout: const Duration(seconds: 3),
    checkInterval: const Duration(seconds: 3),
    addresses: [
      AddressCheckOption(
        uri: Uri.parse('https://google.com'),
        timeout: const Duration(seconds: 3),
      ),
      AddressCheckOption(
        uri: Uri.parse('https://cloudflare.com'),
        timeout: const Duration(seconds: 3),
      ),
    ],
  );

  final _controller = StreamController<bool>.broadcast();
  late final Stream<bool> connectivity$ = _controller.stream;

  bool _initialCheckDone = false; // ✅ EKLENDİ

  void _init() async {
    // 1. İlk bağlantıyı kontrol et
    final firstStatus = await _checker.hasConnection;
    _controller.add(firstStatus);
    _initialCheckDone = true; // ✅ EKLENDİ

    // 2. Ağ değişikliklerini dinle
    _connectivity.onConnectivityChanged.listen((_) async {
      if (!_initialCheckDone) return; // ✅ İlk event’i yut
      final hasConnection = await _checker.hasConnection;
      _controller.add(hasConnection);
    });

    // 3. Checker'ın status akışını da dinle (daha sık tetiklenebilir)
    _checker.onStatusChange.listen((status) {
      if (!_initialCheckDone) return; // ✅ İlk event’i yut
      final isConnected = status == InternetConnectionStatus.connected;
      _controller.add(isConnected);
    });
  }

  void dispose() {
    _controller.close();
  }
}
