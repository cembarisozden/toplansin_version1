import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class ConnectivityService {
  ConnectivityService._();

  static ConnectivityService? _instance;
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    // Lazy init - ilk erişimde başlat
    _instance!._ensureInitialized();
    return _instance!;
  }

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

  bool _initialized = false;
  bool _initialCheckDone = false;

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _init();
  }

  void _init() async {
    try {
      // 1. İlk bağlantıyı kontrol et
      final firstStatus = await _checker.hasConnection;
      _controller.add(firstStatus);
      _initialCheckDone = true;

      // 2. Ağ değişikliklerini dinle
      _connectivity.onConnectivityChanged.listen((_) async {
        if (!_initialCheckDone) return;
        try {
          final hasConnection = await _checker.hasConnection;
          _controller.add(hasConnection);
        } catch (e) {
          debugPrint('⚠️ Connectivity check error: $e');
        }
      });

      // 3. Checker'ın status akışını da dinle
      _checker.onStatusChange.listen((status) {
        if (!_initialCheckDone) return;
        final isConnected = status == InternetConnectionStatus.connected;
        _controller.add(isConnected);
      });
    } catch (e) {
      debugPrint('⚠️ ConnectivityService init error: $e');
      // Hata durumunda online varsay
      _controller.add(true);
      _initialCheckDone = true;
    }
  }

  void dispose() {
    _controller.close();
  }
}
