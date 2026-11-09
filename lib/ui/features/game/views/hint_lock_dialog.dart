import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pipes/data/services/hint_config.dart';
import 'package:pipes/data/services/hint_service.dart';
import 'package:pipes/data/services/leaderboard_service.dart';
import 'package:pipes/ui/core/l10n.dart';
import 'package:pipes/ui/core/theme/app_colors.dart';
import 'package:pipes/ui/core/widgets/tangible_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the player has 0 hints. Explains how to earn more and lets
/// them enter the lifetime password. Returns true if lifetime was unlocked.
Future<bool> showHintLockDialog(
  BuildContext context,
  HintService hints,
  LeaderboardService board,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _HintLockDialog(hints: hints, board: board),
  );
  return result ?? false;
}

class _HintLockDialog extends StatefulWidget {
  const _HintLockDialog({required this.hints, required this.board});
  final HintService hints;
  final LeaderboardService board;

  @override
  State<_HintLockDialog> createState() => _HintLockDialogState();
}

class _HintLockDialogState extends State<_HintLockDialog> {
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await widget.hints.tryUnlock(_pw.text);
    if (!mounted) return;
    switch (r) {
      case UnlockResult.success:
        Navigator.pop(context, true);
        return;
      case UnlockResult.wrong:
        setState(() {
          _busy = false;
          _error = L10n.t('Wrong code (or not for this phone)', 'කේතය වැරදියි (හෝ මේ ෆෝන් එකට නෙවෙයි)');
        });
      case UnlockResult.locked:
        final s = widget.hints.lockSecondsLeft;
        setState(() {
          _busy = false;
          _error = L10n.t(
            'Too many tries. Wait $s s',
            'වැරදි උත්සාහ වැඩියි. තත්පර $s ක් ඉන්න',
          );
        });
    }
  }

  Future<void> _contact() async {
    try {
      final msg = Uri.encodeComponent(
        'Hi! I want Lifetime Hints (Rs. ${HintConfig.lifetimePriceRs}) for Mathra Pipes.\nMy Device ID: ${widget.hints.deviceId}',
      );
      await launchUrl(
        Uri.parse('https://wa.me/${HintConfig.whatsappNumber}?text=$msg'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final score = board.me?.score ?? 0;
    final need = widget.hints.pointsToNext(score);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '🔒  ${L10n.t('Hints locked', 'ඉඟි ඉවරයි')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.headingDark,
                ),
              ),
              const SizedBox(height: 12),
              _box(
                title: '⭐ ${L10n.t('Free hints', 'නොමිලේ ඉඟි')}',
                body: board.hasPlayer
                    ? L10n.d(
                        'Every ${HintConfig.pointsPerReward} leaderboard points = ${HintConfig.hintsPerReward} hints.\nYour score: $score  •  $need more points for the next ${HintConfig.hintsPerReward} hints.',
                        'Leaderboard ලකුණු ${HintConfig.pointsPerReward} ක් වාරයකට ඉඟි ${HintConfig.hintsPerReward} ක්.\nඔයාගේ ලකුණු: $score  •  ඊළඟ ඉඟි ${HintConfig.hintsPerReward} ට තව ලකුණු $need ක් ඕනේ.',
                      )
                    : L10n.d(
                        'Solve a level and enter your name. Every ${HintConfig.pointsPerReward} leaderboard points = ${HintConfig.hintsPerReward} hints.',
                        'Level එකක් ඉවර කරලා නම දාන්න. ලකුණු ${HintConfig.pointsPerReward} ක් වාරයකට ඉඟි ${HintConfig.hintsPerReward} ක්.',
                      ),
              ),
              const SizedBox(height: 10),
              _box(
                title:
                    '👑 ${L10n.t('Lifetime hints', 'Lifetime ඉඟි')} – Rs. ${HintConfig.lifetimePriceRs}',
                body: L10n.d(
                  'Pay once, unlimited hints forever. Send your Device ID on WhatsApp ${HintConfig.whatsappDisplay}. You get a code that works on THIS phone only.',
                  'එක පාරක් ගෙව්ලා life time ඉඟි අසීමිතව. ඔයාගේ Device ID එක WhatsApp ${HintConfig.whatsappDisplay} වෙත යවන්න. ලැබෙන කේතය වැඩ කරන්නේ මේ ෆෝන් එකේ විතරයි.',
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: widget.hints.deviceId));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(L10n.t('Device ID copied', 'Device ID copy වුණා')),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Device ID: ${widget.hints.deviceId}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.headingDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.copy_rounded, size: 16, color: AppColors.subtext),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TangibleButton(
                text: L10n.t('Contact to buy', 'මිලදී ගන්න සම්බන්ධ වෙන්න'),
                icon: Icons.chat_rounded,
                isSecondary: true,
                height: 42,
                onPressed: _contact,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pw,
                obscureText: false,
                textCapitalization: TextCapitalization.characters,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _unlock(),
                style: TextStyle(color: AppColors.headingDark),
                decoration: InputDecoration(
                  hintText: L10n.t('Unlock code', 'Unlock කේතය'),
                  hintStyle: TextStyle(color: AppColors.subtext),
                  prefixIcon: Icon(Icons.lock_rounded, color: AppColors.subtext),
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TangibleButton(
                      text: L10n.t('Close', 'වසන්න'),
                      isSecondary: true,
                      height: 44,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TangibleButton(
                      text: L10n.t('Unlock', 'Unlock'),
                      icon: Icons.lock_open_rounded,
                      height: 44,
                      backgroundColor: AppColors.accent,
                      textColor: Colors.white,
                      onPressed: _unlock,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(fontSize: 12.5, color: AppColors.subtext),
          ),
        ],
      ),
    );
  }
}
