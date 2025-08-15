import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global klavye yardımcıları
class KeyboardKit {
  /// Klavyeyi kapat ve odakları sıfırla
  static Future<void> closeKeyboard(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // TextInput kanalını da kapat (bazı cihazlarda şart)
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    // En az bir frame bekle
    await Future.delayed(const Duration(milliseconds: 16));
  }

  /// Klavye kapalıyken push et (otomatik kapatır)
  static Future<T?> pushWhileKeyboardClosed<T>(
      BuildContext context,
      Route<T> route,
      ) async {
    await closeKeyboard(context);
    return Navigator.of(context).push(route);
  }
}

/// Navigator observer: her geçişte klavyeyi kapatır
class KeyboardUnfocusObserver extends NavigatorObserver {
  Future<void> _safeClose() async {
    final ctx = navigator?.context;
    if (ctx == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 16));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _safeClose();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _safeClose();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _safeClose();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _safeClose();
    super.didRemove(route, previousRoute);
  }
}
