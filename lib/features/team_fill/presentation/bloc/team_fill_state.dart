import 'package:equatable/equatable.dart';
import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';

class TeamFillState extends Equatable {
  const TeamFillState({this.city});

  final String? city;

  @override
  List<Object?> get props => [city];
}

class TeamFillInitial extends TeamFillState {
  const TeamFillInitial({String? city}) : super(city: city);
}

class TeamFillLoading extends TeamFillState {
  const TeamFillLoading({String? city}) : super(city: city);
}

class TeamFillData extends TeamFillState {
  const TeamFillData({String? city, required this.items}) : super(city:city);

  final List<FillRequest> items;

  @override
  List<Object?> get props =>
      [
        city,
        // listedeki elemanların (ör. id) hash imzası:
        Object.hashAll(items.map((e) => e.id)),
      ];
}

class TeamFillEmpty extends TeamFillState {
  const TeamFillEmpty({String? city}) : super(city: city);
}

class TeamFillError extends TeamFillState {
  const TeamFillError({String? city, required this.message, this.code})
      : super(city: city);
  final String message;
  final String? code;

  @override
  List<Object?> get props => [city, message, code];
}
