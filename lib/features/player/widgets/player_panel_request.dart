/// Invalidates panel fetches when a picker closes, changes, or refreshes.
/// Only the newest request may publish data, errors, or loading state.
class PlayerPanelRequest {
  int _generation = 0;

  int begin() => ++_generation;

  void invalidate() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;
}
