import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/di/service_locator.dart';
import '../../core/interfaces/crypto_provider.dart';
import '../../domain/entities/meeting_proof.dart';
import '../blocs/journey/journey_cubit.dart';
import '../dialogs/qr_share_dialog.dart';
import 'map_page.dart';
import '../widgets/timeline/meeting_timeline_item.dart';

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider<JourneyCubit>(
        create: (_) => getIt<JourneyCubit>()..loadJourney(),
        child: const JourneyPage(),
      ),
    );
  }

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  final _hashCache = <String, String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journey'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MapPage.route()),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Show Map'),
          ),
        ],
      ),
      body: BlocBuilder<JourneyCubit, JourneyState>(
        builder: (context, state) {
          return switch (state) {
            JourneyLoading _ => const Center(
                child: CircularProgressIndicator(),
              ),
            JourneyEmpty _ => _JourneyEmptyState(
                onStartPressed: () => Navigator.of(context).pop(),
              ),
            JourneyError s => _JourneyErrorState(
                message: s.message,
                onRetry: () => context.read<JourneyCubit>().loadJourney(),
              ),
            JourneyLoaded s => _JourneyList(
                proofs: s.proofs,
                resolveHash: _resolveProofId,
                onShareQr: _openQrShareDialog,
              ),
          };
        },
      ),
    );
  }

  Future<String> _resolveProofId(MeetingProof proof) async {
    final cacheKey = proof.canonicalPayload();
    final cached = _hashCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final hash = await proof.computeProofHash(getIt<CryptoProvider>());
    final short = hash.length > 6 ? '${hash.substring(0, 6)}...' : hash;
    _hashCache[cacheKey] = short;
    return short;
  }

  void _openQrShareDialog(MeetingProof proof) {
    showDialog<void>(
      context: context,
      builder: (_) => QrShareDialog(proof: proof),
    );
  }
}

class _JourneyList extends StatelessWidget {
  const _JourneyList({
    required this.proofs,
    required this.resolveHash,
    required this.onShareQr,
  });

  final List<MeetingProof> proofs;
  final Future<String> Function(MeetingProof proof) resolveHash;
  final ValueChanged<MeetingProof> onShareQr;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: proofs.length,
      itemBuilder: (context, index) {
        final proof = proofs[index];
        final meetingNumber = proofs.length - index;
        final timestamp = DateTime.tryParse(proof.timestamp)?.toLocal();
        final relative =
            timestamp == null ? proof.timestamp : timeago.format(timestamp);

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 70)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 22 * (1 - value)),
                child: child,
              ),
            );
          },
          child: FutureBuilder<String>(
            future: resolveHash(proof),
            builder: (context, snapshot) {
              final proofId = snapshot.data ?? '...';
              return MeetingTimelineItem(
                meetingNumber: meetingNumber,
                relativeTime: relative,
                proofId: proofId,
                isFirst: index == 0,
                isLast: index == proofs.length - 1,
                onShareQr: () => onShareQr(proof),
              );
            },
          ),
        );
      },
    );
  }
}

class _JourneyEmptyState extends StatelessWidget {
  const _JourneyEmptyState({required this.onStartPressed});

  final VoidCallback onStartPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 82,
              color: const Color(0xFF00CFE8).withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deine Reise beginnt mit dem ersten Handschlag. Geh raus!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Begegnungen gespeichert.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onStartPressed,
              child: const Text('Start your journey'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyErrorState extends StatelessWidget {
  const _JourneyErrorState({
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
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
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
