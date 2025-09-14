import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toplansin/features/team_fill/domain/usecases/list_open_requests.dart';
import 'package:toplansin/features/team_fill/presentation/bloc/team_fill_bloc.dart';
import 'package:toplansin/features/team_fill/presentation/bloc/team_fill_event.dart';
import 'package:toplansin/features/team_fill/presentation/bloc/team_fill_state.dart';
import 'package:toplansin/features/team_fill/presentation/widgets/city_selector.dart';
import 'package:toplansin/features/team_fill/presentation/widgets/empty_view.dart';
import 'package:toplansin/features/team_fill/presentation/widgets/error_view.dart';
import 'package:toplansin/features/team_fill/presentation/widgets/loading_list.dart';
import 'package:toplansin/features/team_fill/presentation/widgets/request_card.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

class BrowseRequestsPage extends StatelessWidget {
  const BrowseRequestsPage({
    super.key,
    required this.listOpenUseCase,
    this.availableCities = const [
      'İstanbul',
      'Ankara',
      'İzmir',
      'Bursa',
      'Antalya'
    ],
  });

  final ListOpenRequests listOpenUseCase;
  final List<String> availableCities;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TeamFillBloc(listOpenUseCase)..add(const TeamFillStarted(limit: 50)),
      child: Scaffold(
        body: const _BrowseBody(),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: Icon(Icons.add),
            label: const Text("İlan Aç")),
      ),
    );
  }
}

class _BrowseBody extends StatelessWidget {
  const _BrowseBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _HeaderBar(),
        const Divider(
          height: 1,
        ),
        Expanded(child:
            BlocBuilder<TeamFillBloc, TeamFillState>(builder: (context, state) {
          if (state is TeamFillInitial || state is TeamFillLoading) {
            return const LoadingList();
          }
          if (state is TeamFillError) {
            return ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<TeamFillBloc>()
                  .add(const TeamFillRetryRequested()),
            );
          }
          if (state is TeamFillEmpty) {
            return const EmptyView();
          }
          if (state is TeamFillData) {
            final items = state.items;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: items.length,
              itemBuilder: (_, i) => RequestCard(item: items[i]),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
            );
          }
          return const SizedBox.shrink();
        })),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamFillBloc, TeamFillState>(
      buildWhen: (prev, curr) => prev.city != curr.city,
      builder: (context, state) {
        final city = state.city;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              CitySelector(
                value: city,
                onChanged: (value) {
                  context
                      .read<TeamFillBloc>()
                      .add(TeamFillCityChanged(city: value));
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      city == null
                          ? 'Tüm Açık İlanlar'
                          : '${city} İçin Açık İlanlar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textPrimary))),
            ],
          ),
        );
      },
    );
  }
}
