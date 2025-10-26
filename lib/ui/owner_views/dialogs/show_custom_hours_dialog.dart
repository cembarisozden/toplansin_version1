import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toplansin/data/entitiy/start_end_hours.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';

Future<Map<String, Map<String, String>>?> showCustomHoursDialog({
  required BuildContext context,
  required String haliSahaId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,                 // üstteki safe area boşluklarını alma
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false, // kendi insets’ini eklemesin
        body: MediaQuery.removePadding(
          context: ctx,
          removeTop: true,
          removeBottom: true,
          child: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (_, constraints) {
                return Align(
                  alignment: Alignment.bottomCenter, // ALTA sabitle
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: 0.88,              // eski %88 yükseklik
                    child: _CustomHoursSheet(
                      haliSahaId: haliSahaId,
                      context: context,              // parent gerekirse
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );


}

class _CustomHoursSheet extends StatefulWidget {
  final String haliSahaId;
  final BuildContext context;

  const _CustomHoursSheet({super.key, required this.haliSahaId, required this.context});

  @override
  State<_CustomHoursSheet> createState() => _CustomHoursSheetState();
}

class _CustomHoursSheetState extends State<_CustomHoursSheet> {
  final _formKey = GlobalKey<FormState>();

  final List<int> _days = const [0, 1, 2, 3, 4, 5, 6];

  late final Map<int, TextEditingController> _startCtrls;
  late final Map<int, TextEditingController> _endCtrls;

  // 🔹 PREFILL durumları
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _startCtrls = {for (final d in _days) d: TextEditingController()};
    _endCtrls = {for (final d in _days) d: TextEditingController()};
    _prefillFromFirestore(); // 🔹 mevcut verileri çek
  }

  Future<void> _prefillFromFirestore() async {
    try {
      final col = FirebaseFirestore.instance
          .collection("hali_sahalar")
          .doc(widget.haliSahaId)
          .collection("start_end_hours");

      final snap = await col.get();

      for (final doc in snap.docs) {
        // Tercihen doc id'yi 0..6 tutuyoruz; değilse 'day' alanına bakar.
        final data = doc.data();
        final parsedId = int.tryParse(doc.id);
        final int day =
            parsedId ?? (data['day'] is int ? data['day'] as int : -1);

        if (!_days.contains(day)) continue;

        final start = (data['startHour'] as String?) ?? '';
        final end = (data['endHour'] as String?) ?? '';
        _startCtrls[day]?.text = start;
        _endCtrls[day]?.text = end;
      }

      setState(() {
        _loading = false;
        _loadError = null;
      });
    } on FirebaseException catch (e) {
      setState(() {
        _loading = false;
        _loadError = e.message ?? e.code;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = 'Bilinmeyen hata';
      });
    }
  }

  @override
  void dispose() {
    for (final c in _startCtrls.values) {
      c.dispose();
    }
    for (final c in _endCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _timeValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // boş bırakmaya izin (opsiyonel)
    final reg = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$'); // HH:MM
    if (!reg.hasMatch(v.trim())) return "Geçerli saat biçimi: 20:00";
    return null;
  }

  // 12 -> 12:  123 -> 12:3  1234 -> 12:34  (sadece sayı ve :)
  TextInputFormatter get _hhmmMask => TextInputFormatter.withFunction(
        (oldValue, newValue) {
      // 🔹 Sadece rakamlar ve ':' izinli
      var t = newValue.text.replaceAll(RegExp(r'[^0-9:]'), '');

      // 🔹 Fazla ':' varsa ilkini bırak diğerlerini sil
      if (':'.allMatches(t).length > 1) {
        final firstColon = t.indexOf(':');
        t = t.substring(0, firstColon + 1) +
            t.substring(firstColon + 1).replaceAll(':', '');
      }

      // 🔹 ':' yoksa ve 3–4 karakter girilmişse otomatik yerleştir
      if (!t.contains(':') && t.length > 2) {
        t = '${t.substring(0, 2)}:${t.substring(2)}';
      }

      // 🔹 Toplam uzunluk en fazla 5 karakter (HH:MM)
      if (t.length > 5) t = t.substring(0, 5);

      return TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    },
  );

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    hintText: "20:00",
    filled: true,
    fillColor: Colors.white,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final height = mq.size.height * 0.88; // Ekranın çoğunu kaplasın

    return Container(
      height: height,
      padding: EdgeInsets.only(
        bottom: mq.viewInsets.bottom, // klavye için
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        // Şık gradient arkaplan
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1ABC9C), Color(0xFF2ECC71)],
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Özel Saat Bilgileri",
                      style: AppTextStyles.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  )
                ],
              ),
            ),

            // İçerik
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_loadError != null
                    ? Center(
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Veriler yüklenemedi: $_loadError',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                    : Form(
                  key: _formKey,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        16, 16, 16, 120),
                    itemCount: _days.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final day = _days[i];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                              color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayInString(day),
                                style: AppTextStyles.titleMedium
                                    .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _startCtrls[day],
                                      keyboardType:
                                      TextInputType.number,
                                      inputFormatters: [
                                        _hhmmMask,
                                        LengthLimitingTextInputFormatter(
                                            5),
                                      ],
                                      validator: _timeValidator,
                                      decoration:
                                      _decor("Başlangıç"),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _endCtrls[day],
                                      keyboardType:
                                      TextInputType.number,
                                      inputFormatters: [
                                        _hhmmMask,
                                        LengthLimitingTextInputFormatter(
                                            5),
                                      ],
                                      validator: _timeValidator,
                                      decoration: _decor("Bitiş"),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Biçim: HH:MM (örn. 20:00)",
                                style: AppTextStyles.bodySmall
                                    .copyWith(
                                    color:
                                    Colors.grey.shade500),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )),
              ),
            ),

            // Alt sabit butonlar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text("İptal"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;

                        // Klavyeyi kapat (snackbar görünürlüğü için iyi)
                        FocusScope.of(context).unfocus();

                        // ❗ İSTENEN KURAL:
                        // Tüm günlerde hem başlangıç hem bitiş DOLU olmalı.
                        // Aksi halde batch YAPILMAYACAK, AppSnackBar ile hata verilecek.
                        for (final d in _days) {
                          final s = _startCtrls[d]!.text.trim();
                          final e = _endCtrls[d]!.text.trim();
                          print(s);
                          print(e);
                          if (s.isEmpty || e.isEmpty) {
                            AppSnackBar.error(
                              context,
                              '${dayInString(d)} için başlangıç ve bitiş saatlerini eksiksiz girin.',
                            );
                            return; // erken çık, batch yok
                          }
                        }

                        try {
                          showLoader(context);
                          // 1) Batch başlat
                          final batch =
                          FirebaseFirestore.instance.batch();

                          final baseCol = FirebaseFirestore.instance
                              .collection("hali_sahalar")
                              .doc(widget.haliSahaId)
                              .collection("start_end_hours");

                          // 2) Tüm günler dolu → batch'e ekle
                          for (final d in _days) {
                            final s = _startCtrls[d]!.text.trim();
                            final e = _endCtrls[d]!.text.trim();

                            final docRef =
                            baseCol.doc(d.toString()); // deterministik id

                            final data = {
                              "day": d,
                              "startHour": s,
                              "endHour": e,
                            };

                            batch.set(
                              docRef,
                              data,
                              SetOptions(merge: true),
                            );
                          }

                          // 3) Tek seferde yaz
                          await batch.commit();

                          AppSnackBar.success(
                              context, "Başarıyla kaydedildi");

                          // 4) Kapat
                          if (mounted) Navigator.of(context).pop();
                        } on FirebaseException catch (e) {
                          AppSnackBar.error(context, "Kaydetme hatası");
                          debugPrint(
                              '⚠️ Firestore hata: ${e.code} - ${e.message}');
                        } catch (e) {
                          debugPrint('⚠️ Beklenmeyen hata: $e');
                          AppSnackBar.error(
                              context, 'Beklenmeyen bir hata oluştu');
                        }finally{
                          hideLoader();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2ECC71),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(.15),
                      ),
                      child: const Text(
                        "Kaydet",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String dayInString(int day) {
    switch (day) {
      case 0:
        return "Pazartesi";
      case 1:
        return "Salı";
      case 2:
        return "Çarşamba";
      case 3:
        return "Perşembe";
      case 4:
        return "Cuma";
      case 5:
        return "Cumartesi";
      case 6:
        return "Pazar";
      default:
        return "";
    }
  }
}
