class StatsRepository {
  static final StatsRepository _instance = StatsRepository._internal();
  Map<String, String> stats = {};

  factory StatsRepository() {
    return _instance;
  }

  StatsRepository._internal();
}
