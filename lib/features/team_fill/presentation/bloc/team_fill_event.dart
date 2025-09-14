import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class TeamFillEvent extends Equatable{
  const TeamFillEvent();
  @override
  List<Object?> get props => const [];
}

class TeamFillStarted extends TeamFillEvent{
  const TeamFillStarted({this.limit=50});
  final int limit;

  @override
  List<Object?> get props => [limit];

}

class TeamFillCityChanged extends TeamFillEvent{
  const TeamFillCityChanged({ this.city,this.limit=50});
  final String? city;
  final int limit;
  @override
  List<Object?> get props => [city,limit];
}

class TeamFillRetryRequested extends TeamFillEvent{
  const TeamFillRetryRequested();
}

