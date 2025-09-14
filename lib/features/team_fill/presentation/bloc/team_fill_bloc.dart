import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart'; // restartable()
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';
import 'package:toplansin/features/team_fill/domain/usecases/list_open_requests.dart';
import 'package:toplansin/features/team_fill/presentation/bloc/team_fill_event.dart';
import 'package:toplansin/features/team_fill/presentation/bloc/team_fill_state.dart';

/// TeamFillBloc:
/// - UI'dan Event alır (Started / CityChanged / Retry)
/// - UseCase stream'ine bağlanır (şehir yoksa Türkiye geneli)
/// - Stream'den gelen veriye göre State üretir (Loading / Data / Empty / Error)

class TeamFillBloc extends Bloc<TeamFillEvent, TeamFillState> {
  TeamFillBloc(this._listOpen) : super(const TeamFillInitial()) {
    on<TeamFillStarted>(_onStarted, transformer: restartable());
    on<TeamFillCityChanged>(_onCityChanged, transformer: restartable());
    on<TeamFillRetryRequested>(_onRetryRequested, transformer: restartable());
  }

  final ListOpenRequests _listOpen;

  int _currentLimit = 50;

  Future<void> _onStarted(
      TeamFillStarted event,
      Emitter<TeamFillState> emit,
      ) async {
    _currentLimit = event.limit;
    await _subscribe(emit, city: null, limit: _currentLimit);
  }

  Future<void> _onCityChanged(
      TeamFillCityChanged event,
      Emitter<TeamFillState> emit,
      ) async {
    if (state.city == event.city && state is! TeamFillError) {
      return;
    }
    _currentLimit = event.limit;
    await _subscribe(emit, city: event.city, limit: _currentLimit);
  }

  Future<void> _onRetryRequested(
      TeamFillRetryRequested event,
      Emitter<TeamFillState> emit,
      ) async {
    await _subscribe(emit, city: state.city, limit: _currentLimit);
  }

  Future<void> _subscribe(
      Emitter<TeamFillState> emit, {
        required String? city,
        required int limit,
      }) async {
    final loading = TeamFillLoading(city: city);
    if (state != loading) emit(loading);

    final stream = _listOpen(city: city, limit: limit);

    await emit.forEach<List<FillRequest>>(
      stream,
      onData: (items) => items.isEmpty
          ? TeamFillEmpty(city: city)
          : TeamFillData(city: city, items: items),
      onError: (error, stack) => TeamFillError(
        city: city,
        message: AppErrorHandler.getMessage(error, context: 'fill_request'),
      ),
    );
  }
}
