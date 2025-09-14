import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';

abstract class FillRequestRepository{
  Stream<List<FillRequest>> listOpen({String? city,int limit});
}