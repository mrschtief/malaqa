import '../../core/identity.dart';
import '../entities/meeting_proof.dart';
import '../services/statistics_service.dart';
import 'badge_definitions.dart';

class BadgeProgress {
  const BadgeProgress({
    required this.badge,
    required this.unlocked,
    required this.currentValue,
    required this.targetValue,
    required this.progress,
    required this.nextHint,
  });

  final BadgeType badge;
  final bool unlocked;
  final double currentValue;
  final double targetValue;
  final double progress;
  final String nextHint;
}

class BadgeManager {
  BadgeManager({StatisticsService? statisticsService})
      : _statisticsService = statisticsService ?? StatisticsService();

  final StatisticsService _statisticsService;

  List<BadgeType> checkUnlocks(
    List<MeetingProof> proofs, {
    required Ed25519Identity me,
  }) {
    final stats = _statisticsService.buildStats(proofs, me: me);
    return BadgeType.values
        .where((badge) => _metricValue(stats, badge.metric) >= badge.target)
        .toList(growable: false);
  }

  List<BadgeProgress> evaluate(
    List<MeetingProof> proofs, {
    required Ed25519Identity me,
  }) {
    final stats = _statisticsService.buildStats(proofs, me: me);
    return BadgeType.values
        .map((badge) => _evaluateBadge(badge: badge, stats: stats))
        .toList(growable: false);
  }

  BadgeProgress _evaluateBadge({
    required BadgeType badge,
    required UserStats stats,
  }) {
    final currentValue = _metricValue(stats, badge.metric);
    final unlocked = currentValue >= badge.target;
    final normalizedProgress =
        badge.target <= 0 ? 1.0 : (currentValue / badge.target).clamp(0.0, 1.0);

    return BadgeProgress(
      badge: badge,
      unlocked: unlocked,
      currentValue: currentValue,
      targetValue: badge.target,
      progress: normalizedProgress,
      nextHint: unlocked
          ? 'Unlocked'
          : _remainingHint(
              badge: badge,
              currentValue: currentValue,
            ),
    );
  }

  double _metricValue(UserStats stats, BadgeMetric metric) {
    return switch (metric) {
      BadgeMetric.meetings => stats.meetingsCount.toDouble(),
      BadgeMetric.uniquePeople => stats.uniquePeopleCount.toDouble(),
      BadgeMetric.distanceKm => stats.totalDistanceKm,
      BadgeMetric.streakDays => stats.streakDays.toDouble(),
    };
  }

  String _remainingHint({
    required BadgeType badge,
    required double currentValue,
  }) {
    final remaining = (badge.target - currentValue).clamp(0.0, double.infinity);
    return switch (badge.metric) {
      BadgeMetric.meetings => 'You need ${remaining.ceil()} more meeting(s).',
      BadgeMetric.uniquePeople =>
        'You need ${remaining.ceil()} more unique people.',
      BadgeMetric.distanceKm =>
        'You need ${remaining.toStringAsFixed(1)} km more.',
      BadgeMetric.streakDays =>
        'You need ${remaining.ceil()} more streak day(s).',
    };
  }
}
