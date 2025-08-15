import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';

class OwnerActivateCodeWithUsersProvider extends ChangeNotifier {
  bool isLoading = false;
  List<Person> users = [];
  final _db = FirebaseFirestore.instance;

  Future<void> fetchUsersByActiveCode(
      String sahaId, BuildContext context) async {
    isLoading = true;
    notifyListeners();

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('listUsersByActiveCode');

      final result = await callable.call({'sahaId': sahaId});

      if (result.data is List) {
        users = (result.data as List)
            .map((e) => Person.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        users = [];
      }
    } on FirebaseFunctionsException catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
      users = [];
    } catch (e) {
      AppSnackBar.error(context, AppErrorHandler.getMessage(e));
      users = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> deleteUsersByActivateCode(
      String userId, String sahaId, BuildContext context) async {
    try {
      isLoading = true;
      notifyListeners();

      final function = FirebaseFunctions.instance
          .httpsCallable('deleteUsersByActiveCode');

      final result = await function.call({
        'userId': userId,
        'sahaId': sahaId,
      });

      users.removeWhere((u) => u.id == userId); // Map tutuyorsan: (u) => u['uid'] == userId
      notifyListeners();

      debugPrint("✅ Kod silme sonucu: ${result.data}");
     AppSnackBar.success(context,'Kod başarıyla silindi.');
    } catch (e) {
      AppSnackBar.error(context, 'Kod silinirken hata oluştu.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

}
