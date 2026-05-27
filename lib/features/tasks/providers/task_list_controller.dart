import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskListState {
  const TaskListState({
    required this.windowAnchor,
    required this.searchLower,
    required this.trainingWarningAcknowledged,
    required this.fabVisible,
    required this.searchBarVisible,
    required this.refreshTick,
  });

  final DateTime windowAnchor;
  final String searchLower;
  final bool trainingWarningAcknowledged;
  final bool fabVisible;
  final bool searchBarVisible;

  /// Monotonic counter that bumps on every `refreshAnchor` call, even when
  /// the hour-aligned `windowAnchor` is unchanged. Screens that watch this
  /// get a forced rebuild on every tick so time-sensitive filters
  /// (blackout windows, priority delays) re-evaluate against current
  /// `DateTime.now()` without waiting for the next hour boundary.
  final int refreshTick;

  TaskListState copyWith({
    DateTime? windowAnchor,
    String? searchLower,
    bool? trainingWarningAcknowledged,
    bool? fabVisible,
    bool? searchBarVisible,
    int? refreshTick,
  }) {
    return TaskListState(
      windowAnchor: windowAnchor ?? this.windowAnchor,
      searchLower: searchLower ?? this.searchLower,
      trainingWarningAcknowledged:
          trainingWarningAcknowledged ?? this.trainingWarningAcknowledged,
      fabVisible: fabVisible ?? this.fabVisible,
      searchBarVisible: searchBarVisible ?? this.searchBarVisible,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}

class TaskListController extends Notifier<TaskListState> {
  @override
  TaskListState build() => TaskListState(
        windowAnchor: _truncateToHour(DateTime.now()),
        searchLower: '',
        trainingWarningAcknowledged: false,
        fabVisible: true,
        searchBarVisible: false,
        refreshTick: 0,
      );

  void refreshAnchor([DateTime? anchor]) {
    final next = _truncateToHour(anchor ?? DateTime.now());
    final nextTick = state.refreshTick + 1;
    if (state.windowAnchor == next) {
      // Hour hasn't rolled, but still bump the tick so blackout/priority
      // boundaries that fall inside the current hour get picked up by
      // any screen watching refreshTick.
      state = state.copyWith(refreshTick: nextTick);
      return;
    }
    state = state.copyWith(windowAnchor: next, refreshTick: nextTick);
  }

  void setSearch(String value) {
    state = state.copyWith(searchLower: value.trim().toLowerCase());
  }

  void acknowledgeTrainingWarning() {
    state = state.copyWith(trainingWarningAcknowledged: true);
  }

  void setFabVisible(bool visible) {
    if (state.fabVisible == visible) return;
    state = state.copyWith(fabVisible: visible);
  }

  void setSearchBarVisible(bool visible) {
    if (state.searchBarVisible == visible) return;
    state = state.copyWith(searchBarVisible: visible);
    if (!visible) {
      state = state.copyWith(searchLower: '');
    }
  }

  void toggleSearchBar() {
    setSearchBarVisible(!state.searchBarVisible);
  }
}

final taskListControllerProvider =
    NotifierProvider<TaskListController, TaskListState>(
  TaskListController.new,
);

DateTime _truncateToHour(DateTime value) {
  return DateTime(value.year, value.month, value.day, value.hour);
}
