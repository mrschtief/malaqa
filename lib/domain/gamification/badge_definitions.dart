enum BadgeMetric {
  meetings,
  uniquePeople,
  distanceKm,
  streakDays,
}

class BadgeType {
  const BadgeType({
    required this.id,
    required this.name,
    required this.description,
    required this.iconAsset,
    required this.condition,
    required this.metric,
    required this.target,
  });

  final String id;
  final String name;
  final String description;
  final String iconAsset;
  final String condition;
  final BadgeMetric metric;
  final double target;

  static const firstContact = BadgeType(
    id: 'first_contact',
    name: 'First Contact',
    description: 'Unlock your first verified meeting in the chain.',
    iconAsset: 'badge_first_contact',
    condition: 'Complete 1 meeting.',
    metric: BadgeMetric.meetings,
    target: 1,
  );

  static const socialButterfly = BadgeType(
    id: 'social_butterfly',
    name: 'Social Butterfly',
    description: 'Connect with five unique people.',
    iconAsset: 'badge_social_butterfly',
    condition: 'Reach 5 unique people.',
    metric: BadgeMetric.uniquePeople,
    target: 5,
  );

  static const explorer = BadgeType(
    id: 'explorer',
    name: 'Explorer',
    description: 'Push your chain across distance.',
    iconAsset: 'badge_explorer',
    condition: 'Reach 10 km total distance.',
    metric: BadgeMetric.distanceKm,
    target: 10,
  );

  static const marathon = BadgeType(
    id: 'marathon',
    name: 'Marathon',
    description: 'Keep the chain alive for a full week.',
    iconAsset: 'badge_marathon',
    condition: 'Reach a 7 day streak.',
    metric: BadgeMetric.streakDays,
    target: 7,
  );

  static const values = <BadgeType>[
    firstContact,
    socialButterfly,
    explorer,
    marathon,
  ];
}
