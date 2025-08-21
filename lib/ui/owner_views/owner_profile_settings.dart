// lib/ui/views/account_settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';

class OwnerProfileSettings extends StatefulWidget {
  final Person currentOwner;

  OwnerProfileSettings({required this.currentOwner});

  @override
  _OwnerProfileSettingsState createState() => _OwnerProfileSettingsState();
}

class _OwnerProfileSettingsState extends State<OwnerProfileSettings> {
  final _formKey = GlobalKey<FormState>();
  late String name;
  late String phone;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    name = widget.currentOwner.name;
    phone = widget.currentOwner.phone ?? "";
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        isLoading = true;
      });
      try {
        // Firestore'da kullanıcı bilgilerini güncelleme
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentOwner.id)
            .update({
          'name': name,
          'phone': phone,
        });

        // Firebase Authentication'da displayName güncelleme
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

        AppSnackBar.success(context,'Profil başarıyla güncellendi.');
      } catch (e) {
        final msg = AppErrorHandler.getMessage(e, context: 'user');

        AppSnackBar.error(context,'Profil güncellenemedi: $msg');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hesap Ayarları"),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: Column(
            children: [
              // İsim Güncelleme
              TextFormField(
                initialValue: name,
                decoration: InputDecoration(
                  labelText: 'İsim',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => name = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'İsim boş olamaz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // Telefon Güncelleme
              TextFormField(
                initialValue: phone,
                decoration: InputDecoration(
                  labelText: 'Telefon',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onSaved: (value) => phone = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Telefon numarası boş olamaz';
                  }
                  if (!RegExp(r'^\d{10,15}$').hasMatch(value)) {
                    return 'Geçerli bir telefon numarası giriniz';
                  }
                  return null;
                },
              ),
              SizedBox(height: 32),
              // Profil Güncelleme Butonu
              ElevatedButton(
                onPressed: _updateProfile,
                child: Text('Profili Güncelle'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
