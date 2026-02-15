import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/identity.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/gamification/badge_definitions.dart';
import '../../../domain/gamification/badge_manager.dart';
import '../../../domain/repositories/chain_repository.dart';
import '../../../domain/repositories/identity_repository.dart';
import '../../../domain/services/statistics_service.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({
    required this.identity,
    required this.stats,
    required this.unlockedBadges,
    required this.badgeProgress,
  });

  final Ed25519Identity identity;
  final UserStats stats;
  final List<BadgeType> unlockedBadges;
  final List<BadgeProgress> badgeProgress;
}

class ProfileError extends ProfileState {
  const ProfileError({required this.message});

  final String message;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required IdentityRepository identityRepository,
    required ChainRepository chainRepository,
    required StatisticsService statisticsService,
    required BadgeManager badgeManager,
  })  : _identityRepository = identityRepository,
        _chainRepository = chainRepository,
        _statisticsService = statisticsService,
        _badgeManager = badgeManager,
        super(const ProfileLoading());

  final IdentityRepository _identityRepository;
  final ChainRepository _chainRepository;
  final StatisticsService _statisticsService;
  final BadgeManager _badgeManager;

  Future<void> loadProfile() async {
    emit(const ProfileLoading());

    try {
      final identity = await _identityRepository.getIdentity();
      if (identity == null) {
        AppLogger.log(
          'PROFILE',
          'No local identity found. Falling back to guest profile.',
        );
        final guestIdentity = await Identity.create(name: 'Malaqa Pionier');
        final proofs = await _chainRepository.getAllProofs();
        final stats = _statisticsService.buildStats(proofs, me: guestIdentity);
        final badgeProgress = _badgeManager.evaluate(proofs, me: guestIdentity);
        final unlockedBadges = badgeProgress
            .where((badge) => badge.unlocked)
            .map((badge) => badge.badge)
            .toList(growable: false);

        emit(
          ProfileLoaded(
            identity: guestIdentity,
            stats: stats,
            unlockedBadges: unlockedBadges,
            badgeProgress: badgeProgress,
          ),
        );
        return;
      }

      final proofs = await _chainRepository.getAllProofs();
      final stats = _statisticsService.buildStats(proofs, me: identity);
      final badgeProgress = _badgeManager.evaluate(proofs, me: identity);
      final unlockedBadges = badgeProgress
          .where((badge) => badge.unlocked)
          .map((badge) => badge.badge)
          .toList(growable: false);

      emit(
        ProfileLoaded(
          identity: identity,
          stats: stats,
          unlockedBadges: unlockedBadges,
          badgeProgress: badgeProgress,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'PROFILE',
        'Failed to load profile',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        const ProfileError(
          message: 'Could not load profile data.',
        ),
      );
    }
  }
}
