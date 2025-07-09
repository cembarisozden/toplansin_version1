import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/core/providers/PhoneVerificationProvider.dart';

class PhoneVerifyDialog extends StatefulWidget {
  final String? initialPhone;

  const PhoneVerifyDialog({Key? key, this.initialPhone}) : super(key: key);

  @override
  State<PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends State<PhoneVerifyDialog> {
  int _step = 0;          // 0: phone entry, 1: code entry
  int _remaining = 0;     // resend countdown
  Timer? _timer;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();

  // Remove all non-digits, strip leading “90” or “0”
  String _digits(String? raw) {
    if (raw == null) return '';
    var n = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('90')) n = n.substring(2);
    if (n.startsWith('0'))  n = n.substring(1);
    return n.length > 10 ? n.substring(n.length - 10) : n;
  }

  bool _validInput(String v) => RegExp(r'^[5-9][0-9]{9}$').hasMatch(v);

  String get _phoneE164 => '+90${_digits(_phoneCtrl.text)}';
  bool   get _phoneChanged =>
      _digits(widget.initialPhone) != _digits(_phoneCtrl.text);

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneCtrl.text = _digits(widget.initialPhone!);
    }
    _phoneCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _remaining = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (--_remaining == 0) t.cancel();
      setState(() {});
    });
  }

  Future<void> _verifyOrUpdate() async {
    final auth = context.read<PhoneVerificationProvider>();

    // If phone changed, update Firestore first
    if (_phoneChanged) {
      await auth.updatePhoneNumber(_phoneE164);
      if (auth.error != null) return;
    }

    // Send the SMS
    await auth.verifyPhone(_phoneE164);
    if (auth.error != null) return;

    _startTimer();
    setState(() => _step = 1);
  }

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) return;

    final success = await context
        .read<PhoneVerificationProvider>()
        .verifyOtp(code);

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _btn(String text, Color bg, VoidCallback onTap, {bool disabled = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? Colors.grey : bg,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: disabled ? null : onTap,
      child: Text(text),
    );
  }

  Widget _field(
      String label,
      IconData icon,
      TextEditingController controller, {
        bool isNumber = false,
        String? prefix,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        maxLength: isNumber ? 10 : null,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [
          FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((oldV, newV) {
            final cleaned = _digits(newV.text);
            return TextEditingValue(
              text: cleaned,
              selection: TextSelection.collapsed(offset: cleaned.length),
            );
          }),
        ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixText: prefix,
          prefixIcon: Icon(icon, color: Colors.green[700]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<PhoneVerificationProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 0
              ? _buildPhoneStep(auth)
              : _buildCodeStep(auth),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(PhoneVerificationProvider auth) {
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Telefonu Doğrula',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700]),
        ),
        const SizedBox(height: 20),
        _field('Telefon (5xxxxxxxx)', Icons.phone, _phoneCtrl, isNumber: true, prefix: '+90 '),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _btn('İptal', Colors.grey, () => Navigator.pop(context)),
            _btn(
              _phoneChanged ? 'Güncelle' : 'Onayla',
              Colors.green,
              _verifyOrUpdate,
              disabled: !_validInput(_phoneCtrl.text) || auth.isVerifying,
            ),
          ],
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 10),
          Text(AppErrorHandler.getMessage(auth.error!), style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildCodeStep(PhoneVerificationProvider auth) {
    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Kod Gönderildi',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700]),
        ),
        const SizedBox(height: 20),
        _field('SMS Kodu', Icons.sms, _codeCtrl, isNumber: true),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _remaining > 0
                  ? '00:${_remaining.toString().padLeft(2, '0')}'
                  : 'Süre doldu',
            ),
            TextButton(
              onPressed: (_remaining == 0 && !auth.isVerifying) ? _verifyOrUpdate : null,
              child: const Text('Tekrar Gönder'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _btn('İptal', Colors.grey, () => Navigator.pop(context)),
            _btn(
              'Doğrula',
              Colors.green,
              _submitCode,
              disabled: auth.isVerifying || _codeCtrl.text.trim().length < 6,
            ),
          ],
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 10),
          Text(AppErrorHandler.getMessage(auth.error!), style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}
