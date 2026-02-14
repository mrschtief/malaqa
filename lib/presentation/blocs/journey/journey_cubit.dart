import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/meeting_proof.dart';
import '../../../domain/repositories/chain_repository.dart';

sealed class JourneyState {
  const JourneyState();
}

class JourneyLoading extends JourneyState {
  const JourneyLoading();
}

class JourneyLoaded extends JourneyState {
  const JourneyLoaded(this.proofs);

  final List<MeetingProof> proofs;
}

class JourneyEmpty extends JourneyState {
  const JourneyEmpty();
}

class JourneyError extends JourneyState {
  const JourneyError(this.message);

  final String message;
}

class JourneyCubit extends Cubit<JourneyState> {
  JourneyCubit(this._chainRepository) : super(const JourneyLoading());

  final ChainRepository _chainRepository;

  Future<void> loadJourney() async {
    emit(const JourneyLoading());
    try {
      final proofs = await _chainRepository.getAllProofs();
      if (proofs.isEmpty) {
        emit(const JourneyEmpty());
        return;
      }

      final sorted = [...proofs]..sort((a, b) {
          final at = DateTime.tryParse(a.timestamp);
          final bt = DateTime.tryParse(b.timestamp);
          if (at == null && bt == null) {
            return b.timestamp.compareTo(a.timestamp);
          }
          if (at == null) {
            return 1;
          }
          if (bt == null) {
            return -1;
          }
          return bt.compareTo(at);
        });

      emit(JourneyLoaded(List<MeetingProof>.unmodifiable(sorted)));
    } catch (error, stackTrace) {
      AppLogger.error(
        'JOURNEY',
        'Failed to load local journey',
        error: error,
        stackTrace: stackTrace,
      );
      emit(const JourneyError('Could not load your journey.'));
    }
  }
}
