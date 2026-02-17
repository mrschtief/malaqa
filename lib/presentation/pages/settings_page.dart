import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/secure_key_value_store.dart';
import '../../data/models/meeting_proof_model.dart';
import '../../domain/services/crypto_wallet_service.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/meeting/meeting_cubit.dart';
import '../blocs/proximity/proximity_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const SettingsPage());
  }

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppSettingsService _settings;
  var _isRevealingBackup = false;
  var _isResetting = false;

  @override
  void initState() {
    super.initState();
    _settings = getIt<AppSettingsService>();
  }

  Future<void> _showBackupPhrase() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Biometric session expired. Re-auth first.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Backup Identity'),
              content: const Text(
                'Diese Recovery Phrase gibt vollen Zugriff auf deine Identität. '
                'Nur offline sichern und niemals teilen.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Ich verstehe'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    setState(() => _isRevealingBackup = true);

    try {
      final walletService = getIt<CryptoWalletService>();
      final mnemonic = await walletService.deriveMnemonic();

      if (!mounted) {
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery Phrase',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    mnemonic,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Warnung: Wer diese Wörter hat, kontrolliert dein Profil.',
                ),
              ],
            ),
          );
        },
      );

      AppLogger.log('SETTINGS', 'Recovery phrase viewed');
    } catch (error, stackTrace) {
      AppLogger.error(
        'SETTINGS',
        'Failed to reveal recovery phrase',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Backup phrase konnte nicht geladen werden.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRevealingBackup = false);
      }
    }
  }

  Future<void> _setNearbyVisibility(bool enabled) async {
    await _settings.setNearbyVisibility(enabled);

    final authState = context.read<AuthCubit>().state;
    if (enabled && authState is AuthAuthenticated) {
      await context.read<ProximityCubit>().setAuthenticated(
            userName: authState.identity.name,
            identity: authState.identity,
            ownerVector: authState.ownerVector,
          );
      return;
    }

    await context.read<ProximityCubit>().clearAuthentication();
  }

  Future<void> _resetApp() async {
    final approved = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Reset App'),
              content: const Text(
                'Dieser Schritt löscht Identity-Keys, lokale Chain-Daten und setzt '
                'das Onboarding zurück. Dieser Vorgang ist nicht rückgängig.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Jetzt löschen'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!approved) {
      return;
    }

    setState(() => _isResetting = true);

    try {
      final isar = getIt<Isar>();
      final secureStore = getIt<SecureKeyValueStore>();

      await isar.writeTxn(() async {
        await isar.meetingProofModels.clear();
      });
      await secureStore.deleteAll();
      await _settings.resetToFirstRun();

      context.read<MeetingCubit>().clearAuthentication();
      await context.read<ProximityCubit>().clearAuthentication();
      await context.read<AuthCubit>().checkIdentity();

      AppLogger.log('SETTINGS', 'App reset completed');
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error, stackTrace) {
      AppLogger.error(
        'SETTINGS',
        'App reset failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset fehlgeschlagen.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _SectionCard(
                title: 'Account',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Backup Identity'),
                    subtitle: const Text(
                      'Zeige deine Recovery Phrase (12+ Wörter).',
                    ),
                    trailing: _isRevealingBackup
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isRevealingBackup ? null : _showBackupPhrase,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Privacy',
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nearby Visibility'),
                    subtitle: const Text(
                      'Steuert Bluetooth Advertising + Discovery.',
                    ),
                    value: _settings.nearbyVisibility,
                    onChanged: _setNearbyVisibility,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'System',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reset App'),
                    subtitle: const Text('Danger Zone: löscht lokale Daten'),
                    trailing: _isResetting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.warning_amber_rounded),
                    onTap: _isResetting ? null : _resetApp,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'About',
                children: const [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Malaqa'),
                    subtitle: Text('v0.5.0-alpha'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}
