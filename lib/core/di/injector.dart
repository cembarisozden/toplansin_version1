import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:toplansin/features/team_fill/data/datasources/fill_request_firestore_ds.dart';
import 'package:toplansin/features/team_fill/data/repositories/fill_request_repository_impl.dart';
import 'package:toplansin/features/team_fill/domain/repositories/fill_request_repository.dart';
import 'package:toplansin/features/team_fill/domain/usecases/list_open_requests.dart';

final sl = GetIt.instance;

Future<void> setup() async {
  // tekrar kayıtları önlemek için guard
  if (!sl.isRegistered<FillRequestFirestoreDs>()) {
    sl.registerLazySingleton<FillRequestFirestoreDs>(
          () => FillRequestFirestoreDs(FirebaseFirestore.instance),
    );
  }

  if (!sl.isRegistered<FillRequestRepository>()) {
    sl.registerLazySingleton<FillRequestRepository>(
          () => FillRequestRepositoryImpl(sl<FillRequestFirestoreDs>()),
    );
  }

  if (!sl.isRegistered<ListOpenRequests>()) {
    sl.registerFactory<ListOpenRequests>(() => ListOpenRequests(sl()));
  }
}
