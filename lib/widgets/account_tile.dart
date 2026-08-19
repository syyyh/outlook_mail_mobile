import 'package:flutter/material.dart';

import '../models/mail_account.dart';
import '../theme/app_theme.dart';

class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.onTap,
    required this.onRetry,
    this.animate = false,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final MailAccount account;
  final VoidCallback onTap;
  final VoidCallback onRetry;
  final bool animate;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final success = account.status == AccountStatus.success;
    final failed = account.status == AccountStatus.failed;
    final metaColor = success
        ? AppColors.accent
        : failed
        ? AppColors.error
        : AppColors.muted;

    final tile = SizedBox(
      height: 76,
      child: Material(
        color: selected ? AppColors.accentSoft : Colors.transparent,
        child: InkWell(
          onTap: selectionMode
              ? onTap
              : success
              ? onTap
              : failed
              ? onRetry
              : null,
          onLongPress: onLongPress,
          child: Row(
            children: [
              _AccountInitial(account: account),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'account-email-${account.id}',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          account.email.isEmpty ? '无法识别的账号' : account.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: metaColor,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              selectionMode
                  ? _SelectionCheck(selected: selected)
                  : _StateIcon(status: account.status),
            ],
          ),
        ),
      ),
    );

    if (!animate) return tile;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: tile,
    );
  }

  String _subtitle() => switch (account.status) {
    AccountStatus.validating => '正在验证并读取收件箱',
    AccountStatus.failed => account.errorMessage ?? '令牌已失效，点按重试',
    AccountStatus.success =>
      account.unreadCount > 0
          ? '已连接  ${account.unreadCount} 封未读'
          : '已连接  0 封未读',
  };
}

class _SelectionCheck extends StatelessWidget {
  const _SelectionCheck({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.muted,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: Colors.white, size: 15)
          : null,
    );
  }
}

class _AccountInitial extends StatelessWidget {
  const _AccountInitial({required this.account});

  final MailAccount account;

  @override
  Widget build(BuildContext context) {
    final color = switch (account.status) {
      AccountStatus.failed => AppColors.avatarCoral,
      AccountStatus.validating => AppColors.avatarAmber,
      AccountStatus.success => _successColor(account.id),
    };
    final initial = account.email.trim().isEmpty
        ? '?'
        : account.email.trim().characters.first.toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _successColor(String id) {
    if (id.hashCode.isEven) return AppColors.avatarTeal;
    if (id.hashCode % 3 == 0) return AppColors.avatarBlue;
    return AppColors.accent;
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.status});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AccountStatus.success => const Icon(
        Icons.check_circle_outline,
        color: AppColors.accent,
        size: 23,
      ),
      AccountStatus.failed => const Icon(
        Icons.error_outline,
        color: AppColors.error,
        size: 23,
      ),
      AccountStatus.validating => const Icon(
        Icons.schedule_outlined,
        color: AppColors.muted,
        size: 23,
      ),
    };
  }
}
