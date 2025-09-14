import 'package:toplansin/features/team_fill/data/datasources/fill_request_firestore_ds.dart';
import 'package:toplansin/features/team_fill/data/dto/fill_request_dto.dart';
import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';
import 'package:toplansin/features/team_fill/domain/repositories/fill_request_repository.dart';

class FillRequestRepositoryImpl extends FillRequestRepository {

  final FillRequestFirestoreDs _ds;

  FillRequestRepositoryImpl(this._ds);

  @override
  Stream<List<FillRequest>> listOpen ({String? city, int limit = 50}){

    final Stream<List<FillRequestDto>> dtoStream = _ds.listOpen(city: city, limit: limit);

    return dtoStream.map((dtos)=>dtos.map((d)=>d.toEntity()).toList());
  }

}