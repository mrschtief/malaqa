import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../domain/gamification/badge_manager.dart';
import '../blocs/profile/profile_cubit.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider<ProfileCubit>(
        create: (_) => getIt<ProfileCubit>()..loadProfile(),
        child: const ProfilePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(SettingsPage.route()),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          return switch (state) {
            ProfileLoading _ =>
              const Center(child: CircularProgressIndicator()),
            ProfileError s => _ProfileErrorState(
                message: s.message,
                onRetry: () => context.read<ProfileCubit>().loadProfile(),
              ),
            ProfileLoaded s => _ProfileContent(state: s),
          };
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.state});

  final ProfileLoaded state;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = state.stats.totalDistanceKm < 10
        ? state.stats.totalDistanceKm.toStringAsFixed(1)
        : state.stats.totalDistanceKm.toStringAsFixed(0);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _ProfileHeader(name: state.identity.name),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Meetings',
                    value: '${state.stats.meetingsCount}',
                    icon: Icons.handshake_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Distance',
                    value: '$distanceLabel km',
                    icon: Icons.public_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'People',
                    value: '${state.stats.uniquePeopleCount}',
                    icon: Icons.groups_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Best streak: ${state.stats.streakDays} day(s)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Badges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.14,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final progress = state.badgeProgress[index];
                return _BadgeTile(
                  progress: progress,
                  onTap: () => _showBadgeDetails(context, progress),
                );
              },
              childCount: state.badgeProgress.length,
            ),
          ),
        ),
      ],
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeProgress progress) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress.badge.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(progress.badge.description),
              const SizedBox(height: 12),
              Text(
                progress.badge.condition,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Text(
                progress.unlocked
                    ? 'Status: unlocked'
                    : 'Status: locked - ${progress.nextHint}',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: const Color(0xFF00CFE8).withValues(alpha: 0.22),
          child: Text(
            initial,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Malaqa traveler',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: null,
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF009CB0)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.progress,
    required this.onTap,
  });

  final BadgeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.unlocked;
    final baseColor = unlocked ? const Color(0xFF00CFE8) : Colors.grey.shade400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color:
              unlocked ? const Color(0xFF00CFE8).withValues(alpha: 0.12) : null,
          border: Border.all(
            color: unlocked
                ? const Color(0xFF00CFE8).withValues(alpha: 0.45)
                : Colors.grey.shade300,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconForBadge(progress.badge.iconAsset), color: baseColor),
                const SizedBox(height: 10),
                Text(
                  progress.badge.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: unlocked ? Colors.black : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  progress.badge.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                LinearProgressIndicator(
                  value: progress.progress,
                  backgroundColor: Colors.grey.shade200,
                  color:
                      unlocked ? const Color(0xFF00CFE8) : Colors.grey.shade400,
                ),
              ],
            ),
            if (!unlocked)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForBadge(String iconAsset) {
    return switch (iconAsset) {
      'badge_first_contact' => Icons.waving_hand_outlined,
      'badge_social_butterfly' => Icons.diversity_3_outlined,
      'badge_explorer' => Icons.explore_outlined,
      'badge_marathon' => Icons.bolt_outlined,
      _ => Icons.emoji_events_outlined,
    };
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 54, color: Colors.redAccent),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
