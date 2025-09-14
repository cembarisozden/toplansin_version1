import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';
import 'package:toplansin/features/team_fill/domain/repositories/fill_request_repository.dart';

class ListOpenRequests {
  final FillRequestRepository _repo;

  ListOpenRequests(this._repo);

  Stream<List<FillRequest>> call({
    String? city,
    int limit = 50,
  }) {
    if (city != null && city.trim().isEmpty) {
      throw ArgumentError('city cannot be empty string');
    }

    return _repo.listOpen(city: city, limit: limit);
  }
}
