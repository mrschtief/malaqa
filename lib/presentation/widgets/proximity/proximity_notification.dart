import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/services/proof_importer.dart';
import '../../blocs/proximity/proximity_cubit.dart';
import '../../pages/journey_page.dart';

class ProximityNotificationOverlay extends StatelessWidget {
  const ProximityNotificationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProximityCubit, ProximityState>(
      builder: (context, state) {
        Widget child = const SizedBox.shrink();

        if (state is ProximityMatchFound) {
          child = _ProximityCard(
            title: '✨ Jemand hat dich gerade gesehen!',
            subtitle:
                'Similarity: ${(state.similarity * 100).toStringAsFixed(1)}%',
            primaryLabel: 'Claim & Save',
            onPrimaryPressed: () =>
                context.read<ProximityCubit>().claimAndSave(),
            secondaryLabel: 'Ignorieren',
            onSecondaryPressed: () =>
                context.read<ProximityCubit>().ignoreMatch(),
            icon: Icons.auto_awesome_outlined,
            accentColor: const Color(0xFF00CFE8),
          );
        } else if (state is ProximityClaiming) {
          child = _ProximityCard(
            title: 'Claiming proof...',
            subtitle: 'Validating and saving the meeting proof.',
            icon: Icons.sync,
            accentColor: const Color(0xFF00CFE8),
            isLoading: true,
          );
        } else if (state is ProximityClaimed) {
          final isSuccess = state.result.status == ImportStatus.success;
          final isDuplicate = state.result.status == ImportStatus.duplicate;
          child = _ProximityCard(
            title: isSuccess
                ? 'Meeting verified via QR bridge'
                : isDuplicate
                    ? 'Already saved'
                    : 'Import failed',
            subtitle: state.result.message,
            primaryLabel: isSuccess ? 'Open Journey' : 'Close',
            onPrimaryPressed: () {
              if (isSuccess) {
                Navigator.of(context).push(JourneyPage.route());
              }
              context.read<ProximityCubit>().dismissClaimResult();
            },
            secondaryLabel: isSuccess ? 'Continue' : null,
            onSecondaryPressed: isSuccess
                ? () => context.read<ProximityCubit>().dismissClaimResult()
                : null,
            icon: isSuccess
                ? Icons.check_circle_outline
                : isDuplicate
                    ? Icons.info_outline
                    : Icons.error_outline,
            accentColor: isSuccess
                ? const Color(0xFF2ECC71)
                : isDuplicate
                    ? const Color(0xFF00CFE8)
                    : const Color(0xFFE74C3C),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.25),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

class _ProximityCard extends StatelessWidget {
  const _ProximityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isLoading = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.7)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (primaryLabel != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: onPrimaryPressed,
                          child: Text(primaryLabel!),
                        ),
                        if (secondaryLabel != null) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: onSecondaryPressed,
                            child: Text(secondaryLabel!),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
